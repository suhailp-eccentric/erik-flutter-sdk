import Foundation
import WebKit

final class ErikAssetSchemeHandler: NSObject, WKURLSchemeHandler {
    private let assetRootURL: URL

    init(assetRootURL: URL) {
        self.assetRootURL = assetRootURL
        super.init()
    }

    func webView(
        _ webView: WKWebView,
        start urlSchemeTask: WKURLSchemeTask
    ) {
        guard let fileURL = resolveAssetURL(for: urlSchemeTask.request.url) else {
            let response = HTTPURLResponse(
                url: urlSchemeTask.request.url ?? assetRootURL,
                statusCode: 404,
                httpVersion: "HTTP/1.1",
                headerFields: ["Content-Type": "text/plain"]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(Data("Not found".utf8))
            urlSchemeTask.didFinish()
            return
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let response = HTTPURLResponse(
                url: urlSchemeTask.request.url ?? fileURL,
                statusCode: 200,
                httpVersion: "HTTP/1.1",
                headerFields: [
                    "Content-Type": mimeType(for: fileURL.pathExtension),
                    "Content-Length": "\(data.count)",
                    "Cache-Control": "no-cache",
                ]
            )!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(
        _ webView: WKWebView,
        stop urlSchemeTask: WKURLSchemeTask
    ) {
        // No long-lived task state to cancel for bundle-backed requests.
    }

    private func resolveAssetURL(for requestURL: URL?) -> URL? {
        guard let requestURL else {
            return nil
        }

        let requestedPath = requestURL.path
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let normalizedPath = requestedPath.isEmpty ? "index.html" : requestedPath

        let candidateRelativePaths = [
            normalizedPath,
            "erik_browser/\(normalizedPath)",
        ]

        for relativePath in candidateRelativePaths {
            let candidateURL = assetRootURL.appendingPathComponent(relativePath)
            if FileManager.default.fileExists(atPath: candidateURL.path) {
                return candidateURL
            }
        }

        return nil
    }

    private func mimeType(for fileExtension: String) -> String {
        switch fileExtension.lowercased() {
        case "html":
            return "text/html"
        case "js":
            return "text/javascript"
        case "css":
            return "text/css"
        case "json":
            return "application/json"
        case "wasm":
            return "application/wasm"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "webp":
            return "image/webp"
        case "svg":
            return "image/svg+xml"
        case "ico":
            return "image/x-icon"
        case "woff":
            return "font/woff"
        case "woff2":
            return "font/woff2"
        case "ttf":
            return "font/ttf"
        case "mp4":
            return "video/mp4"
        case "hdr", "ash", "erik":
            return "application/octet-stream"
        default:
            return "application/octet-stream"
        }
    }

    private func textEncodingName(for fileExtension: String) -> String? {
        switch fileExtension.lowercased() {
        case "html", "js", "css", "json":
            return "utf-8"
        default:
            return nil
        }
    }
}
