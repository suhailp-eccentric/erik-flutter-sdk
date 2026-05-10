import SceneKit
import UIKit

final class ErikPanoramaView: UIView {
    private let sceneView = SCNView()
    private let cameraNode = SCNNode()

    private var yaw: Float = 0
    private var pitch: Float = 0
    private var fieldOfView: CGFloat = 100

    init(image: UIImage) {
        super.init(frame: .zero)
        configureScene(image: image)
        configureGestures()
        resetView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func resetView() {
        // SceneKit's inside-sphere camera faces the opposite seam by default.
        // Start the panorama rotated to match Android's forward-facing interior.
        yaw = .pi
        pitch = 0
        fieldOfView = 100
        applyCameraState()
    }

    private func configureScene(image: UIImage) {
        let scene = SCNScene()

        let camera = SCNCamera()
        camera.fieldOfView = fieldOfView
        camera.zNear = 0.01
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3Zero
        scene.rootNode.addChildNode(cameraNode)

        let sphere = SCNSphere(radius: 10)
        let material = SCNMaterial()
        material.diffuse.contents = image
        material.isDoubleSided = true
        material.cullMode = .front
        material.lightingModel = .constant
        sphere.firstMaterial = material

        let sphereNode = SCNNode(geometry: sphere)
        sphereNode.scale = SCNVector3(-1, 1, 1)
        scene.rootNode.addChildNode(sphereNode)

        sceneView.scene = scene
        sceneView.backgroundColor = .black
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        sceneView.isPlaying = true
        sceneView.autoenablesDefaultLighting = false
        sceneView.allowsCameraControl = false

        addSubview(sceneView)
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: trailingAnchor),
            sceneView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func configureGestures() {
        let panRecognizer = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sceneView.addGestureRecognizer(panRecognizer)

        let pinchRecognizer = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        sceneView.addGestureRecognizer(pinchRecognizer)
    }

    @objc
    private func handlePan(_ recognizer: UIPanGestureRecognizer) {
        let translation = recognizer.translation(in: sceneView)
        recognizer.setTranslation(.zero, in: sceneView)

        // Match Android's swipe direction for the interior panorama on both axes.
        yaw += Float(translation.x) * 0.005
        pitch += Float(translation.y) * 0.005
        pitch = max(-(.pi / 2.2), min(.pi / 2.2, pitch))
        applyCameraState()
    }

    @objc
    private func handlePinch(_ recognizer: UIPinchGestureRecognizer) {
        fieldOfView /= recognizer.scale
        recognizer.scale = 1
        fieldOfView = max(40, min(100, fieldOfView))
        applyCameraState()
    }

    private func applyCameraState() {
        cameraNode.eulerAngles = SCNVector3(pitch, yaw, 0)
        cameraNode.camera?.fieldOfView = fieldOfView
    }
}
