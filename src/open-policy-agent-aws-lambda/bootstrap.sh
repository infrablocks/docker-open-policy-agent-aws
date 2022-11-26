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

  path=$(jq -r ".path" < /tmp/event.data)
  method=$(jq -r ".httpMethod" < /tmp/event.data)
  payload=$(jq -r  ".body" < /tmp/event.data)
  rm /tmp/event.data

  length=${#path}
  first_char=${path:0:1}
  [[ $first_char == "/" ]] && path=${path:1:length-1}

  echo "Request path is: ${path}"
  echo "Request method is: ${method}"
  echo "Request payload is: ${payload}"

  echo "Passing request to OPA..."
  curl \
    --silent \
    --request "$method" \
    --data "$payload" \
    --header "Content-Type: application/json" \
    --output /tmp/body.data \
    --write-out '{"headers": %{header_json}, "others": %{json}}' \
    "http://127.0.0.1:8181/${path}" > /tmp/response.data

  body=$(cat /tmp/body.data)
  statusCode=$(jq -r ".others.response_code" < /tmp/response.data)
  headers=$(jq -r ".headers" < /tmp/response.data)
  rm /tmp/body.data
  rm /tmp/response.data

  echo "Response status code is: ${statusCode}"
  echo "Response headers are: ${}"
  echo "Response body is: ${body}"

  response="{\"isBase64Encoded\": false, \"statusCode\": $statusCode, \"body\": \"$body\"}"

  echo "OPA response is: ${response}"

  echo "Sending response to Lambda..."
  curl \
    --silent \
    --request "POST" \
    --data "$response" \
    --header "Content-Type: application/json" \
    "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$request_id/response"

  echo "Request poll complete..."
done
