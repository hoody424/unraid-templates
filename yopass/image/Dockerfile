# Yopass server and web UI plus Memcached in one container, so a single Unraid
# template is enough. Secrets stay in RAM only.
# The CI workflow passes the newest Yopass release as YOPASS_VERSION.
ARG YOPASS_VERSION=15.0.0

# Official server binary of that release.
FROM jhaals/yopass:${YOPASS_VERSION} AS server

# Web UI of the same release, built with relative URLs so it also works under
# a path such as https://example.com/yopass/, plus an HTTPS notice (see
# patch-ui.mjs).
FROM node:22-bookworm AS website
ARG YOPASS_VERSION
RUN git clone --depth 1 --branch "$YOPASS_VERSION" https://github.com/jhaals/yopass.git /src
WORKDIR /src/website
COPY patch-ui.mjs /patch-ui.mjs
RUN node /patch-ui.mjs \
 && yarn install --frozen-lockfile --network-timeout 600000 \
 && YOPASS_BACKEND_URL=. yarn build --base=./

# The yopass-server binary is linked against glibc, so no Alpine here.
FROM debian:trixie-slim
ARG YOPASS_VERSION

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates memcached tini \
 && rm -rf /var/lib/apt/lists/*

COPY --from=server /yopass-server /usr/local/bin/yopass-server
COPY --from=website /src/website/dist /public
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod 755 /usr/local/bin/entrypoint.sh

ENV ASSET_PATH=/public \
    MEMCACHED=127.0.0.1:11211 \
    MEMCACHED_MEMORY=64

LABEL org.opencontainers.image.title="yopass" \
      org.opencontainers.image.description="Yopass (share secrets with one-time links) with a built-in Memcached, for Unraid" \
      org.opencontainers.image.version="${YOPASS_VERSION}" \
      org.opencontainers.image.source="https://github.com/hoody424/unraid-templates" \
      org.opencontainers.image.licenses="Apache-2.0"

USER 65534:65534
EXPOSE 1337
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s CMD ["yopass-server", "--health-check"]
ENTRYPOINT ["tini", "--", "entrypoint.sh"]
