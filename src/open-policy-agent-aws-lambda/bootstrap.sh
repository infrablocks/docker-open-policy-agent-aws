#!/bin/sh

set -euo pipefail

# The handler needs to be running continuously to receive events from Lambda so
# we put it in a loop
while true; do
  HEADERS="$(mktemp)"
  # Grab an invocation event and write to temp file, this step will be blocked
  # by Lambda until an event is received
  curl -sS \
    -LD "$HEADERS" \
    -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next" \
    -o /tmp/event.data

  # Extract request ID by scraping response headers received above
  REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

  # Extract OPA variables from temp file created event and delete temp file
  OPA_PATH=$(jq -r ".x_opa_path" </tmp/event.data)
  OPA_METHOD=$(jq -r ".x_opa_method" </tmp/event.data)
  OPA_PAYLOAD=$(jq -r  ".x_opa_payload" </tmp/event.data)
  rm /tmp/event.data

  # Remove leading / in OPA path if included in request
  length=${#OPA_PATH}
  first_char=${OPA_PATH:0:1}
  [[ $first_char == "/" ]] && OPA_PATH=${OPA_PATH:1:length-1}
  echo $first_char
  echo $OPA_PATH

  # Pass Payload to OPA and Get Response
  RESPONSE=$(curl -s -X POST "http://localhost:8181/${OPA_PATH}" -d "$OPA_PAYLOAD" -H "Content-Type: application/json")

  # Send Response to Lambda
  curl -s \
    -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
    -d "$RESPONSE" \
    -H "Content-Type: application/json"
done
