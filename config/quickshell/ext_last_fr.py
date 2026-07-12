##sudo pacman -S python-opencv

import cv2
import sys
import os


video_path = sys.argv[1] if len(sys.argv) > 1 else 'input_video.mp4'

def open_video_capture(video_source):
    # Open the video source using OpenCV
    cap = cv2.VideoCapture(video_source)
    # ... (error handling)
    return cap

def get_last_frame(cap):
    # Iterate through frames and get the last one
    last_frame = None
    while True:
        ret, tmp_frame = cap.read()
        if not ret:
            break
        last_frame = tmp_frame
    return last_frame

def extract_last_frame_from_path(video_path):
    cap = open_video_capture(video_path)
    last_frame = get_last_frame(cap)
    output_path = os.path.join(os.path.expanduser('~'), '.config/quickshell/videos/wave_last_frame.png')
    cv2.imwrite(output_path, last_frame)  # Save the last frame as an image
    print(video_path)

extract_last_frame_from_path(video_path)
