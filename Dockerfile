FROM ghcr.io/restic/restic:0.18.1@sha256:c1958a2a1c8614f5c317347c2aaddd9f426076f0521430b55509eba43d7516ee AS restic

FROM docker.io/library/debian:trixie-20260505@sha256:0bea168ca3987374732de970508d6dd701d36ee68781b18aadaddca04a95d392 AS s3fs-build

RUN apt-get update
RUN apt-get install -y build-essential git automake pkg-config libfuse3-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

RUN mkdir /build-s3fs \
 && git clone -b "v1.97" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

FROM docker.io/library/debian:trixie-slim@sha256:bacd8d9d762705be0fdc6f98aa280c6fb29d9e12217aedcf77125397dcee1ab5

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types libfuse3-4 tzdata ssh-client

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

COPY --from=s3fs-build --chmod=755 /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=restic --chmod=755 /usr/bin/restic /usr/local/bin/restic

