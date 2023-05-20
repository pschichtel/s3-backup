#!/usr/bin/env bash

set -euo pipefail

image_name="ghcr.io/pschichtel/s3-backup:dev"

podman build --build-arg S3FS_VERSION="1.91" --build-arg RESTIC_VERSION="0.15.2" -t "$image_name" .

source test_variables.sh

podman run --rm -t --privileged \
    -e SOURCE_S3_ENDPOINT="$source_endpoint" \
    -e SOURCE_S3_ACCESS_KEY="$source_access_key" \
    -e SOURCE_S3_SECRET_KEY="$source_secret_key" \
    -e SOURCE_BUCKETS="$source_buckets" \
    -e AWS_ACCESS_KEY_ID="$target_access_key" \
    -e AWS_SECRET_ACCESS_KEY="$target_secret_key" \
    -e RESTIC_REPOSITORY="s3:${target_endpoint}/${target_bucket}/" \
    -e RESTIC_PASSWORD="$restic_repo_password" \
    -e RESTIC_INIT_REPOSITORY="true" \
    "$image_name"