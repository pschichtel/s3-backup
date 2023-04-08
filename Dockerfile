FROM docker.io/library/debian:bookworm AS build

RUN apt-get update
RUN apt-get install -y build-essential
RUN apt-get install -y git automake pkg-config golang
RUN apt-get install -y libfuse-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

ARG S3FS_VERSION

RUN mkdir /build-s3fs \
 && git clone -b "v${S3FS_VERSION}" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

ARG RESTIC_VERSION

RUN mkdir /build-restic \
 && git clone -b "v${RESTIC_VERSION}" --depth 1 https://github.com/restic/restic /build-restic \
 && cd /build-restic \
 && go run build.go

FROM docker.io/library/debian:bookworm-slim

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types fuse tzdata ssh-client

COPY --from=build /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=build --chmod=755 /build-restic/restic /usr/local/bin/restic

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

