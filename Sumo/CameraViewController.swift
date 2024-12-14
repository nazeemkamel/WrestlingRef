import UIKit
import AVFoundation

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let frameProcessingInterval: TimeInterval = 2.0
    private var lastFrameTime = Date.distantPast
    private var lastDepthData: [Float]?
    private var shapeLayer: CAShapeLayer!
    
    private let detectionTextView: UITextView = {
        let textView = UITextView()
        textView.text = ""
        textView.textColor = .red
        textView.backgroundColor = .black.withAlphaComponent(0.5)
        textView.font = UIFont.boldSystemFont(ofSize: 20)
        textView.textAlignment = .center
        textView.isEditable = false
        textView.isScrollEnabled = true
        textView.translatesAutoresizingMaskIntoConstraints = false
        return textView
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Camera"

        setupCamera()
        setupShapeLayer()
        setupdetectionTextView()
    }
    
    private func setupdetectionTextView() {
        view.addSubview(detectionTextView)

        NSLayoutConstraint.activate([
            detectionTextView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            detectionTextView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            detectionTextView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            detectionTextView.heightAnchor.constraint(equalToConstant: 100)
        ])
    }

    private func setupShapeLayer() {
        shapeLayer = CAShapeLayer()
        shapeLayer.frame = view.bounds
        shapeLayer.strokeColor = UIColor.red.cgColor
        shapeLayer.fillColor = UIColor.red.cgColor
        view.layer.addSublayer(shapeLayer)
    }

    private func setupCamera() {
        captureSession = AVCaptureSession()
        captureSession.sessionPreset = .medium

        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            fatalError("No rear camera found.")
        }

        let videoInput = try! AVCaptureDeviceInput(device: videoCaptureDevice)
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        }

        // Enable to capture LIDAR depth data
