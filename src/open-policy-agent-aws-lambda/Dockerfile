FROM alpine:3.16.2 AS curl

ENV CURL_VERSION='7.86.0'

ENV CC='clang'

RUN apk update
RUN apk upgrade
RUN apk add \
    build-base \
    clang \
    gnupg \
    libssh2-dev \
    libssh2-static \
    nghttp2-dev \
    nghttp2-static \
    openssl-dev \
    openssl-libs-static \
    zlib-static

WORKDIR /tmp

RUN wget https://curl.haxx.se/download/curl-${CURL_VERSION}.tar.gz

RUN tar xzf curl-${CURL_VERSION}.tar.gz
WORKDIR /tmp/curl-${CURL_VERSION}/
RUN LDFLAGS="-static" PKG_CONFIG="pkg-config --static" ./configure \
    --disable-shared \
    --enable-static \
    --disable-ldap \
    --enable-ipv6  \
    --enable-unix-sockets  \
    --with-ssl \
    --with-libssh2
RUN make -j4 V=1 LDFLAGS="-static -all-static"
RUN strip src/curl

RUN mkdir -p /tmp/release/
RUN mv src/curl "/tmp/release/curl"

WORKDIR /tmp
RUN rm -rf "curl-${CURL_VERSION}/"

FROM amazon/aws-lambda-provided:al2.2022.11.15.11

# Install jq for interpreting requests and responses
RUN yum -y update
RUN yum -y install jq

# Install OPA static binary
RUN mkdir -p /opt/opa/bin
WORKDIR /opt/opa/bin
RUN curl -L -o opa https://openpolicyagent.org/downloads/v0.46.1/opa_linux_amd64_static
RUN chmod +x opa
COPY --from=curl /tmp/release/curl /opt/opa/bin/curl

# Add wrapper scripts
WORKDIR /var/runtime
COPY start.sh .
COPY bootstrap.sh .
RUN chmod +x start.sh
RUN chmod +x bootstrap.sh

WORKDIR /

# Start Handler
ENTRYPOINT ["/var/runtime/start.sh"]
