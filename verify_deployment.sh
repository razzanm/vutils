#!/bin/bash
set -e

SERVICE_URL="https://vutils-backend-706554023404.us-central1.run.app"
INPUT_KEY="more_than_200mb_file.mp4"

echo "Testing Live Service at $SERVICE_URL..."

# Payload
JSON_DATA=$(cat <<EOF
{
  "input_key": "$INPUT_KEY",
  "format": "avi",
  "output_key": "200_test_output.avi"
}
EOF
)

curl -v -X POST -H "Content-Type: application/json" \
  -d "$JSON_DATA" \
  $SERVICE_URL/convert

echo -e "\nRequest sent."
