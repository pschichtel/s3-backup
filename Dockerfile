FROM ghcr.io/restic/restic:0.19.0@sha256:9b0c3c7010d79826a67731ea91a8d1b7eb308d255bdb50a984dbed3e50100deb AS restic

FROM docker.io/library/debian:trixie-20260610@sha256:50d8c6e4413c3f5f5890208197bd439e60e4b0c6567326bfef8f3ede11d1645b AS s3fs-build

RUN apt-get update
RUN apt-get install -y build-essential git automake pkg-config libfuse3-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

RUN mkdir /build-s3fs \
 && git clone -b "v1.97" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

FROM docker.io/library/debian:trixie-slim@sha256:b6f94ac1729f1010ed1d01cde9e68a6a5bb19a51382883d5e3bf87fd832a5a85

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types libfuse3-4 tzdata ssh-client

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

COPY --from=s3fs-build --chmod=755 /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=restic --chmod=755 /usr/bin/restic /usr/local/bin/restic

