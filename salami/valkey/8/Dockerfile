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
RUN make -j1 MALLOC=libc

# Optionally run tests (uncomment if you want)
#RUN make test

# Copy binaries to /tmp/bin
RUN mkdir -p /tmp/bin && cp src/valkey-server src/valkey-cli /tmp/bin/ && mkdir -p /tmp/bin/etc && \ 
    touch /tmp/bin/etc/valkey-default.conf
# Verify the binaries
RUN file /tmp/bin/valkey-server /tmp/bin/valkey-cli

FROM ghcr.io/opensalami/salamibase-thin:1.0.4

ENV APP_VERSION=$APP_VERSION \
    SALAMI_APP_NAME="valkey" \
    PATH="/opt/salami/mysql/bin:/opt/salami/common/bin:/opt/salami/valkey/bin:$PATH"

COPY --from=builder /tmp/bin/* /opt/salami/valkey/
COPY rootfs/opt/salami/scripts /opt/salami/scripts
RUN mkdir -p /salami /opt/salami/valkey/etc && \
    touch /opt/salami/valkey/etc/valkey-default.conf

RUN ["/bin/sh", "-c", "exec /opt/salami/scripts/valkey/postunpack.sh"]

EXPOSE 6379

#ENTRYPOINT [ "/opt/salami/scripts/valkey/entrypoint.sh" ]
CMD [ "/opt/salami/scripts/valkey/run.sh" ]