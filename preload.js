const { contextBridge } = require('electron');
const { Pose, POSE_CONNECTIONS } = require('@mediapipe/pose');
const { Camera } = require('@mediapipe/camera_utils');
const { drawConnectors, drawLandmarks } = require('@mediapipe/drawing_utils');

contextBridge.exposeInMainWorld('mediapipe', {
  Pose,
  POSE_CONNECTIONS,
  Camera,
  drawConnectors,
  drawLandmarks,
});
