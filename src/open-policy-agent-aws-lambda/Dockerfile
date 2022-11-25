FROM amazon/aws-lambda-provided:al2.2022.11.15.11

RUN yum -y update
RUN yum -y install jq procps netstat

RUN mkdir -p /opt/opa/bin
WORKDIR /opt/opa/bin
RUN curl -L -o opa https://openpolicyagent.org/downloads/v0.46.1/opa_linux_amd64_static
RUN chmod +x opa

WORKDIR /var/runtime
COPY start.sh .
COPY bootstrap.sh .
RUN chmod +x bootstrap.sh
RUN chmod +x start.sh

WORKDIR /

# Start Handler
ENTRYPOINT ["/var/runtime/start.sh"]
