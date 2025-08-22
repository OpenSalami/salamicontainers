ARG TARGETARCH
FROM redis as builder

FROM alpine:3.22 AS gather-libs

# Install required libraries for both amd64 and arm64
RUN apk add --no-cache libstdc++ openssl git

# Copy redis binaries from builder
COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli
RUN mkdir -p /opt/salami/scripts

# Copy rootfs
COPY rootfs/opt/salami/scripts /opt/salami/scripts 

# Copy required libraries for each architecture to /out
RUN mkdir -p /out/amd64 /out/arm64 && \
    cp /lib/x86_64-linux-gnu/libm.so.6 /out/amd64/ 2>/dev/null || true && \
    cp /lib/x86_64-linux-gnu/libstdc++.so.6 /out/amd64/ 2>/dev/null || true && \
    cp /lib/x86_64-linux-gnu/libssl.so.3 /out/amd64/ 2>/dev/null || true && \
    cp /lib/x86_64-linux-gnu/libcrypto.so.3 /out/amd64/ 2>/dev/null || true && \
    cp /lib/x86_64-linux-gnu/libc.so.6 /out/amd64/ 2>/dev/null || true && \
    cp /lib/x86_64-linux-gnu/libgcc_s.so.1 /out/amd64/ 2>/dev/null || true && \
    cp /lib64/ld-linux-x86-64.so.2 /out/amd64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libm.so.6 /out/arm64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libstdc++.so.6 /out/arm64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libssl.so.3 /out/arm64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libcrypto.so.3 /out/arm64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libc.so.6 /out/arm64/ 2>/dev/null || true && \
    cp /lib/aarch64-linux-gnu/libgcc_s.so.1 /out/arm64/ 2>/dev/null || true && \
    cp /lib/ld-linux-aarch64.so.1 /out/arm64/ 2>/dev/null || true

RUN git clone https://github.com/OpenSalami/rootfs.git /prebuildfs && \
    cp -r /prebuildfs/prebuildfs/opt/salami/scripts/* /opt/salami/scripts/ && \
    find /opt/salami -type f -name '*.sh' -exec chmod +x {} \; || true && \
    ls -la /opt/salami/scripts

RUN /opt/salami/scripts/redis/postunpack.sh

FROM ghcr.io/opensalami/salamibase-thin:1.0.1

ARG TARGETARCH

COPY --from=gather-libs /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=gather-libs /usr/local/bin/redis-cli /usr/local/bin/redis-cli
COPY --from=gather-libs /opt /opt

# Copy the correct set of libraries for the target architecture
COPY --from=gather-libs /out/amd64/ /lib/x86_64-linux-gnu/
COPY --from=gather-libs /out/amd64/ /lib64/
COPY --from=gather-libs /out/arm64/ /lib/aarch64-linux-gnu/
COPY --from=gather-libs /out/arm64/ /lib/

ENTRYPOINT ["/usr/local/bin/redis-server"]