#!/bin/sh

# Gracefully exit if killed
exit_script() {
    echo "Shutting down..."
    trap - SIGINT SIGTERM # clear the trap
}
trap exit_script SIGINT SIGTERM

# Run OPA in sever mode and load bundle
echo "Starting Open Policy Agent"
exec /opa/opa run -s /opa/ &

# If running locally load Runtime Interface Emulator and handler,
# otherwise just handler
if [ -z "${AWS_LAMBDA_RUNTIME_API}" ]; then
    echo "Running Locally - Starting RIE and Handler"
    exec /usr/local/bin/aws-lambda-rie /var/runtime/bootstrap.sh
else
    echo "Running on Lambda - Starting Handler..."
    exec /var/runtime/bootstrap.sh
fi