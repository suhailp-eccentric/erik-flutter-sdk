import Foundation
import UIKit
import WebKit

public struct ErikRuntimeState: Equatable {
    public let isReady: Bool
    public let isIntroAnimationPlaying: Bool

    public init(
        isReady: Bool = false,
        isIntroAnimationPlaying: Bool = false
    ) {
        self.isReady = isReady
        self.isIntroAnimationPlaying = isIntroAnimationPlaying
    }

    func toMap() -> [String: Any] {
        [
            "isReady": isReady,
            "isIntroAnimationPlaying": isIntroAnimationPlaying,
        ]
    }
}

public enum ErikDoor: String {
    case frontLeft
    case frontRight
    case rearLeft
    case rearRight
    case boot
    case sunroof
}

private extension ErikDoor {
    var jsName: String {
        switch self {
        case .frontLeft:
            return "FRONT_LEFT_DOOR"
        case .frontRight:
            return "FRONT_RIGHT_DOOR"
        case .rearLeft:
            return "REAR_LEFT_DOOR"
        case .rearRight:
            return "REAR_RIGHT_DOOR"
        case .boot:
            return "BOOT_DOOR"
        case .sunroof:
            return "SUNROOF_OPEN"
        }
    }
}

public final class ErikViewController: UIViewController, WKNavigationDelegate, WKScriptMessageHandler {
    public typealias CommandCompletion = (Result<Void, Error>) -> Void

    enum ErikViewError: Error {
        case missingBrowserAsset
        case missingPanoramaAsset
        case invalidJavascriptResult
    }

    private struct PendingCommand {
        let command: String
        let completion: CommandCompletion
    }

    private enum ActiveSurface {
        case exterior
        case interior
    }

    public var onStateChanged: ((ErikRuntimeState) -> Void)?

    private let browserEntryURL: URL
    private let panoramaImageURL: URL
    private let assetSchemeHandler: ErikAssetSchemeHandler

    private let webContainer = UIView()
    private let panoramaContainer = UIView()
    private let webView: WKWebView
    private var hasScheduledDiagnostics = false

    private var panoramaView: ErikPanoramaView?
    private var pendingCommands: [PendingCommand] = []
    private var isReady = false
    private var isIntroAnimationPlaying = false
    private var activeSurface: ActiveSurface = .exterior

    init(
        browserEntryURL: URL,
        panoramaImageURL: URL,
        assetRootURL: URL
    ) {
        self.browserEntryURL = browserEntryURL
        self.panoramaImageURL = panoramaImageURL
        self.assetSchemeHandler = ErikAssetSchemeHandler(assetRootURL: assetRootURL)

        let contentController = WKUserContentController()
        let bootstrapScript = WKUserScript(
            source: Self.documentStartBridgeScript(bridgeName: Self.bridgeName),
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
        contentController.addUserScript(bootstrapScript)
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController
        configuration.allowsInlineMediaPlayback = true
        configuration.setURLSchemeHandler(
            assetSchemeHandler,
            forURLScheme: Self.assetScheme
        )
        self.webView = WKWebView(frame: .zero, configuration: configuration)

        super.init(nibName: nil, bundle: nil)

        contentController.add(self, name: Self.bridgeName)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        dispose()
    }

    public override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        configureLayout()
        configurePanorama()
        configureWebView()
        updateSurfaceVisibility()
        loadBrowser()
    }

    public static func makeWithBundleAssets() throws -> ErikViewController {
        try makeWithBundleAssets(resolver: ErikAssetResolver())
    }

    public func currentState() -> ErikRuntimeState {
        ErikRuntimeState(
            isReady: isReady,
            isIntroAnimationPlaying: isIntroAnimationPlaying
        )
    }

