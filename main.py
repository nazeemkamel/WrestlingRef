from fastapi import FastAPI, UploadFile, File, HTTPException
import cv2
import numpy as np
import mediapipe as mp
from typing import List, Dict
import uvicorn

# Initialize FastAPI
app = FastAPI()

# Initialize MediaPipe Pose
mp_pose = mp.solutions.pose
pose = mp_pose.Pose(static_image_mode=True, model_complexity=1, min_detection_confidence=0.5, min_tracking_confidence=0.5)

# Define a ground level threshold
GROUND_THRESHOLD = 0.2  # Adjust this value based on your setup

@app.post("/process-frame/")
async def process_frame(frame: UploadFile = File(...)):
    """
    Endpoint to process a single image frame and depth data for pose estimation.
    """
    if not frame.filename.endswith(("jpg", "jpeg", "png")):
        raise HTTPException(status_code=400, detail="Invalid file type for frame. Please upload an image.")
    # if depth and not depth.filename.endswith("txt"):
    #     raise HTTPException(status_code=400, detail="Invalid file type for depth data. Please upload a text file.")

    try:
        # Read and decode the image
        frame_data = await frame.read()
        image = cv2.imdecode(np.frombuffer(frame_data, np.uint8), cv2.IMREAD_COLOR)

        # Read and parse the depth data if provided
        # depth_array = None
        # if depth:
        #     depth_data = await depth.read()
        #     depth_array = np.array([float(x) for x in depth_data.decode().split(",")])

        #     # for debugging purposes, store the depth data
        #     with open("depth.txt", "wb") as file_d:
        #         file_d.write(depth_data)

        # # for debugging purposes, store the image
        # with open("frame.jpg", "wb") as file_f:
        #     file_f.write(frame_data)

        # Convert image to RGB for MediaPipe
        rgb_image = cv2.cvtColor(image, cv2.COLOR_BGR2RGB)

        # Process the image using MediaPipe Pose
        results = pose.process(rgb_image)

        skeleton_points: List[Dict[str, float]] = []

        if results.pose_landmarks:
            for i, landmark in enumerate(results.pose_landmarks.landmark):
                skeleton_points.append({
                    "x": landmark.x,  # Normalized [0, 1]
                    "y": landmark.y,  # Normalized [0, 1]
                    "z": landmark.z,  # Normalized depth
                    "visibility": landmark.visibility  # Confidence
                })

        # TODO: Integrate depth data with skeleton points

        # Check for ground contact
        results = detect_ground_contact(skeleton_points)

        print("Result:", {"skeleton": results})
        return {"skeleton": results}

    except Exception as e:
        print("Error processing frame:", e)
        raise HTTPException(status_code=500, detail=f"Internal server error: {e}")

def detect_ground_contact(skeleton_points: List[Dict[str, float]]) -> List[str]:
    """
    Detects if any joint other than the feet is close to the ground.
    """
    results = []
    joint_names = [
        "nose", "left_eye_inner", "left_eye", "left_eye_outer", "right_eye_inner", "right_eye",
        "right_eye_outer", "left_ear", "right_ear", "mouth_left", "mouth_right", "left_shoulder",
        "right_shoulder", "left_elbow", "right_elbow", "left_wrist", "right_wrist", "left_pinky",
        "right_pinky", "left_index", "right_index", "left_thumb", "right_thumb", "left_hip",
        "right_hip", "left_knee", "right_knee", "left_ankle", "right_ankle", "left_heel",
        "right_heel", "left_foot_index", "right_foot_index"
    ]

    # Indices for foot joints to exclude from detection
    foot_indices = {27, 28, 29, 30, 31, 32}  # "left_ankle", "right_ankle", "left_heel", "right_heel", "left_foot_index", "right_foot_index"

    if len(skeleton_points) != 33:
        return results
    min_foot_y = min(skeleton_points[27]["y"],skeleton_points[28]["y"],skeleton_points[29]["y"],skeleton_points[30]["y"],skeleton_points[31]["y"],skeleton_points[32]["y"])
    for i, point in enumerate(skeleton_points):
       if i not in foot_indices and point["visibility"] > 0.5 and point["y"] >= min_foot_y:
           results.append({"x": point["x"], "y": point["y"], "min": min_foot_y, "label": joint_names[i], "ground_contact": True})
       else:
          results.append({"x": point["x"], "y": point["y"], "min": min_foot_y, "label": joint_names[i], "ground_contact": False})

    return results

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
