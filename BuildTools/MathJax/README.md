# Easydict MathJax bundle

The app uses MathJax **4.1.3** and `@mathjax/mathjax-tex-font` **4.1.3** under
Apache-2.0. `entry.cjs` is the app-owned wrapper; `build.cjs` bundles only its
reachable dependencies with esbuild **0.25.12**. The lockfile pins build inputs.

From the repository root, rebuild the committed runtime asset with:

```sh
npm ci --prefix BuildTools/MathJax --ignore-scripts
npm run --prefix BuildTools/MathJax build
```

Outputs are `Easydict/Swift/Feature/Math/mathjax-tex-svg.js` and
`Easydict/Swift/Feature/Math/MathJax-LICENSE.txt`. Normal Xcode builds use these
committed files and do not need Node, npm, a CDN, or network access for rendering.

The bundle runs on a serial JavaScriptCore queue with MathJax's `liteAdaptor`.
It exposes no native bridge or browser/network APIs. TeX packages are limited to
`base`, `ams`, `newcommand`, and `boldsymbol`; unsupported commands fall back to
source text. Each expression gets a fresh TeX processor so macro definitions do
not cross translation boundaries. Input size, macro expansion, cache size, and
formulas per result are bounded. SVG is rendered by AppKit as a text attachment.
The TeX font includes its glyph data and avoids MathJax 4's dynamic font loading.

Sources:

- [MathJax source, 4.1.3](https://github.com/mathjax/MathJax-src/tree/4.1.3)
- [MathJax TeX font package](https://www.npmjs.com/package/@mathjax/mathjax-tex-font/v/4.1.3)
- [MathJax font support](https://docs.mathjax.org/en/v4.0/output/fonts.html)
- [MathJax TeX delimiter options](https://docs.mathjax.org/en/latest/options/input/tex.html)

The app-owned delimiter scanner runs before Markdown conversion and skips code
spans/fences. Single-dollar math requires non-whitespace at both ends and does
not close immediately before a digit, reducing accidental currency matching.
Unclosed delimiters and parse failures stay visible. Native selection copying
substitutes the original delimited TeX for formula attachment characters.
