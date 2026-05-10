import Flutter
import Foundation

final class ErikAssetResolver {
    private let resourceBundleName = "erik_flutter_sdk_resources"
    private lazy var candidateBundles: [Bundle] = {
        var bundles: [Bundle] = []
        let owningBundle = Bundle(for: ErikFlutterSdkPlugin.self)

        if let resourceBundle = Self.loadResourceBundle(
            named: resourceBundleName,
            from: owningBundle
        ) {
            bundles.append(resourceBundle)
        }

        bundles.append(owningBundle)

        if let mainResourceBundle = Self.loadResourceBundle(
            named: resourceBundleName,
            from: .main
        ) {
            bundles.append(mainResourceBundle)
        }

        bundles.append(.main)
        return bundles
    }()

    init() {}

    convenience init(registrar _: FlutterPluginRegistrar) {
        self.init()
    }

    func assetURL(for relativePath: String) -> URL? {
        let normalizedPath = relativePath.hasPrefix("/")
            ? String(relativePath.dropFirst())
            : relativePath

        for bundle in candidateBundles {
            let url = bundle.bundleURL.appendingPathComponent(normalizedPath)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }

        return nil
    }

    private static func loadResourceBundle(
        named bundleName: String,
        from bundle: Bundle
    ) -> Bundle? {
        guard let bundleURL = bundle.url(
            forResource: bundleName,
            withExtension: "bundle"
        ) else {
            return nil
        }
        return Bundle(url: bundleURL)
    }
}
