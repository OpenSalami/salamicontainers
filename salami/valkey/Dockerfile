FROM alpine:3.22 AS builder
ARG TARGETARCH
ENV APP_VERSION=8.1.3

WORKDIR /tmp
RUN apk add --no-cache curl make gcc musl-dev git file && \
    git clone --branch $APP_VERSION --depth 1 https://github.com/valkey-io/valkey.git && \
    cd valkey && \
    make install
RUN ls -la /usr/local/bin/ && file /usr/local/bin/valkey-server

FROM ghcr.io/opensalami/salamibase-thin:1.0.3


COPY --from=builder /usr/local/bin/valkey-server /usr/local/bin/valkey-server

CMD ["/usr/local/bin/valkey-server"]
