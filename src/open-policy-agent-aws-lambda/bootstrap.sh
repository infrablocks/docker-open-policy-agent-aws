#!/bin/bash

set -euo pipefail

echo "Checking some things..."
echo "Environment is:"
env
echo "Running as:"
whoami
echo "OPA directory looks like:"
ls -la /opt/opa
ls -la /opt/opa/bin

echo "Starting request handling loop..."

# The handler needs to be running continuously to receive events from Lambda so
# we put it in a loop
while true; do
  echo "Starting request poll..."

  echo "Fetching next request from Lambda..."
  # Lambda will block until an event is received
  lambda_headers_file="$(mktemp)"
  lambda_event_file="$(mktemp)"
  /opt/opa/bin/curl \
    --silent \
    --show-error \
    --location \
    --dump-header "$lambda_headers_file" \
    --request GET \
    --output "$lambda_event_file" \
    "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/next"

  echo "Request received. Processing..."

  request_id=$(grep -Fi Lambda-Runtime-Aws-Request-Id "$lambda_headers_file" | tr -d '[:space:]' | cut -d: -f2)

  echo "Request ID is: ${request_id}."
  echo "Invocation event is: $(cat "$lambda_event_file")"
  echo "Invocation headers are: $(cat "$lambda_headers_file")"

  echo "Reading and normalising request parameters..."

  path=$(jq -r ".path" < "$lambda_event_file")
  method=$(jq -r ".httpMethod" < "$lambda_event_file")
  payload=$(jq -r  ".body" < "$lambda_event_file")

  length=${#path}
  first_char=${path:0:1}
  [[ $first_char == "/" ]] && path=${path:1:length-1}

  echo "Request path is: ${path}"
  echo "Request method is: ${method}"
  printf "Request payload is: %s\n" "${payload}"

  echo "Passing request to OPA..."
  response_data_file="$(mktemp)"
  response_body_file="$(mktemp)"

  /opt/opa/bin/curl \
    --silent \
    --request "$method" \
    --data "$payload" \
    --header "Content-Type: application/json" \
    --output "$response_body_file" \
    --write-out '{"headers": %{header_json}, "others": %{json}}' \
    "http://127.0.0.1:8181/${path}" > "$response_data_file"

  body=$(jq -c -r "." < "$response_body_file" | jq -R -s ".")
  statusCode=$(jq -r ".others.response_code" < "$response_data_file")
  headers=$(jq -c -r ".headers" < "$response_data_file")

  printf "Response status code is: %s\n" "${statusCode}"
  printf "Response headers are: %s\n" "${headers}"
  printf "Response body is: %s\n" "${body}"

  response="{\"isBase64Encoded\": false, \"statusCode\": $statusCode, \"body\": $body, \"multiValueHeaders\": $headers}"

  printf "OPA response is: %s\n" "${response}"

  echo "Sending response to Lambda..."
  /opt/opa/bin/curl \
    --silent \
    --request "POST" \
    --data "$response" \
    --header "Content-Type: application/json" \
    "http://${AWS_LAMBDA_RUNTIME_API}/2018-06-01/runtime/invocation/$request_id/response"

  echo "Request poll complete..."
done
