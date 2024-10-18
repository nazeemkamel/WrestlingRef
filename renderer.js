const videoElement = document.getElementById('video');
const startButton = document.getElementById('startButton');
const quitButton = document.getElementById('quitButton');
const backButton = document.getElementById('backButton');
const menu = document.getElementById('menu');
const videoContainer = document.getElementById('videoContainer');

const {
  Pose,
  POSE_CONNECTIONS,
  Camera,
  drawConnectors,
  drawLandmarks,
} = window.mediapipe;

startButton.addEventListener('click', () => {
  menu.style.display = 'none';
  videoContainer.style.display = 'flex';
  startLimbTracking();
});

backButton.addEventListener('click', () => {
  stopLimbTracking();
  videoContainer.style.display = 'none';
  menu.style.display = 'flex';
});

quitButton.addEventListener('click', () => {
  window.close();
});

let camera = null;
let pose = null;

function startLimbTracking() {
  pose = new Pose({
    locateFile: (file) => {
      return `https://cdn.jsdelivr.net/npm/@mediapipe/pose/${file}`;
    },
  });

  pose.setOptions({
    modelComplexity: 1,
    smoothLandmarks: true,
    minDetectionConfidence: 0.5,
    minTrackingConfidence: 0.5,
    maxNumPoses: 2,  // Set max number of people to track
  });

  pose.onResults(onResults);

  camera = new Camera(videoElement, {
    onFrame: async () => {
      await pose.send({ image: videoElement });
    },
    width: 640,
    height: 480,
  });
  camera.start();
}

function stopLimbTracking() {
  if (camera) {
    camera.stop();
    camera = null;
  }
  if (pose) {
    pose.close();
    pose = null;
  }
  const canvasElement = document.getElementById('output_canvas');
  if (canvasElement) {
    const canvasCtx = canvasElement.getContext('2d');
    canvasCtx.clearRect(0, 0, canvasElement.width, canvasElement.height);
  }
}

function onResults(results) {
  const canvasElement = document.getElementById('output_canvas');
  const canvasCtx = canvasElement.getContext('2d');
  canvasCtx.save();
  canvasCtx.clearRect(0, 0, canvasCtx.canvas.width, canvasCtx.canvas.height);
  canvasCtx.drawImage(
    results.image, 0, 0, canvasCtx.canvas.width, canvasCtx.canvas.height
  );

  // Check if there are multiple pose landmarks
  if (results.poseLandmarks && results.poseLandmarks.length > 0) {
    results.poseLandmarks.forEach((poseLandmarks) => {
      // Draw connectors and landmarks for each detected person
      drawConnectors(canvasCtx, poseLandmarks, POSE_CONNECTIONS,
        { color: '#00FF00', lineWidth: 4 });
      drawLandmarks(canvasCtx, poseLandmarks,
        { color: '#FF0000', lineWidth: 2 });
    });
  }
  canvasCtx.restore();
}
