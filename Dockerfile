ARG RESTIC_VERSION

FROM ghcr.io/restic/restic:${RESTIC_VERSION} AS restic

FROM docker.io/library/debian:bookworm AS s3fs-build

ARG S3FS_VERSION

RUN apt-get update
RUN apt-get install -y build-essential git automake pkg-config libfuse-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

RUN mkdir /build-s3fs \
 && git clone -b "v${S3FS_VERSION}" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

FROM docker.io/library/debian:bookworm-slim

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types fuse tzdata ssh-client

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

COPY --from=s3fs-build --chmod=755 /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=restic --chmod=755 /usr/bin/restic /usr/local/bin/restic

