FROM alpine:3.22 AS builder
ARG TARGETARCH
ENV APP_VERSION=8.1.3

WORKDIR /tmp

# Install build dependencies
RUN apk add --no-cache build-base linux-headers openssl-dev tcl git file

# Clone Valkey source and checkout the desired version
RUN git clone --branch $APP_VERSION --depth 1 https://github.com/valkey-io/valkey.git

WORKDIR /tmp/valkey

# Build Valkey (musl will be used by default on Alpine)
RUN make -j2

# Optionally run tests (uncomment if you want)
#RUN make test

# Copy binaries to /tmp/bin
RUN mkdir -p /tmp/bin && cp src/valkey-server src/valkey-cli /tmp/bin/
# Verify the binaries
RUN file /tmp/bin/valkey-server /tmp/bin/valkey-cli

FROM ghcr.io/opensalami/salamibase-thin:1.0.3

ENV APP_VERSION=$APP_VERSION \
    SALAMI_APP_NAME="valkey" \
    PATH="/opt/salami/mysql/bin:/opt/salami/common/bin:/opt/salami/valkey/bin:$PATH"

COPY --from=builder /tmp/bin/* /usr/local/bin/

CMD ["/usr/local/bin/valkey-server"]