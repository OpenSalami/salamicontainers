FROM alpine:3.20 AS builder

ARG TARGETARCH
ENV GRAFANA_VERSION=12.1.1

WORKDIR /tmp

RUN if [ "$TARGETARCH" = "amd64" ]; then \
      export GRAFANA_ARCH=linux-amd64 ; \
    elif [ "$TARGETARCH" = "arm64" ]; then \
      export GRAFANA_ARCH=linux-arm64 ; \
    else \
      echo "Unsupported arch: $TARGETARCH" && exit 1 ; \
    fi && \
    echo "GRAFANA_ARCH=$GRAFANA_ARCH" > /tmp/arch.env

RUN echo "TARGETARCH=$TARGETARCH" && uname -m
# Install dependencies and download/copy files
RUN set -a && . /tmp/arch.env && set +a && \
    apk add --no-cache curl tar git ca-certificates shadow util-linux su-exec && \
    curl -fsSL -o grafana.tar.gz "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.${GRAFANA_ARCH}.tar.gz" && \
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