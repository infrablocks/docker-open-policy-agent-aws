FROM amazon/aws-lambda-provided:al2.2022.11.15.11

RUN yum -y update
RUN yum -y install jq

RUN mkdir /opa
WORKDIR /opa
RUN curl -L -o opa https://openpolicyagent.org/downloads/v0.46.1/opa_linux_amd64_static
RUN chmod +x opa

WORKDIR /var/runtime
COPY start.sh .
COPY bootstrap.sh .
RUN chmod +x bootstrap.sh
RUN chmod +x start.sh

# Start Handler
ENTRYPOINT ["/var/runtime/start.sh"]
