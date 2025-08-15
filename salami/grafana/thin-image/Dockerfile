FROM alpine:3.20 AS builder

ENV GRAFANA_VERSION=12.1.1
WORKDIR /tmp
RUN apk add --no-cache curl tar git && \
    curl -fsSL -o grafana.tar.gz "https://dl.grafana.com/oss/release/grafana-${GRAFANA_VERSION}.linux-amd64.tar.gz" && \
    mkdir /grafana && \
    mkdir rootfs && \
    tar -xzf grafana.tar.gz -C /grafana --strip-components=1 && \
    git clone https://github.com/OpenSalami/rootfs.git /rootfs


FROM scratch

COPY --from=builder /grafana /grafana
COPY --from=builder /etc/ssl/certs/ca-certificates.crt /etc/ssl/certs/
COPY --from=builder /bin/sh /bin/sh
COPY --from=builder /rootfs/opt/scripts /opt/scripts

EXPOSE 3000

WORKDIR /grafana

ENTRYPOINT ["/grafana/bin/grafana-server"]
CMD ["--homepath=/grafana", "--config=/grafana/conf/defaults.ini"]