import UIKit
import AVFoundation

class CameraViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureDepthDataOutputDelegate {
    private var captureSession: AVCaptureSession!
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private let frameProcessingInterval: TimeInterval = 2.0
    private var lastFrameTime = Date.distantPast
    private var lastDepthData: [Float]?

    private let detectionLabel: UILabel = {
        let label = UILabel()
        label.text = ""
        label.textColor = .red
        label.backgroundColor = .black.withAlphaComponent(0.5)
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "Camera"

        setupCamera()
        setupDetectionLabel()
    }

    private func setupDetectionLabel() {
        view.addSubview(detectionLabel)

        NSLayoutConstraint.activate([
            detectionLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 10),
            detectionLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            detectionLabel.widthAnchor.constraint(equalToConstant: 200),
            detectionLabel.heightAnchor.constraint(equalToConstant: 40)

        ])
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

        let depthDataOutput = AVCaptureDepthDataOutput()
        depthDataOutput.setDelegate(self, callbackQueue: DispatchQueue(label: "depthDataQueue"))
        if captureSession.canAddOutput(depthDataOutput) {
            captureSession.addOutput(depthDataOutput)
        }

        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)

        // Ensure the constant label is always on top
        view.bringSubviewToFront(detectionLabel)

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
        let uiImage = UIImage(ciImage: ciImage)

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

    struct SkeletonPoint: Codable {
        let x: Float
        let y: Float
        let z: Float
        let visibility: Float
    }

    struct ProcessFrameResponse: Codable {
        let skeleton: [SkeletonPoint]
        let ground_contacts: [String]
    }

    private func sendFrameToBackend(image: UIImage, depthData: [Float]?) {
        guard let url = URL(string: "http://10.0.0.22:8000/process-frame/") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"frame.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)

        if let depthData = depthData {
            let depthDataString = depthData.map { String($0) }.joined(separator: ",")
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"depthData\"; filename=\"depth.txt\"\r\n".data(using: .utf8)!)
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

            guard let data = data else {
                print("Error: No data received.")
                return
            }

            do {
                let result = try JSONDecoder().decode(ProcessFrameResponse.self, from: data)
                DispatchQueue.main.async {
                    let groundContacts = result.ground_contacts
                    let label = groundContacts.isEmpty ? "No contacts" : groundContacts.joined(separator: ", ")
                    self.detectionLabel.text = " contacts : \(label)"
                    print("Frame captured at \(label)")
                }
            } catch {
                print("Error decoding response: \(error)")
            }
        }.resume()
    }
}
