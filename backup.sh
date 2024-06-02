#!/usr/bin/env bash

set -euo pipefail

s3fs_mountpoint_base='/mnt'
read -r -a source_buckets <<< "${SOURCE_BUCKETS?no source buckets were configured!}"

if [ -n "${SOURCE_S3_ACCESS_KEY:-}" ]
then
    s3fs_access_key="$SOURCE_S3_ACCESS_KEY"
elif [ -n "${SOURCE_S3_ACCESS_KEY_FILE:-}" ] && [ -r "$SOURCE_S3_ACCESS_KEY_FILE" ]
then
    s3fs_access_key="$(< "$SOURCE_S3_ACCESS_KEY_FILE")"
else
    echo "No s3 access key given for s3fs!"
    exit 1
fi

if [ -n "${SOURCE_S3_SECRET_KEY:-}" ]
then
    s3fs_secret_key="$SOURCE_S3_SECRET_KEY"
elif [ -n "${SOURCE_S3_SECRET_KEY_FILE:-}" ] && [ -r "$SOURCE_S3_SECRET_KEY_FILE" ]
then
    s3fs_secret_key="$(< "$SOURCE_S3_SECRET_KEY_FILE")"
else
    echo "No s3 secret key given for s3fs!"
    exit 1
fi

s3fs_credentials_file="$(mktemp)"
chmod 600 "$s3fs_credentials_file"
echo -n "$s3fs_access_key:$s3fs_secret_key" > "$s3fs_credentials_file"

if [ -n "${SOURCE_S3_ENDPOINT:-}" ]
then
    s3fs_url=",url=${SOURCE_S3_ENDPOINT}"
else
    s3fs_url=''
fi


s3fs_processes=()

cleanup_s3fs() {
    for pid in "${s3fs_processes[@]}"
    do
        if kill -0 "$pid"
        then
            echo "Cleanup of s3fs process $pid"
            kill -TERM "$pid"
        fi
    done
}

trap cleanup_s3fs EXIT


s3fs_mountpoints=()
for source_bucket in "${source_buckets[@]}"
do
    s3fs_mountpoint="${s3fs_mountpoint_base}/${source_bucket}"
    mkdir -p "$s3fs_mountpoint"
    mount_test_file="$(mktemp -p "$s3fs_mountpoint")"
    s3fs -f "$source_bucket" "$s3fs_mountpoint" -o "ro,nonempty,listobjectsv2,instance_name=${source_bucket},passwd_file=${s3fs_credentials_file},use_path_request_style${s3fs_url}" > "/proc/$$/fd/1" 2> "/proc/$$/fd/2" &
    s3fs_pid="$!"
    s3fs_processes+=("$s3fs_pid")

    while test -e "$mount_test_file"
    do
        if ! kill -0 "$s3fs_pid"
        then
            echo "s3fs exited unexpectedly!"
            exit 1
        fi
        echo "Waiting for the s3fs mount to appear for bucket ${source_bucket} at ${s3fs_mountpoint}..."
        sleep 1
    done
    s3fs_mountpoints+=("$s3fs_mountpoint")
done

restic_args=()

if [ -z "${RESTIC_CACHE_DIR:-}" ]
then
    restic_args+=(--no-cache)
fi

if [ -n "${RESTIC_RETRY_LOCK_TIMEOUT:-}" ]
then
    restic_args+=(--retry-lock "${RESTIC_RETRY_LOCK_TIMEOUT}")
fi

backup_args=()
if [ -n "${RESTIC_BACKUP_TAG:-}" ]
then
    backup_args+=("--tag" "$RESTIC_BACKUP_TAG")
fi

if [ -n "${RESTIC_BACKUP_HOST:-}" ]
then
    backup_args+=("--host" "$RESTIC_BACKUP_HOST")
fi

# Load the secret env vars from files for AWS/S3 for restic

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_ACCESS_KEY_ID_FILE:-}" ] && [ -r "$AWS_ACCESS_KEY_ID_FILE" ]
then
    export AWS_ACCESS_KEY_ID
    AWS_ACCESS_KEY_ID="$(< "$AWS_ACCESS_KEY_ID_FILE")"
fi

if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_FILE:-}" ] && [ -r "$AWS_SECRET_ACCESS_KEY_FILE" ]
then
    export AWS_SECRET_ACCESS_KEY
    AWS_SECRET_ACCESS_KEY="$(< "$AWS_SECRET_ACCESS_KEY_FILE")"
fi

if [ -z "${AWS_SESSION_TOKEN:-}" ] && [ -n "${AWS_SESSION_TOKEN_FILE:-}" ] && [ -r "$AWS_SESSION_TOKEN_FILE" ]
then
    export AWS_SESSION_TOKEN
    AWS_SESSION_TOKEN="$(< "$AWS_SESSION_TOKEN_FILE")"
fi

if [ "${RESTIC_INIT_REPOSITORY:-}" = "true" ]
then
    restic "${restic_args[@]}" ${RESTIC_EXTRA_ARGS:-} init || echo "Repository initialization failed, is it already initialized?"
fi


restic "${restic_args[@]}" ${RESTIC_EXTRA_ARGS:-} backup --one-file-system "${backup_args[@]}" ${RESTIC_BACKUP_EXTRA_ARGS:-} "${s3fs_mountpoints[@]}"

for s3fs_mountpoint in "${s3fs_mountpoints[@]}"
do
    umount "$s3fs_mountpoint"
done

