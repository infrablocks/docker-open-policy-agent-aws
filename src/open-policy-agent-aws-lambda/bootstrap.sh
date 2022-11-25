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

  opa_path=$(jq -r ".x_opa_path" </tmp/event.data)
  opa_method=$(jq -r ".x_opa_method" </tmp/event.data)
  opa_payload=$(jq -r  ".x_opa_payload" </tmp/event.data)
  rm /tmp/event.data

  length=${#opa_path}
  first_char=${opa_path:0:1}
  [[ $first_char == "/" ]] && opa_path=${opa_path:1:length-1}

  echo "Request path is: ${opa_path}"
  echo "Request method is: ${opa_method}"
  echo "Request payload is: ${opa_payload}"

  echo "Passing request to OPA..."
  response=$(curl -s -X "$opa_method" "http://127.0.0.1:8181/${opa_path}" -d "$opa_payload" -H "Content-Type: application/json")

  echo "OPA response is: ${response}"

  echo "Sending response to Lambda..."
  curl -s \
    -X POST "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$request_id/response" \
    -d "$response" \
    -H "Content-Type: application/json"

  echo "Request poll complete..."
done
