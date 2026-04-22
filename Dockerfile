FROM ghcr.io/restic/restic:0.18.1@sha256:c1958a2a1c8614f5c317347c2aaddd9f426076f0521430b55509eba43d7516ee AS restic

FROM docker.io/library/debian:trixie-20260421@sha256:35b8ff74ead4880f22090b617372daff0ccae742eb5674455d542bef71ef1999 AS s3fs-build

RUN apt-get update
RUN apt-get install -y build-essential git automake pkg-config libfuse3-dev libssl-dev libxml2-dev libcurl4-openssl-dev openssl media-types

RUN mkdir /build-s3fs \
 && git clone -b "v1.97" --depth 1 https://github.com/s3fs-fuse/s3fs-fuse /build-s3fs \
 && cd /build-s3fs \
 && ./autogen.sh \
 && ./configure \
 && make

FROM docker.io/library/debian:trixie-slim@sha256:cedb1ef40439206b673ee8b33a46a03a0c9fa90bf3732f54704f99cb061d2c5a

RUN apt-get update
RUN apt-get install -y libcurl4 libxml2 openssl media-types libfuse3-4 tzdata ssh-client

COPY backup.sh /backup.sh

CMD [ "/backup.sh" ]

COPY --from=s3fs-build --chmod=755 /build-s3fs/src/s3fs /usr/local/bin/s3fs
COPY --from=restic --chmod=755 /usr/bin/restic /usr/local/bin/restic

