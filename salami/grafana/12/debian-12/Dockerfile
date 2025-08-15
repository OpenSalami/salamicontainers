# Copyright Broadcom, Inc. All Rights Reserved.
# SPDX-License-Identifier: APACHE-2.0

FROM docker.io/bitnami/minideb:bookworm

ARG DOWNLOADS_URL="dl.grafana.com/grafana/release/12.1.0/"
ARG GRAFANA_TARBALL="grafana-12.1.0.linux-amd64.tar.gz"
ARG GRAFANA_VERSION="12.1.0"
ARG TARGETARCH

LABEL org.opencontainers.image.base.name="docker.io/bitnami/minideb:bookworm" \
      org.opencontainers.image.description="Application packed by The OpenSalami project" \
      org.opencontainers.image.documentation="https://github.com/opensalami/containers/tree/main/salami/grafana/README.md" \
      org.opencontainers.image.source="https://github.com/opensalami/containers/tree/main/salami/grafana" \
      org.opencontainers.image.title="grafana" \
      org.opencontainers.image.vendor="The OpenSalami project" \
      org.opencontainers.image.version="${GRAFANA_VERSION}" 

ENV HOME="/" \
    OS_ARCH="${TARGETARCH:-amd64}" \
    OS_FLAVOUR="debian-12" \
    OS_NAME="linux" \
    SALAMI_APP_NAME="grafana"

COPY prebuildfs /
SHELL ["/bin/bash", "-o", "errexit", "-o", "nounset", "-o", "pipefail", "-c"]
# Install required system packages and dependencies
RUN install_packages ca-certificates curl tar libaudit1 libcap-ng0 libfontconfig libgcc-s1 libicu72 liblzma5 libncurses6 libpam0g libssl3 libstdc++6 libtinfo6 libxml2 procps zlib1g

# Download, extract, and install Grafana
RUN curl -SsLf "https://${DOWNLOADS_URL}${GRAFANA_TARBALL}" -O && \
    mkdir -p /opt/salami/grafana && \
    tar -xzf "${GRAFANA_TARBALL}" -C /opt/salami/grafana --strip-components=1 && \
    rm -f "${GRAFANA_TARBALL}"

RUN apt-get update && apt-get upgrade -y && \
    apt-get clean && rm -rf /var/lib/apt/lists /var/cache/apt/archives
RUN chmod g+rwX /opt/salami
RUN find / -perm /6000 -type f -exec chmod a-s {} \; || true

COPY rootfs /
RUN /opt/salami/scripts/grafana/postunpack.sh
ENV APP_VERSION="${GRAFANA_VERSION}}" \
    SALAMI_APP_NAME="grafana" \
    PATH="/opt/salami/mysql/bin:/opt/salami/common/bin:/opt/salami/grafana/bin:$PATH"

EXPOSE 3000

WORKDIR /opt/salami/grafana
USER 1001
ENTRYPOINT [ "/opt/salami/scripts/grafana/entrypoint.sh" ]
CMD [ "/opt/salami/scripts/grafana/run.sh" ]