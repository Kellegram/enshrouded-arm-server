FROM ubuntu:26.04

ARG HANGOVER_VERSION=11.16
ARG HANGOVER_TAR=hangover_${HANGOVER_VERSION}_ubuntu2604_resolute_arm64.tar

RUN apt-get update \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ca-certificates curl unzip tini \
 && mkdir /tmp/hangover && cd /tmp/hangover \
 && curl -fLO "https://github.com/AndreRH/hangover/releases/download/hangover-${HANGOVER_VERSION}/${HANGOVER_TAR}" \
 && tar xf "${HANGOVER_TAR}" \
 && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends ./*.deb \
 && mkdir -p /opt/depotdownloader && cd /opt/depotdownloader \
 && curl -fLO https://github.com/SteamRE/DepotDownloader/releases/latest/download/DepotDownloader-linux-arm64.zip \
 && unzip DepotDownloader-linux-arm64.zip && rm DepotDownloader-linux-arm64.zip \
 && chmod +x DepotDownloader \
 && rm -rf /tmp/hangover /var/lib/apt/lists/*

COPY --chmod=755 entrypoint.sh /entrypoint.sh

ENV WINEDEBUG=-all
VOLUME /data
EXPOSE 15637/udp

STOPSIGNAL SIGINT
ENTRYPOINT ["/usr/bin/tini", "-g", "--", "/entrypoint.sh"]
