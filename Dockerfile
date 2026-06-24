FROM ghcr.io/restic/restic:0.19.0@sha256:9b0c3c7010d79826a67731ea91a8d1b7eb308d255bdb50a984dbed3e50100deb AS restic

FROM docker.io/library/debian:trixie-20260623@sha256:e95d0a959e322983d2c7a9e970a9727bd0dec842bde2e2052568715e2357a508 AS s3fs-build

RUN apt-get update
RUN apt-get install -y build-essential git automake pkg-config libfuse3-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

RUN mkdir /build-s3fs \
 && git clone -b "v1.97" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

FROM docker.io/library/debian:trixie-slim@sha256:f3da28155e2e26086464eba22cd235b22200b7143e8f3e1811bf359e3114bf96

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types libfuse3-4 tzdata ssh-client

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

COPY --from=s3fs-build --chmod=755 /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=restic --chmod=755 /usr/bin/restic /usr/local/bin/restic

