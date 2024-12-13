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
async def process_frame(file: UploadFile = File(...)):
    """
    Endpoint to process a single image frame for pose estimation.
    """
    if not file.filename.endswith(("jpg", "jpeg", "png")):
        raise HTTPException(status_code=400, detail="Invalid file type. Please upload an image.")

    try:
        # Read and decode the image
        file_data = await file.read()
        image = cv2.imdecode(np.frombuffer(file_data, np.uint8), cv2.IMREAD_COLOR)

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

        # Check for ground contact
        ground_contacts = detect_ground_contact(skeleton_points)

        print("Result:", {"skeleton": skeleton_points, "ground_contacts": ground_contacts})
        return {"skeleton": skeleton_points, "ground_contacts": ground_contacts}

    except Exception as e:
        print("Error processing frame:", e)
        raise HTTPException(status_code=500, detail=f"Internal server error: {e}")

def detect_ground_contact(skeleton_points: List[Dict[str, float]]) -> List[str]:
    """
    Detects if any joint other than the feet is close to the ground.
    """
    ground_contacts = []
    joint_names = [
        "nose", "left_eye_inner", "left_eye", "left_eye_outer", "right_eye_inner", "right_eye",
        "right_eye_outer", "left_ear", "right_ear", "mouth_left", "mouth_right", "left_shoulder",
        "right_shoulder", "left_elbow", "right_elbow", "left_wrist", "right_wrist", "left_pinky",
        "right_pinky", "left_index", "right_index", "left_thumb", "right_thumb", "left_hip",
        "right_hip", "left_knee", "right_knee", "left_ankle", "right_ankle", "left_heel",
        "right_heel", "left_foot_index", "right_foot_index"
    ]

    # Indices for foot joints to exclude from detection
    foot_indices = {27, 28, 31, 32}  # left_ankle, right_ankle, left_foot_index, right_foot_index

    for i, point in enumerate(skeleton_points):
        # if i not in foot_indices and point["visibility"] > 0.5 and 
        if point["z"] < GROUND_THRESHOLD:
            ground_contacts.append(joint_names[i])

    return ground_contacts

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=8000)
