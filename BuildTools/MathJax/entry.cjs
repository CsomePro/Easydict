// Local JavaScriptCore entry point. No browser, network, or dynamic TeX loading.
const { mathjax } = require('@mathjax/src/cjs/mathjax.js');
const { TeX } = require('@mathjax/src/cjs/input/tex.js');
const { SVG } = require('@mathjax/src/cjs/output/svg.js');
const { MathJaxTexFont } = require('@mathjax/mathjax-tex-font/cjs/svg.js');
const { liteAdaptor } = require('@mathjax/src/cjs/adaptors/liteAdaptor.js');
const { RegisterHTMLHandler } = require('@mathjax/src/cjs/handlers/html.js');
require('@mathjax/src/cjs/input/tex/ams/AmsConfiguration.js');
require('@mathjax/src/cjs/input/tex/newcommand/NewcommandConfiguration.js');
require('@mathjax/src/cjs/input/tex/boldsymbol/BoldsymbolConfiguration.js');

const adaptor = liteAdaptor();
RegisterHTMLHandler(adaptor);
const fail = (_document, _math, error) => { throw error; };
// A native text attachment needs one SVG, not MathJax's breakable inline fragments.
const output = new SVG({
    fontCache: 'none',
    fontData: MathJaxTexFont,
    linebreaks: { inline: false }
});

globalThis.renderMath = function (tex, display) {
    if (tex.length > 4096) return null;
    // A new input processor prevents macro definitions from leaking across results.
    const document = mathjax.document('', {
        InputJax: new TeX({
            packages: ['base', 'ams', 'newcommand', 'boldsymbol'],
            maxBuffer: 8192,
            maxMacros: 1000,
            formatError: (_jax, error) => { throw error; }
        }),
        OutputJax: output,
        compileError: fail,
        typesetError: fail
    });
    try {
        const node = document.convert(tex, { display, em: 16, ex: 8, containerWidth: 100000 });
        const svg = adaptor.firstChild(node);
        const box = adaptor.getAttribute(svg, 'viewBox').split(/\s+/).map(Number);
        if (box.length !== 4 || !box.every(Number.isFinite)) return null;
        const width = box[2] / 1000;
        const height = box[3] / 1000;
        const depth = (box[1] + box[3]) / 1000;
        if (width <= 0 || height <= 0 || width > 1000 || height > 1000) return null;
        adaptor.setAttribute(svg, 'width', width * 16);
        adaptor.setAttribute(svg, 'height', height * 16);
        return { svg: adaptor.outerHTML(svg), width, height, depth };
    } catch (_) {
        return null;
    } finally {
        document.clear();
    }
};
