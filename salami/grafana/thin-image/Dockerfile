FROM alpine:3.20 AS builder

ARG TARGETARCH=amd64
ENV GRAFANA_VERSION=12.1.1

WORKDIR /tmp

# Set GRAFANA_ARCH and MUSL_LIB for the build
RUN if [ "$TARGETARCH" = "amd64" ]; then \
      export GRAFANA_ARCH=amd64 && export MUSL_LIB=ld-musl-x86_64.so.1 ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      export GRAFANA_ARCH=arm64 && export MUSL_LIB=ld-musl-aarch64.so.1 ; \
    else \
      echo "Unsupported arch: $TARGETARCH" && exit 1 ; \
    fi && \
    echo "GRAFANA_ARCH=$GRAFANA_ARCH" > /tmp/arch.env && \
    echo "MUSL_LIB=$MUSL_LIB" >> /tmp/arch.env

# Install dependencies and download/copy files
RUN set -a && . /tmp/arch.env && set +a && \
    apk add --no-cache curl tar git ca-certificates shadow util-linux su-exec && \
    curl -fsSL -o grafana.tar.gz "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-${GRAFANA_ARCH}.tar.gz" && \
    mkdir /grafana && \
    tar -xzf grafana.tar.gz -C /grafana --strip-components=1 && \
    git clone https://github.com/OpenSalami/rootfs.git /prebuildfs

RUN find /prebuildfs/prebuildfs/opt/salami/scripts -type f -name '*.sh' -exec chmod +x {} \; || true
COPY rootfs /rootfs
RUN find /rootfs/opt/salami/scripts -type f -name '*.sh' -exec chmod +x {} \; || true
RUN touch /grafana/conf/sample.ini
RUN mkdir -p /opt/salami/scripts && \
    cp -r /rootfs/opt/salami/scripts/* /opt/salami/scripts/ && \
    cp /prebuildfs/prebuildfs/opt/salami/scripts/* /opt/salami/scripts/

RUN /opt/salami/scripts/grafana/postunpack.sh

FROM ghcr.io/opensalami/salamibase-thin:latest

COPY --from=builder /grafana /grafana
COPY --from=builder /rootfs/opt/ /opt

ENV APP_VERSION=$GRAFANA_VERSION \
    SALAMI_APP_NAME="grafana" \
    PATH="/opt/salami/mysql/bin:/opt/salami/common/bin:/opt/salami/grafana/bin:$PATH"

EXPOSE 3000

ENTRYPOINT [ "/bin/sh", "/opt/salami/scripts/grafana/entrypoint.sh" ]
CMD [ "/bin/sh", "/opt/salami/scripts/grafana/run.sh" ]