    public func dispose() {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: Self.bridgeName)
        webView.navigationDelegate = nil
        webView.stopLoading()
    }

    public func openDoor(_ door: ErikDoor, completion: @escaping CommandCompletion) {
        runCommand("__erik.play('\(door.jsName)', 'forward')", completion: completion)
    }

    public func closeDoor(_ door: ErikDoor, completion: @escaping CommandCompletion) {
        runCommand("__erik.play('\(door.jsName)', 'reverse')", completion: completion)
    }

    public func setAllDoorsOpen(_ open: Bool, completion: @escaping CommandCompletion) {
        let direction = open ? "forward" : "reverse"
        runCommand("__erik.allDoors('\(direction)')", completion: completion)
    }

    public func goInterior(completion: @escaping CommandCompletion) {
        panoramaView?.resetView()
        activeSurface = .interior
        updateSurfaceVisibility()
        completion(.success(()))
    }

    public func goExterior(completion: @escaping CommandCompletion) {
        runCommand("__erik.goExterior()") { [weak self] result in
            if case .success = result {
                self?.activeSurface = .exterior
                self?.updateSurfaceVisibility()
            }
            completion(result)
        }
    }

    public func toggleLights(completion: @escaping CommandCompletion) {
        runCommand("__erik.toggleLights()", completion: completion)
    }

    public func setColor(_ colorName: String, completion: @escaping CommandCompletion) {
        let escapedColorName = colorName.replacingOccurrences(of: "'", with: "\\'")
        runCommand("__erik.setColor('\(escapedColorName)')", completion: completion)
    }

    public func skipIntro(completion: @escaping CommandCompletion) {
        runCommand("__erik.skipIntro()", completion: completion)
    }

    public func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == Self.bridgeName else {
            return
        }

        if let payload = message.body as? String {
            handleBridgeMessage(payload)
            return
        }

        guard let payload = message.body as? [String: Any] else {
            return
        }

        switch payload["type"] as? String {
        case "ready":
            setReady(true)
            flushPendingCommands()
        case "console":
            guard let consoleMessage = payload["message"] as? String else {
                return
            }
            handleConsoleMessage(consoleMessage)
        default:
            break
        }
    }

    public func webView(
        _ webView: WKWebView,
        didStartProvisionalNavigation navigation: WKNavigation!
    ) {
        Self.debugLog("Started navigation to \(webView.url?.absoluteString ?? browserEntryURL.absoluteString)")
        setReady(false)
        setIntroAnimationPlaying(false)
    }

    public func webView(
        _ webView: WKWebView,
        didFinish navigation: WKNavigation!
    ) {
        Self.debugLog("Finished navigation to \(webView.url?.absoluteString ?? "<unknown>")")
        injectBootstrapScript()
        scheduleDiagnosticsIfNeeded()
    }

    public func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        Self.debugLog("Navigation failed: \(error.localizedDescription)")
        failPendingCommands(message: error.localizedDescription)
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        Self.debugLog("Provisional navigation failed: \(error.localizedDescription)")
        failPendingCommands(message: error.localizedDescription)
    }

    private func configureLayout() {
        [panoramaContainer, webContainer].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            $0.backgroundColor = .black
            view.addSubview($0)
            NSLayoutConstraint.activate([
                $0.topAnchor.constraint(equalTo: view.topAnchor),
                $0.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                $0.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                $0.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
        }
    }

    private func configurePanorama() {
        let image = UIImage(contentsOfFile: panoramaImageURL.path)
        if let image {
            let panoramaView = ErikPanoramaView(image: image)
            panoramaView.translatesAutoresizingMaskIntoConstraints = false
            panoramaContainer.addSubview(panoramaView)
            NSLayoutConstraint.activate([
                panoramaView.topAnchor.constraint(equalTo: panoramaContainer.topAnchor),
                panoramaView.leadingAnchor.constraint(equalTo: panoramaContainer.leadingAnchor),
                panoramaView.trailingAnchor.constraint(equalTo: panoramaContainer.trailingAnchor),
                panoramaView.bottomAnchor.constraint(equalTo: panoramaContainer.bottomAnchor),
            ])
            self.panoramaView = panoramaView
        }
    }

    private func configureWebView() {
        webView.translatesAutoresizingMaskIntoConstraints = false
        webView.navigationDelegate = self
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .black
        webContainer.addSubview(webView)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: webContainer.topAnchor),
            webView.leadingAnchor.constraint(equalTo: webContainer.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: webContainer.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: webContainer.bottomAnchor),
        ])
    }

    private func loadBrowser() {
        Self.debugLog("Loading Erik browser from \(browserEntryURL.absoluteString)")
        webView.load(URLRequest(url: browserEntryURL))
    }

    private func handleBridgeMessage(_ message: String) {
        Self.debugLog("Bridge message: \(message)")
        if message == "ready" {
            setReady(true)
            flushPendingCommands()
        }
    }

    private func handleConsoleMessage(_ message: String) {
        Self.debugLog("JS console: \(message)")
        if message.contains("Starting trailer camera") {
            setIntroAnimationPlaying(true)
        } else if
            message.contains("Trailer camera sequence finished") ||
            message.contains("Trailer camera sequence skipped")
        {
            setIntroAnimationPlaying(false)
        }
    }

    private func injectBootstrapScript() {
        let script =
            """
            (function bootstrapErikNativeBridge() {
              const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(Self.bridgeName);
              if (!bridge || typeof bridge.postMessage !== 'function') {
                return;
              }

              if (!window.__erikNativeConsolePatched) {
                ['log', 'debug', 'warn', 'error'].forEach(function(level) {
                  const original = console[level];
                  console[level] = function() {
                    try {
                      bridge.postMessage({
                        type: 'console',
                        message: Array.prototype.slice.call(arguments).map(String).join(' ')
                      });
                    } catch (_) {}
                    if (typeof original === 'function') {
                      return original.apply(console, arguments);
                    }
                  };
                });
                window.__erikNativeConsolePatched = true;
              }

              let attempts = 0;
              (function tick() {
                if (typeof window.__erik !== 'undefined') {
                  bridge.postMessage({ type: 'ready' });
                  return;
                }
                if (attempts++ < 60) {
                  setTimeout(tick, 250);
                }
              })();
            })();
            """

        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    private func scheduleDiagnosticsIfNeeded() {
        guard !hasScheduledDiagnostics else {
            return
        }

        hasScheduledDiagnostics = true
        [1.0, 3.0].forEach { delay in
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.logJavascriptDiagnostics(after: delay)
            }
        }
    }

    private func logJavascriptDiagnostics(after delay: Double) {
        let script =
            """
            (async function erikNativeDiagnostics() {
              const stringify = (value) => {
                if (value == null) {
                  return null;
                }
                if (typeof value === 'string') {
                  return value;
                }
                try {
                  return JSON.stringify(value);
                } catch (_) {
                  return String(value);
                }
              };

              const result = {
                href: window.location.href,
                readyState: document.readyState,
                erikType: typeof window.__erik,
                appRootExists: !!document.querySelector('app-root'),
                lastError: window.__erikNativeLastError || null,
                lastUnhandledRejection: window.__erikNativeLastUnhandledRejection || null,
                recentConsoleMessages: Array.isArray(window.__erikNativeConsoleMessages)
                  ? window.__erikNativeConsoleMessages.slice(-8)
                  : [],
              };

              try {
                const projectResponse = await fetch('./erik/resources/project.json');
                result.projectJsonStatus = projectResponse.status;
                result.projectJsonOk = projectResponse.ok;
              } catch (error) {
                result.projectJsonError = stringify(error && error.message ? error.message : error);
              }

              try {
                const wasmResponse = await fetch('./erik_player.wasm');
                result.wasmStatus = wasmResponse.status;
                result.wasmOk = wasmResponse.ok;
              } catch (error) {
                result.wasmError = stringify(error && error.message ? error.message : error);
              }

              return JSON.stringify(result);
            })();
            """

        webView.evaluateJavaScript(script) { result, error in
            if let error {
                Self.debugLog("Diagnostics after \(delay)s failed: \(error.localizedDescription)")
                return
            }

            Self.debugLog(
                "Diagnostics after \(delay)s: \(Self.normalizeJavascriptResult(result) ?? "<nil>")"
            )
        }
    }

    private func runCommand(
        _ command: String,
        completion: @escaping CommandCompletion
    ) {
        if !isReady {
            pendingCommands.append(PendingCommand(command: command, completion: completion))
            return
        }

        evaluateCommand(command, completion: completion)
    }

    private func flushPendingCommands() {
        guard isReady, !pendingCommands.isEmpty else {
            return
        }

        let queuedCommands = pendingCommands
        pendingCommands.removeAll()
        queuedCommands.forEach { pending in
            evaluateCommand(pending.command, completion: pending.completion)
        }
    }

    private func evaluateCommand(
        _ command: String,
        completion: @escaping CommandCompletion
    ) {
        let wrappedCommand =
            """
            (function() {
              try {
                \(command);
                return 'ok';
              } catch (error) {
                return 'error:' + (error && error.message ? error.message : String(error));
              }
            })();
            """

        webView.evaluateJavaScript(wrappedCommand) { result, error in
            if let error {
                completion(.failure(error))
                return
            }

            guard let normalizedResult = Self.normalizeJavascriptResult(result) else {
                completion(.failure(ErikViewError.invalidJavascriptResult))
                return
            }

            if normalizedResult.hasPrefix("error:") {
                completion(.failure(NSError(
                    domain: "com.eccentric.erik",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: String(normalizedResult.dropFirst("error:".count))]
                )))
            } else {
                completion(.success(()))
            }
        }
    }

    private func failPendingCommands(message: String) {
        guard !pendingCommands.isEmpty else {
            return
        }

        let error = NSError(
            domain: "com.eccentric.erik",
            code: 2,
            userInfo: [NSLocalizedDescriptionKey: message]
        )
        let commandsToFail = pendingCommands
        pendingCommands.removeAll()
        commandsToFail.forEach { pending in
            pending.completion(.failure(error))
        }
    }

    private func setReady(_ ready: Bool) {
        guard isReady != ready else {
            return
        }

        isReady = ready
        dispatchState()
    }

    private func setIntroAnimationPlaying(_ playing: Bool) {
        guard isIntroAnimationPlaying != playing else {
            return
        }

        isIntroAnimationPlaying = playing
        dispatchState()
    }

    private func dispatchState() {
        onStateChanged?(currentState())
    }

    private func updateSurfaceVisibility() {
        let showingInterior = activeSurface == .interior

        panoramaContainer.alpha = showingInterior ? 1 : 0
        panoramaContainer.isUserInteractionEnabled = showingInterior

        webContainer.alpha = showingInterior ? 0 : 1
        webContainer.isUserInteractionEnabled = !showingInterior
    }

    private static func normalizeJavascriptResult(_ result: Any?) -> String? {
        switch result {
        case let string as String:
            return string
        case nil:
            return ""
        default:
            return String(describing: result!)
        }
    }

    private static func documentStartBridgeScript(bridgeName: String) -> String {
        """
        (function erikNativeDocumentStartBridge() {
          const bridge = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(bridgeName);
          const post = (payload) => {
            if (!bridge || typeof bridge.postMessage !== 'function') {
              return;
            }
            try {
              bridge.postMessage(payload);
            } catch (_) {}
          };

          const stringify = (value) => {
            if (typeof value === 'string') {
              return value;
            }
            try {
              return JSON.stringify(value);
            } catch (_) {
              return String(value);
            }
          };

          if (!Array.isArray(window.__erikNativeConsoleMessages)) {
            window.__erikNativeConsoleMessages = [];
          }

          if (!window.__erikNativeConsolePatched) {
            ['log', 'debug', 'warn', 'error'].forEach(function(level) {
              const original = console[level];
              console[level] = function() {
                const message = Array.prototype.slice.call(arguments).map(stringify).join(' ');
                window.__erikNativeConsoleMessages.push('[' + level + '] ' + message);
                post({ type: 'console', message: '[' + level + '] ' + message });
                if (typeof original === 'function') {
                  return original.apply(console, arguments);
                }
              };
            });
            window.__erikNativeConsolePatched = true;
          }

          window.addEventListener('error', function(event) {
            const message = event && event.message ? event.message : 'Unknown JavaScript error';
            window.__erikNativeLastError = message;
            post({ type: 'console', message: '[window.error] ' + message });
          });

          window.addEventListener('unhandledrejection', function(event) {
            const reason = event && event.reason;
            const message = reason && reason.message ? reason.message : stringify(reason);
            window.__erikNativeLastUnhandledRejection = message;
            post({ type: 'console', message: '[unhandledrejection] ' + message });
          });

          let attempts = 0;
          (function tick() {
            if (typeof window.__erik !== 'undefined') {
              post({ type: 'ready' });
              return;
            }
            if (attempts++ < 120) {
              setTimeout(tick, 250);
            } else {
              post({ type: 'console', message: '[ready-timeout] window.__erik was not defined after polling' });
            }
          })();
        })();
        """
    }

    private static func debugLog(_ message: String) {
        NSLog("[ErikViewController] %@", message)
    }

    static func makeWithBundleAssets(resolver: ErikAssetResolver) throws -> ErikViewController {
        guard let browserEntryAssetURL = resolver.assetURL(for: "erik_browser/index.html") else {
            throw ErikViewError.missingBrowserAsset
        }
        guard let panoramaURL = resolver.assetURL(for: "interior/panorama_interior_v2.webp") else {
            throw ErikViewError.missingPanoramaAsset
        }
        let assetRootURL = browserEntryAssetURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        guard let browserEntryURL = URL(
            string: "\(assetScheme)://bundle/erik_browser/index.html"
        ) else {
            throw ErikViewError.missingBrowserAsset
        }
        return ErikViewController(
            browserEntryURL: browserEntryURL,
            panoramaImageURL: panoramaURL,
            assetRootURL: assetRootURL
        )
    }

    private static let bridgeName = "ErikBridge"
    private static let assetScheme = "erik-assets"
}
