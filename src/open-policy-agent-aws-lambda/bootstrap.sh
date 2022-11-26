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
  headers="$(mktemp)"
  curl -sS \
    -LD "$headers" \
    -X GET "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next" \
    -o /tmp/event.data

  echo "Request received. Processing..."

  request_id=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$headers" | tr -d '[:space:]' | cut -d: -f2)

  echo "Request ID is: ${request_id}."
  echo "Invocation event is: $(cat /tmp/event.data)"
  echo "Invocation headers are: $(cat $headers)"

  echo "Reading and normalising request parameters..."

  path=$(jq -r ".path" </tmp/event.data)
  method=$(jq -r ".httpMethod" </tmp/event.data)
  payload=$(jq -r  ".body" </tmp/event.data)
  rm /tmp/event.data

  length=${#path}
  first_char=${path:0:1}
  [[ $first_char == "/" ]] && path=${path:1:length-1}

  echo "Request path is: ${path}"
  echo "Request method is: ${method}"
  echo "Request payload is: ${payload}"

  echo "Passing request to OPA..."
  response=$(curl -s -X "$method" "http://127.0.0.1:8181/${path}" -d "$payload" -H "Content-Type: application/json")

  echo "OPA response is: ${response}"

  echo "Sending response to Lambda..."
  curl -s \
    -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$request_id/response" \
    -d "$response" \
    -H "Content-Type: application/json"

  echo "Request poll complete..."
done
