# syntax=docker/dockerfile:1.4
ARG TARGETARCH
ARG REDIS_VERSION=8.2.28

FROM --platform=$BUILDPLATFORM redis as builder

FROM alpine:3.20 AS gather-libs
ARG TARGETARCH

RUN apk add --no-cache libstdc++ openssl git

# Copy redis binaries from builder
COPY --from=builder /usr/local/bin/redis-server /opt/salami/redis/redis-server
COPY --from=builder /usr/local/bin/redis-cli /opt/salami/redis/redis-cli

RUN mkdir -p /opt/salami/scripts /opt/salami/redis/etc && \
    touch /opt/salami/redis/etc/redis.conf && \
    touch /opt/salami/redis/etc/redis-default.conf

# Copy rootfs
COPY rootfs/opt/salami/scripts /opt/salami/scripts

# Copy required libraries for each architecture to /out
RUN mkdir -p /out/amd64 /out/arm64 && \
    cp /lib/x86_64-linux-gnu/* /out/amd64/ 2>/dev/null || true && \
    cp /lib64/ld-linux-x86-64.so.2 /out/amd64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/* /out/arm64/ 2>/dev/null || true && \
    cp /lib/ld-linux-aarch64.so.1 /out/arm64/ 2>/dev/null || true

RUN git clone https://github.com/OpenSalami/rootfs.git /prebuildfs && \
    cp -r /prebuildfs/prebuildfs/opt/salami/scripts/* /opt/salami/scripts/ && \
    find /opt/salami -type f -name '*.sh' -exec chmod +x {} \; || true



FROM ghcr.io/opensalami/salamibase-thin:1.0.2

ARG TARGETARCH

COPY --from=gather-libs /opt /opt

# Only copy the correct set of libraries for the target architecture
COPY --from=gather-libs /out/${TARGETARCH}/ /lib/

ENV APP_VERSION=$REDIS_VERSION \
    SALAMI_APP_NAME="redis" \
    ALLOW_EMPTY_PASSWORD="yes"
RUN ls -la /opt/salami/redis/

RUN /opt/salami/scripts/redis/postunpack.sh

ENTRYPOINT ["/opt/salami/scripts/redis/entrypoint.sh"]
CMD ["/opt/salami/scripts/redis/run.sh"]