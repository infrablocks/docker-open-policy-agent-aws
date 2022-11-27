#!/bin/bash

# Gracefully exit if killed
exit_script() {
    echo '{"message": "Shutting down..."}'
    trap - SIGINT SIGTERM # clear the trap
}
trap exit_script SIGINT SIGTERM

# Run OPA in sever mode and load policies
echo '{"message": "Starting Open Policy Agent..."}'
exec /opt/opa/bin/opa run \
  --server \
  --disable-telemetry \
  --log-level debug \
  /opt/opa/ &

echo '{"message": "Waiting for Open Policy Agent to be healthy..."}'
address="http://127.0.0.1:8181/health"
while [[ "$(curl -s -o /dev/null -w '%{http_code}' $address)" != "200" ]]; do
  echo '{"message": "Not healthy yet. Waiting 50ms..."}'
  sleep 0.05
done
echo '{"message": "Started Open Policy Agent"}'

# If running locally load Runtime Interface Emulator and handler,
# otherwise just handler
echo '{"message": "Starting request handler..."}'
if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
    echo '{"message": "Running locally - starting RIE and request handler..."}'
    exec /usr/local/bin/aws-lambda-rie \
      --log-level debug \
      /var/runtime/bootstrap.sh
else
    echo '{"message": "Running on Lambda - starting request handler..."}'
    exec /var/runtime/bootstrap.sh
fi
