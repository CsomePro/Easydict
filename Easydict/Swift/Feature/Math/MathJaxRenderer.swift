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

    /// Retain a complete snapshot before the caller starts constructing attachments.
    func cachedResults(for expressions: [MathExpression]) -> [String: Result]? {
        var results: [String: Result] = [:]
        for expression in expressions {
            guard let result = cache.object(forKey: expression.cacheKey as NSString) else { return nil }
            results[expression.cacheKey] = result
        }
        return results
    }

    /// Failed expressions are cached too, so malformed input cannot cause a render loop.
    func prepare(_ expressions: [MathExpression], completion: @escaping ([String: Result]) -> Void) {
        queue.async { [self] in
            var results: [String: Result] = [:]
            for expression in expressions {
                if let result = results[expression.cacheKey] ?? cache.object(forKey: expression.cacheKey as NSString) {
                    results[expression.cacheKey] = result
                    continue
                }
                let value = context?.objectForKeyedSubscript("renderMath")?
                    .call(withArguments: [expression.tex, expression.display])?.toDictionary() as? [String: Any]
                let result = Result(value)
                results[expression.cacheKey] = result
                cache.setObject(result, forKey: expression.cacheKey as NSString, cost: result.svg?.utf8.count ?? 1)
            }
            // NSCache can evict entries at any time. Delivery and active labels own their results.
            let prepared = results
            DispatchQueue.main.async { completion(prepared) }
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
