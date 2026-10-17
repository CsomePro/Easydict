//
//  MathJaxRenderer.swift
//  Easydict
//

import Foundation
import JavaScriptCore

/// Serial, offline MathJax execution. Only immutable SVG data crosses the worker queue.
final class MathJaxRenderer {
    static let shared = MathJaxRenderer()

    final class Result {
        let svg: String?
        let width: Double
        let height: Double
        let depth: Double

        init(_ value: [String: Any]?) {
            svg = value?["svg"] as? String
            width = value?["width"] as? Double ?? 0
            height = value?["height"] as? Double ?? 0
            depth = value?["depth"] as? Double ?? 0
        }
    }

    func cached(_ expression: MathExpression) -> Result? {
        cache.object(forKey: expression.cacheKey as NSString)
    }

    /// Failed expressions are cached too, so malformed input cannot cause a render loop.
    func prepare(_ expressions: [MathExpression], completion: @escaping () -> Void) {
        queue.async { [self] in
            for expression in expressions where cached(expression) == nil {
                let value = context?.objectForKeyedSubscript("renderMath")?
                    .call(withArguments: [expression.tex, expression.display])?.toDictionary() as? [String: Any]
                let result = Result(value)
                cache.setObject(result, forKey: expression.cacheKey as NSString, cost: result.svg?.utf8.count ?? 1)
            }
            DispatchQueue.main.async(execute: completion)
        }
    }

    private let queue = DispatchQueue(label: "com.easydict.math-rendering", qos: .userInitiated)
    private let cache: NSCache<NSString, Result> = {
        let cache = NSCache<NSString, Result>()
        cache.countLimit = 256
        cache.totalCostLimit = 16 * 1024 * 1024
        return cache
    }()

    // Initialized and used exclusively on queue. No web or native bridge is exposed to JavaScript.
    private lazy var context: JSContext? = {
        guard let url = Bundle.main.url(forResource: "mathjax-tex-svg", withExtension: "js"),
              let script = try? String(contentsOf: url, encoding: .utf8),
              let context = JSContext()
        else { return nil }
        context.evaluateScript(script)
        guard context.exception == nil else { return nil }
        return context
    }()
}
