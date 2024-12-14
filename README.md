# WrestlingRef Project Setup Guide

Welcome to the WrestlingRef project! This guide will walk you through the setup process for both the backend and the iOS application.

---

## Project Structure

Here is the structure of the WrestlingRef project as seen in Xcode:

- **Sumo (Xcode Project)**
  - **main** (Backend folder)
  - **requirements** (Backend dependencies file)
  - **Sumo** (iOS app folder)
    - **Preview Content**
    - **Assets** (Contains app assets like images)
    - **CameraViewController.swift** (Handles camera functionality and backend communication)
    - **ContentView.swift** (Main SwiftUI content)
    - **SumoApp.swift** (Entry point for the app)
  - **SumoTests** (Unit testing files for the app)
    - **SumoTests.swift**
  - **SumoUITests** (UI testing files for the app)
    - **SumoUITests.swift**
    - **SumoUITestsLaunchTests.swift**

---

## Backend Setup

1. **Navigate to the Backend Folder:**
   ```bash
   cd main
   ```

2. **Install Dependencies:**
   - Create and activate a Python virtual environment:
     ```bash
     python3 -m venv venv
     source venv/bin/activate  # macOS/Linux
     venv\Scripts\activate   # Windows
     ```
   - Install the required Python libraries:
     ```bash
     pip install -r requirements.txt
     ```

3. **Run the Backend:**
   - Start the backend server:
     ```bash
     python main.py
     ```
   - The server will start on your local machine at `http://127.0.0.1:5000`.

---

## iOS App Configuration

1. **Open the Project in Xcode:**
   - Navigate to the project directory and open the `.xcodeproj` file:
     ```bash
     open Sumo.xcodeproj
     ```

2. **Set the Backend IP Address:**
   - Open `CameraViewController.swift` in Xcode.
   - Locate the line defining the backend URL:
     ```swift
     let backendURL = "http://<YOUR_IP_ADDRESS>:5000"
     ```
   - Replace `<YOUR_IP_ADDRESS>` with your computer's IP address on the same network as your iPhone.
     - To find your IP address:
       - **macOS:** Run `ifconfig | grep inet` in the terminal.
       - **Windows:** Run `ipconfig` in the Command Prompt.
   - Example:
     ```swift
     let backendURL = "http://192.168.1.100:5000"
     ```

3. **Connect an iOS Device:**
   - Ensure your iPhone is connected to the same Wi-Fi network as your computer.
   - Use a USB cable to connect the device to your computer.

4. **Run the App:**
   - Select your device in the Xcode toolbar.
   - Press the **Run** button or use `Cmd + R`.

---

## Testing the System

1. **Ensure the Backend is Running:**
   - The backend must be running on your laptop and accessible at the IP address you configured in `CameraViewController.swift`.

2. **Launch the App:**
   - Use the app on your iPhone for real-time analysis and communication with the backend.

---

## Troubleshooting

### Common Issues

- **Backend Connection Errors:**
  - Ensure your laptop and iPhone are on the same network.
  - Verify the IP address in `CameraViewController.swift` matches your laptop's IP.

- **Backend Not Running:**
  - Check that the Python server (`main.py`) is running and no errors occurred during startup.

- **Dependencies Missing:**
  - Ensure all required Python packages are installed using `pip install -r requirements.txt`.

- **App Build Errors:**
  - Verify that Xcode is configured properly and your iPhone is connected.

---

## Project Notes

- The **backend** folder contains all Python code and logic for the backend server.
- The **iOS app** is built using Swift and SwiftUI, with `CameraViewController.swift` as the main interface between the app and the backend.
- The **SumoTests** and **SumoUITests** folders provide testing support for unit and UI-level verification of the app.

Feel free to reach out if you have questions or encounter issues while setting up the project!

