#!/bin/bash

set -euo pipefail

echo '{"message": "Starting request handling loop..."}'

# The handler needs to be running continuously to receive events from Lambda so
# we put it in a loop
while true; do
  echo '{"message": "Starting request poll..."}'

  echo '{"message": "Fetching next request from Lambda..."}'
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

  request_id=$(grep \
    -Fi Lambda-Runtime-Aws-Request-Id "$lambda_headers_file" | \
    tr -d '[:space:]' | \
    cut -d: -f2)

  echo "{\"message\": \"Request received. Processing...\","\
       "\"requestId\": \"${request_id}\","\
       "\"invocationEvent\": $(jq -c -r "." < "$lambda_event_file")}"

  path=$(jq -r ".path" < "$lambda_event_file")
  method=$(jq -r ".httpMethod" < "$lambda_event_file")
  request_body=$(jq -r  ".body" < "$lambda_event_file")

  echo "{\"message\": \"Parsed request parameters.\","\
       "\"requestId\": \"${request_id}\", \"path\": \"${path}\","\
       "\"method\": \"${method}\", \"body\": ${request_body}}"

  echo "{\"message\": \"Passing request to OPA...\","\
       "\"requestId\": \"${request_id}\"}"
  response_data_file="$(mktemp)"
  response_body_file="$(mktemp)"

  /opt/opa/bin/curl \
    --silent \
    --request "$method" \
    --data "$request_body" \
    --header "Content-Type: application/json" \
    --output "$response_body_file" \
    --write-out '{"headers": %{header_json}, "others": %{json}}' \
    "http://127.0.0.1:8181${path}" > "$response_data_file"

  status_code=$(jq -r ".others.response_code" < "$response_data_file")
  headers=$(jq -c -r ".headers" < "$response_data_file")
  if escaped_json=$(jq -c -r "." < "$response_body_file" 2>/dev/null | \
                    jq -R -s "."); then
    response_body=$escaped_json
  else
    response_body="\"$(cat "$response_body_file")\""
  fi

  echo "{\"message\": \"Received response from OPA.\","\
       "\"requestId\": \"${request_id}\","\
       "\"statusCode\": \"${status_code}\","\
       "\"headers\": ${headers},"\
       "\"body\": ${response_body}}"

  response="{"
  response+="\"isBase64Encoded\": false, "
  response+="\"statusCode\": $status_code, "
  response+="\"body\": $response_body, "
  response+="\"multiValueHeaders\": $headers"
  response+="}"

  echo "{\"message\": \"Sending response to Lambda.\","\
       "\"requestId\": \"${request_id}\","\
       "\"response\": ${response}}"
  invocation_response_path="/2018-06-01/runtime/invocation/$request_id/response"
  /opt/opa/bin/curl \
    --silent \
    --request "POST" \
    --data "$response" \
    --header "Content-Type: application/json" \
    "http://${AWS_LAMBDA_RUNTIME_API}${invocation_response_path}"

  echo "{\"message\": \"Request poll complete...\","\
       "\"requestId\": \"${request_id}\"}"
done
