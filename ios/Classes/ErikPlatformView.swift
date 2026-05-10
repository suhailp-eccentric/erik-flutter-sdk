import Flutter
import UIKit

final class ErikPlatformView: NSObject, FlutterPlatformView {
    private let channel: FlutterMethodChannel
    private let containerView: UIView
    private let erikViewController: ErikViewController?

    init(
        frame: CGRect,
        viewId: Int64,
        messenger: FlutterBinaryMessenger,
        assetResolver: ErikAssetResolver
    ) {
        self.channel = FlutterMethodChannel(
            name: "erik_flutter_sdk/view_\(viewId)",
            binaryMessenger: messenger
        )
        self.containerView = UIView(frame: frame)

        do {
            let erikViewController = try ErikViewController.makeWithBundleAssets(resolver: assetResolver)
            self.erikViewController = erikViewController
            super.init()
            channel.setMethodCallHandler(handle)
            erikViewController.onStateChanged = { [weak self] state in
                self?.channel.invokeMethod("onStateChanged", arguments: state.toMap())
            }
            attach(viewController: erikViewController)
            channel.invokeMethod("onStateChanged", arguments: erikViewController.currentState().toMap())
        } catch {
            self.erikViewController = nil
            super.init()
            channel.setMethodCallHandler(handle)
            let label = UILabel(frame: frame)
            label.numberOfLines = 0
            label.textAlignment = .center
            label.textColor = .white
            label.text = "ErikView failed to load iOS assets.\n\(error.localizedDescription)"
            label.backgroundColor = .black
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            containerView.backgroundColor = .black
            containerView.addSubview(label)
        }
    }

    deinit {
        channel.setMethodCallHandler(nil)
        erikViewController?.dispose()
    }

    func view() -> UIView {
        containerView
    }

    private func attach(viewController: ErikViewController) {
        viewController.loadViewIfNeeded()
        let hostedView = viewController.view!
        hostedView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = .black
        containerView.addSubview(hostedView)
        NSLayoutConstraint.activate([
            hostedView.topAnchor.constraint(equalTo: containerView.topAnchor),
            hostedView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            hostedView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            hostedView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let erikViewController else {
            result(
                FlutterError(
                    code: "view_unavailable",
                    message: "ErikView is unavailable on iOS.",
                    details: nil
                )
            )
            return
        }

        switch call.method {
        case "getState":
            result(erikViewController.currentState().toMap())
        case "goExterior":
            erikViewController.goExterior(completion: commandResult(result))
        case "goInterior":
            erikViewController.goInterior(completion: commandResult(result))
        case "toggleLights":
            erikViewController.toggleLights(completion: commandResult(result))
        case "setColor":
            guard let colorName = Self.colorName(from: call.arguments) else {
                result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a non-empty color name.",
                        details: nil
                    )
                )
                return
            }
            erikViewController.setColor(colorName, completion: commandResult(result))
        case "skipIntro":
            erikViewController.skipIntro(completion: commandResult(result))
        case "openDoor":
            guard let door = Self.door(from: call.arguments) else {
                result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a valid door name.",
                        details: nil
                    )
                )
                return
            }
            erikViewController.openDoor(door, completion: commandResult(result))
        case "closeDoor":
            guard let door = Self.door(from: call.arguments) else {
                result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a valid door name.",
                        details: nil
                    )
                )
                return
            }
            erikViewController.closeDoor(door, completion: commandResult(result))
        case "setAllDoorsOpen":
            guard let open = Self.openFlag(from: call.arguments) else {
                result(
                    FlutterError(
                        code: "invalid_arguments",
                        message: "Expected a boolean open flag.",
                        details: nil
                    )
                )
                return
            }
            erikViewController.setAllDoorsOpen(open, completion: commandResult(result))
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func commandResult(_ result: @escaping FlutterResult) -> (Result<Void, Error>) -> Void {
        { commandResult in
            switch commandResult {
            case .success:
                result(nil)
            case let .failure(error):
                result(
                    FlutterError(
                        code: "erik_command_failed",
                        message: error.localizedDescription,
                        details: nil
                    )
                )
            }
        }
    }

    private static func colorName(from arguments: Any?) -> String? {
        switch arguments {
        case let colorName as String where !colorName.isEmpty:
            colorName
        case let payload as [AnyHashable: Any]:
            (payload["color"] as? String)?.nilIfEmpty
        default:
            nil
        }
    }

    private static func openFlag(from arguments: Any?) -> Bool? {
        switch arguments {
        case let open as Bool:
            open
        case let payload as [AnyHashable: Any]:
            payload["open"] as? Bool
        default:
            nil
        }
    }

    private static func door(from arguments: Any?) -> ErikDoor? {
        let rawDoor: String?
        switch arguments {
        case let door as String:
            rawDoor = door
        case let payload as [AnyHashable: Any]:
            rawDoor = payload["door"] as? String
        default:
            rawDoor = nil
        }

        guard let rawDoor else {
            return nil
        }

        return ErikDoor(rawValue: rawDoor)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
