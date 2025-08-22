ARG TARGETARCH
FROM redis as builder

from alpine:3.22 AS builder2

COPY --from=builder /usr/local/bin/redis-server /usr/local/bin/redis-server
COPY --from=builder /usr/local/bin/redis-cli /usr/local/bin/redis-cli

COPY rootfs /opt




FROM scratch



# Copy required libraries for aarch64 (arm64)
COPY --from=builder /lib/aarch64-linux-gnu/libm.so.6 /lib/aarch64-linux-gnu/libm.so.6
COPY --from=builder /lib/aarch64-linux-gnu/libstdc++.so.6 /lib/aarch64-linux-gnu/libstdc++.so.6
COPY --from=builder /lib/aarch64-linux-gnu/libssl.so.3 /lib/aarch64-linux-gnu/libssl.so.3
COPY --from=builder /lib/aarch64-linux-gnu/libcrypto.so.3 /lib/aarch64-linux-gnu/libcrypto.so.3
COPY --from=builder /lib/aarch64-linux-gnu/libc.so.6 /lib/aarch64-linux-gnu/libc.so.6
COPY --from=builder /lib/aarch64-linux-gnu/libgcc_s.so.1 /lib/aarch64-linux-gnu/libgcc_s.so.1
COPY --from=builder /lib/ld-linux-aarch64.so.1 /lib/ld-linux-aarch64.so.1

ENTRYPOINT ["/usr/local/bin/redis-server"]