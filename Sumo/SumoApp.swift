//
//  SumoApp.swift
//  Sumo
//
//  Created by Abderrezak Kamel on 12/12/24.
//

import SwiftUI

@main
struct SumoApp: App {
    var body: some Scene {
        WindowGroup {
            // ContentView()
            CameraViewControllerWrapper()
        }
    }
}

struct CameraViewControllerWrapper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CameraViewController {
        return CameraViewController()
    }

    func updateUIViewController(_ uiViewController: CameraViewController, context: Context) {}
}

