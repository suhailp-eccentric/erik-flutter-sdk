import Flutter
import Foundation

final class ErikPlatformViewFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger
    private let assetResolver: ErikAssetResolver

    init(
        messenger: FlutterBinaryMessenger,
        assetResolver: ErikAssetResolver
    ) {
        self.messenger = messenger
        self.assetResolver = assetResolver
        super.init()
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        ErikPlatformView(
            frame: frame,
            viewId: viewId,
            messenger: messenger,
            assetResolver: assetResolver
        )
    }
}
