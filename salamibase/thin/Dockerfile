FROM alpine:3.22 AS builder

ARG TARGETARCH=amd64

WORKDIR /tmp

RUN if [ "$TARGETARCH" = "amd64" ]; then \
      export MUSL_LIB=ld-musl-x86_64.so.1 ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
        export MUSL_LIB=ld-musl-aarch64.so.1 ; \
    else \
      echo "Unsupported arch: $TARGETARCH" && exit 1 ; \
    fi 

RUN apk add --no-cache curl tar git ca-certificates shadow util-linux su-exec && \
    git clone https://github.com/OpenSalami/rootfs.git /prebuildfs


RUN find /prebuildfs/prebuildfs/opt/salami/scripts -type f -name '*.sh' -exec chmod +x {} \; || true
RUN mkdir -p /opt/salami/scripts && cp /prebuildfs/prebuildfs/opt/salami/scripts/* /opt/salami/scripts/


FROM scratch

COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/sh /bin/sh
COPY --from=builder /lib/${MUSL_LIB} /lib/
COPY --from=builder /prebuildfs/prebuildfs/opt/salami/scripts/ /opt/salami/scripts/
COPY --from=builder /bin/busybox /bin/busybox
RUN ["/bin/busybox", "--install", "-s", "/bin"]
COPY --from=builder /sbin/su-exec /sbin/su-exec

ENTRYPOINT ["/bin/sh"]