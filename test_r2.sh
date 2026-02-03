#!/bin/bash
set -e

APP_NAME="vutils-backend"
CONTAINER_NAME="vutils-test"
PORT=5002

# Environment variables should be passed to this script or set in the environment
# For this test, you must provide them when running the script if you want a real test
# e.g. ./test_r2.sh

# Load environment variables from .env if present
if [ -f .env ]; then
  export $(cat .env | xargs)
fi

echo "Stopping any existing container..."
docker stop $CONTAINER_NAME 2>/dev/null || true
docker rm $CONTAINER_NAME 2>/dev/null || true

echo "Running container..."
# Passing env vars from host to container
docker run -d -p $PORT:5000 \
  -e R2_ENDPOINT_URL="$R2_ENDPOINT_URL" \
  -e R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e INPUT_BUCKET="$INPUT_BUCKET" \
  -e OUTPUT_BUCKET="$OUTPUT_BUCKET" \
  --name $CONTAINER_NAME $APP_NAME

echo "Waiting for service to start..."
sleep 3

echo "Testing R2 conversion trigger..."
# Note: Input key must exist in the INPUT_BUCKET
INPUT_KEY="WhatCarCanYouGetForAGrand_copy.mp4" 

# Payload
JSON_DATA=$(cat <<EOF
{
  "input_key": "$INPUT_KEY",
  "format": "avi"
}
EOF
)

curl -X POST -H "Content-Type: application/json" \
  -d "$JSON_DATA" \
  http://localhost:$PORT/convert

echo -e "\nRequest sent."
echo "Check container logs for progress:"
echo "docker logs $CONTAINER_NAME"
