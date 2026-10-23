FROM alpine:3.22

# Upstream ships a static Go binary with each release but no image.
ARG ACU_VERSION=1.0.2

RUN apk add --no-cache ca-certificates tzdata su-exec apache2-utils \
 && cd /tmp \
 && base=https://github.com/linsomniac/apt-cacher-ultra/releases/download/${ACU_VERSION} \
 && wget -q "$base/apt-cacher-ultra-${ACU_VERSION}-linux-amd64" "$base/SHA256SUMS" \
 && grep " apt-cacher-ultra-${ACU_VERSION}-linux-amd64\$" SHA256SUMS | sha256sum -c - \
 && install -m 0755 "apt-cacher-ultra-${ACU_VERSION}-linux-amd64" /usr/local/bin/apt-cacher-ultra \
 && rm -f /tmp/* \
 && apt-cacher-ultra -version

COPY entrypoint.sh /entrypoint.sh
COPY config.toml.default /usr/share/apt-cacher-ultra/config.toml.default

ENV PUID=99 PGID=100
EXPOSE 3142 6789
VOLUME ["/config", "/cache"]
HEALTHCHECK --interval=60s --timeout=5s --start-period=30s \
  CMD nc -z 127.0.0.1 3142
ENTRYPOINT ["/entrypoint.sh"]
