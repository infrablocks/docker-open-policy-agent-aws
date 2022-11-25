#!/bin/sh

# Gracefully exit if killed
exit_script() {
    echo "Shutting down..."
    trap - SIGINT SIGTERM # clear the trap
}
trap exit_script SIGINT SIGTERM

# Run OPA in sever mode and load policies
echo "Starting Open Policy Agent..."
exec /opt/opa/bin/opa run \
  --server \
  --disable-telemetry \
  --log-level debug \
  --bundle /opt/opa/ &
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
