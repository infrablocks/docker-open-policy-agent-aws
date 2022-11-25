#!/bin/sh

# Gracefully exit if killed
exit_script() {
    echo "Shutting down..."
    trap - SIGINT SIGTERM # clear the trap
}
trap exit_script SIGINT SIGTERM

echo "Checking some things..."
echo "Environment is:"
echo $(env)
echo "Running as:"
echo $(whoami)
echo "OPA directory looks like:"
echo $(ls -la /opt/opa)
echo $(ls -la /opt/opa/bin)

# Run OPA in sever mode and load policies
echo "Starting Open Policy Agent..."
exec /opt/opa/bin/opa run \
  --server \
  --disable-telemetry \
  --log-level debug \
  /opt/opa/ &

echo "Waiting for Open Policy Agent to be healthy..."
address="http://127.0.0.1:8181/health"
while [[ "$(curl -s -o /dev/null -w ''%{http_code}'' $address)" != "200" ]]; do
  echo "Not healthy yet. Waiting 50ms..."
  sleep 0.05
done
echo "Started Open Policy Agent"

# If running locally load Runtime Interface Emulator and handler,
# otherwise just handler
echo "Starting request handler..."
if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
    echo "Running locally - starting RIE and request handler..."
    exec /usr/local/bin/aws-lambda-rie --log-level debug /var/runtime/bootstrap.sh
else
    echo "Running on Lambda - starting request handler..."
    exec /var/runtime/bootstrap.sh
fi
