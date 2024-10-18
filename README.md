# Sumo Wrestling Referee (Multi-Person Pose Tracking Web Application)

## **Goal**

The goal of this project is to develop an AI-based referee system that can **score sumo wrestling matches** by detecting whether wrestlers step out of the ring or touch the ground with any part of their body other than their feet. This web-based application leverages **MediaPipe Pose Estimation** to track the poses of up to two people in real-time using a live webcam feed. The system will use body landmark detection and connection analysis to determine potential rule violations in sumo wrestling.

## **Technologies**

- **MediaPipe**: For real-time pose estimation.
- **JavaScript**: For handling client-side logic, video streaming, and interactions.
- **HTML/CSS**: For structuring and styling the web interface.
- **Webcam API**: To capture live video via the browser.

## **File Structure**

```bash
.
├── index.html        # Main HTML structure for the web application
├── style.css         # Styling for the web app
├── main.js           # JavaScript handling pose tracking logic
├── package.json      # Node.js project dependencies and metadata
├── package-lock.json # Lock file for dependency versions

```
## **How to Run the Project**

### 1. **Run Locally**

To run the project locally, you can either open `index.html` directly in a web browser or serve the project using a local HTTP server:

#### Option 1: Open Directly
1. Open the `index.html` file in your web browser by double-clicking it or using your browser's "Open File" option.

#### Option 2: Use a Simple HTTP Server
1. Open a terminal or command prompt.
2. Navigate to the directory where your project is located.
3. Run the following command to start a local server:
   ```bash
   python -m http.server 8000
    ```
4. Open your web browser and go to http://localhost:8000.
