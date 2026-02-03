#!/bin/bash
set -e

APP_NAME="vutils-backend"
CONTAINER_NAME="vutils-test"
PORT=5001
TEST_VIDEO="/Users/rajan/Downloads/WhatCarCanYouGetForAGrand.mp4"
OUTPUT_VIDEO="WhatCarCanYouGetForAGrand.avi"

echo "Building Docker image..."
docker build -t $APP_NAME .

echo "Stopping any existing container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

echo "Running container..."
docker run -d -p $PORT:5000 --name $CONTAINER_NAME $APP_NAME

echo "Waiting for service to start..."
sleep 3

# Create a dummy video file if it doesn't exist
if [ ! -f "$TEST_VIDEO" ]; then
    echo "Creating dummy video file..."
    # Generate a simple test video using ffmpeg directly (assuming user has ffmpeg locally for test gen, or we could use the container)
    # If local ffmpeg is not guaranteed, we can use the container to generate it.
    docker exec $CONTAINER_NAME ffmpeg -f lavfi -i testsrc=duration=5:size=320x240:rate=1 -c:v libx264 -t 5 -y /tmp/$TEST_VIDEO
    docker cp $CONTAINER_NAME:/tmp/$TEST_VIDEO .
fi

echo "Testing conversion..."
curl -X POST -F "file=@$TEST_VIDEO" -F "format=avi" http://localhost:$PORT/convert --output $OUTPUT_VIDEO

if [ -f "$OUTPUT_VIDEO" ]; then
    echo "Conversion successful! Output saved to $OUTPUT_VIDEO"
    ls -lh $OUTPUT_VIDEO
else
    echo "Conversion failed!"
    exit 1
fi

echo "Cleaning up..."
docker stop $CONTAINER_NAME
docker rm $CONTAINER_NAME
# rm "$TEST_VIDEO" "$OUTPUT_VIDEO" # Keep for inspection for now
echo "Done."
