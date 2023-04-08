#!/usr/bin/env bash

set -euo pipefail

s3fs_mountpoint='/mnt'
s3fs_bucket="${S3FS_BUCKET?no s3 bucket for s3fs}"

if [ -n "${S3FS_ACCESS_KEY:-}" ]
then
    s3fs_access_key="$S3FS_ACCESS_KEY"
elif [ -n "${S3FS_ACCESS_KEY_FILE:-}" ] && [ -r "$S3FS_ACCESS_KEY_FILE" ]
then
    s3fs_access_key="$(< "$S3FS_ACCESS_KEY_FILE")"
else
    echo "No s3 access key given for s3fs!"
    exit 1
fi

if [ -n "${S3FS_SECRET_KEY:-}" ]
then
    s3fs_secret_key="$S3FS_SECRET_KEY"
elif [ -n "${S3FS_SECRET_KEY_FILE:-}" ] && [ -r "$S3FS_SECRET_KEY_FILE" ]
then
    s3fs_secret_key="$(< "$S3FS_SECRET_KEY_FILE")"
else
    echo "No s3 secret key given for s3fs!"
    exit 1
fi

s3fs_credentials_file="$(mktemp)"
chmod 600 "$s3fs_credentials_file"
echo -n "$s3fs_access_key:$s3fs_secret_key" > "$s3fs_credentials_file"

if [ -n "${S3FS_ENDPOINT:-}" ]
then
    s3fs_url=",url=${S3FS_ENDPOINT}"
else
    s3fs_url=''
fi

mount_test_file="$(mktemp -p "$s3fs_mountpoint")"
s3fs -f "$s3fs_bucket" "$s3fs_mountpoint" -o "ro,nonempty,passwd_file=${s3fs_credentials_file},use_path_request_style${s3fs_url}" > "/proc/$$/fd/1" 2> "/proc/$$/fd/2" &
s3fs_pid="$!"

cleanup_s3fs() {
    if kill -0 "$s3fs_pid"
    then
        echo "Cleanup of s3fs"
        kill -TERM "$s3fs_pid"
    fi
}

trap cleanup_s3fs EXIT

while test -e "$mount_test_file"
do
    if ! kill -0 "$s3fs_pid"
    then
        echo "s3fs exited unexpectedly!"
        exit 1
    fi
    echo "Waiting for the s3fs mount to appear..."
    sleep 1
done

restic_args=()

if [ -z "${RESTIC_CACHE_DIR:-}" ]
then
    restic_args+=(--no-cache)
fi

backup_args=()
if [ -n "${RESTIC_BACKUP_TAG:-}" ]
then
    backup_args+=("--tag" "$RESTIC_BACKUP_TAG")
fi

# Load the secret env vars from files for AWS/S3 for restic

if [ -z "${AWS_ACCESS_KEY_ID:-}" ] && [ -n "${AWS_ACCESS_KEY_ID_FILE:-}" ] && [ -r "$AWS_ACCESS_KEY_ID_FILE" ]
then
    export AWS_ACCESS_KEY_ID="$(< "$AWS_ACCESS_KEY_ID_FILE")"
fi

if [ -z "${AWS_SECRET_ACCESS_KEY:-}" ] && [ -n "${AWS_SECRET_ACCESS_KEY_FILE:-}" ] && [ -r "$AWS_SECRET_ACCESS_KEY_FILE" ]
then
    export AWS_SECRET_ACCESS_KEY="$(< "$AWS_SECRET_ACCESS_KEY_FILE")"
fi

if [ -z "${AWS_SESSION_TOKEN:-}" ] && [ -n "${AWS_SESSION_TOKEN_FILE:-}" ] && [ -r "$AWS_SESSION_TOKEN_FILE" ]
then
    export AWS_SESSION_TOKEN="$(< "$AWS_SESSION_TOKEN_FILE")"
fi

restic "${restic_args[@]}" backup --one-file-system "${backup_args[@]}" ${RESTIC_BACKUP_EXTRA_ARGS:-} "$s3fs_mountpoint"

umount "$s3fs_mountpoint"