//        let depthDataOutput = AVCaptureDepthDataOutput()
//        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthDataQueue"))
//        if captureSession.canAddOutput(depthDataOutput) {
//            captureSession.addOutput(depthDataOutput)
//        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Ensure the constant label is always on top
        view.bringSubviewToFront(detectionTextView)

        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning()
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastFrameTime) >= frameProcessingInterval else { return }
        lastFrameTime = currentTime

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
 
        // Adjust the image orientation based on the device orientation
        let orientation: UIImage.Orientation
        switch UIDevice.current.orientation {
        case .portrait:
            orientation = .right
        case .portraitUpsideDown:
            orientation = .left
        case .landscapeLeft:
            orientation = .up
        case .landscapeRight:
            orientation = .down
        default:
            orientation = .right
        }

        let uiImage = UIImage(ciImage: ciImage, scale: 1.0, orientation: orientation)

        sendFrameToBackend(image: uiImage, depthData: lastDepthData)
    }


    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        let depthMap = depthData.depthDataMap
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        var depthArray = [Float]()
        for y in 0..<height {
            let rowData = CVPixelBufferGetBaseAddress(depthMap)! + y * CVPixelBufferGetBytesPerRow(depthMap)
            for x in 0..<width {
                let depth = rowData.assumingMemoryBound(to: Float32.self)[x]
                depthArray.append(depth)
            }
        }
        CVPixelBufferUnlockBaseAddress(depthMap, .readOnly)

        lastDepthData = depthArray
    }

    private func drawSkeleton(_ skeleton: [SkeletonPoint]) {
        shapeLayer.sublayers?.forEach { $0.removeFromSuperlayer() }

        guard !skeleton.isEmpty else {
            return
        }
      
        // Define the connections between the skeleton points
        let connections: [(Int, Int)] = [
            (0,1),(1,2),(2,3),(3,7),
            (0,4),(4,5),(5,6),(6,8),
            (9,10),
            (11,12),(11,13),(12,14),
            (13,15),(14,16),
            (15,17),(17,19),(19,15),(15,21),
            (16,18),(18,20),(20,16),(16,21),
            (11,23),(12,24),(23,24),
            (23,25),(25,27),(27,29),(29,31),(31,27),
            (24,26),(26,28),(28,30),(30,32),(32,28)
        ]

        // Draw the connections
        for connection in connections {
            if let startPoint = skeleton[safe: connection.0], let endPoint = skeleton[safe: connection.1] {
                let startPoint = CGPoint(x: CGFloat(startPoint.x) * view.bounds.width, y: CGFloat(startPoint.y) * view.bounds.height)
                let endPoint = CGPoint(x: CGFloat(endPoint.x) * view.bounds.width, y: CGFloat(endPoint.y) * view.bounds.height)
                let linePath = UIBezierPath()
                linePath.move(to: startPoint)
                linePath.addLine(to: endPoint)
                let lineLayer = CAShapeLayer()
                lineLayer.path = linePath.cgPath
                lineLayer.strokeColor = UIColor.green.cgColor
                lineLayer.lineWidth = 2.0
                shapeLayer.addSublayer(lineLayer)
            }
        }

        // Draw the min heigh line
        let yMin = skeleton.map { $0.min }.min() ?? 0
        let minHeighLinePath = UIBezierPath()
        minHeighLinePath.move(to: CGPoint(x: 0, y: CGFloat(yMin) * view.bounds.height))
        minHeighLinePath.addLine(to: CGPoint(x: view.bounds.width, y: CGFloat(yMin) * view.bounds.height))
        let minHeighLineLayer = CAShapeLayer()
        minHeighLineLayer.path = minHeighLinePath.cgPath
        minHeighLineLayer.strokeColor = UIColor.red.cgColor
        minHeighLineLayer.lineWidth = 1.0
        minHeighLineLayer.lineDashPattern = [4, 4]
        shapeLayer.addSublayer(minHeighLineLayer)

        // Draw the points
        for point in skeleton {
            let circlePath = UIBezierPath(arcCenter: CGPoint(x: CGFloat(point.x) * view.bounds.width, y: CGFloat(point.y) * view.bounds.height), radius: 5, startAngle: 0, endAngle: CGFloat.pi * 2, clockwise: true)
            let circleLayer = CAShapeLayer()
            circleLayer.path = circlePath.cgPath
            circleLayer.fillColor = point.ground_contact ? UIColor.red.cgColor : UIColor.blue.cgColor
            shapeLayer.addSublayer(circleLayer)
        }

    }

    struct SkeletonPoint: Codable {
        let x: Float    
        let y: Float
        let min: Float
        let label: String
        let ground_contact: Bool
    }
    
    struct ProcessFrameResponse: Codable {
        let skeleton: [SkeletonPoint]
    }

    private func sendFrameToBackend(image: UIImage, depthData: [Float]?) {
        guard let url = URL(string: "http://10.15.162.38:8000/process-frame/") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"frame\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        if let depthData = depthData {
            let depthDataString = depthData.map { String($0) }.joined(separator: ",")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"depth\"; filename=\"depth.txt\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: text/plain\r\n\r\n".data(using: .utf8)!)
            body.append(depthDataString.data(using: .utf8)!)
            body.append("\r\n".data(using: .utf8)!)
        }

        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending frame: \(error)")
                return
            }

            guard let httpResponse = response as? HTTPURLResponse else {
                print("Error: No HTTP response received.")
                return
            }

            guard (200...299).contains(httpResponse.statusCode) else {
                print("Error: HTTP response code \(httpResponse.statusCode)")
                return
            }

            guard let data = data, !data.isEmpty else {
                print("Error: No data received.")
                return
            }

            do {
                let result = try JSONDecoder().decode(ProcessFrameResponse.self, from: data)
                DispatchQueue.main.async {
                    let groundContacts = result.skeleton.filter { $0.ground_contact }
                    let groundContactsLabels = groundContacts.map { $0.label }
                    let label = groundContacts.isEmpty ? "No contacts" : groundContactsLabels.joined(separator: ", ")
                    self.detectionTextView.text = label
                    self.drawSkeleton(result.skeleton)
                    print("Frame captured at \(label)")
                }
            } catch {
                print("Error decoding response: \(error)")
            }
        }.resume()
    }
}
