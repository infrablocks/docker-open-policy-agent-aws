#!/bin/sh

# set -euo pipefail

echo "Checking some things..."
echo "Environment is:"
echo $(env)
echo "Running as:"
echo $(whoami)
echo "OPA directory looks like:"
echo $(ls -la /opt/opa)
echo $(ls -la /opt/opa/bin)

echo "Starting request handling loop..."

# The handler needs to be running continuously to receive events from Lambda so
# we put it in a loop
while true; do
  echo "Starting request poll..."

  echo "Fetching next request from Lambda..."
  # Lambda will block until an event is received
  HEADERS="$(mktemp)"
  curl -sS \
    -LD "$HEADERS" \
    -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next" \
    -o /tmp/event.data

  echo "Request received. Processing..."

  REQUEST_ID=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$HEADERS" | tr -d '[:space:]' | cut -d: -f2)

  echo "Request ID is: ${REQUEST_ID}."
  echo "Invocation event is: $(cat /tmp/event.data)"
  echo "Invocation headers are: $(cat $HEADERS)"

  echo "Reading and normalising request parameters..."

  OPA_PATH=$(jq -r ".x_opa_path" </tmp/event.data)
  OPA_METHOD=$(jq -r ".x_opa_method" </tmp/event.data)
  OPA_PAYLOAD=$(jq -r  ".x_opa_payload" </tmp/event.data)
  rm /tmp/event.data

  length=${#OPA_PATH}
  first_char=${OPA_PATH:0:1}
  [[ $first_char == "/" ]] && OPA_PATH=${OPA_PATH:1:length-1}

  echo "Request path is: ${OPA_PATH}"
  echo "Request method is: ${OPA_METHOD}"
  echo "Request payload is: ${OPA_PAYLOAD}"

  echo "Passing request to OPA..."
  RESPONSE=$(curl -s -X "$OPA_METHOD" "http://localhost:8181/${OPA_PATH}" -d "$OPA_PAYLOAD" -H "Content-Type: application/json")

  echo "OPA response is: ${RESPONSE}"

  echo "Sending response to Lambda..."
  curl -s \
    -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$REQUEST_ID/response" \
    -d "$RESPONSE" \
    -H "Content-Type: application/json"

  echo "Request poll complete..."
done
