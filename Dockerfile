FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    SDL_VIDEODRIVER=dummy \
    SDL_AUDIODRIVER=dummy

RUN rm -f /etc/dpkg/dpkg.cfg.d/excludes \
    && apt-get update \
    && apt-get install -y --no-install-recommends love \
    && rm -rf /var/lib/apt/lists/* \
    && useradd --create-home --shell /usr/sbin/nologin kyma \
    && mkdir -p /data \
    && chown kyma:kyma /data

WORKDIR /app

COPY server/ ./
COPY src/ ./src/
COPY libs/ ./libs/

USER kyma

ENV PORT=6789 \
    MAX_PEERS=64 \
    SERVER_NAME="Kyma server" \
    SERVER_MOTD="" \
    DATA_DIR=/data

VOLUME ["/data"]

EXPOSE 6789/udp

CMD ["love", "/app"]
