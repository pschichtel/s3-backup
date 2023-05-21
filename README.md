s3-backup
=========

This is a simple little container that bundles [s3fs](https://github.com/s3fs-fuse/s3fs-fuse) and [restic](https://github.com/restic/restic) together with a script that combines them.

S3fs is used to mount an arbitrary S3 bucket as a fuse filesystem to `/mnt`. Restic is then used to backup the containing files to an arbitrary restic repository.

All configuration is done through environment variables and file mounts.

Running the Container
---------------------

### Environment Variables

For the s3fs mount:

* `SOURCE_S3_ENDPOINT`: The S3 server endpoint, e.g. for non-AWS S3 services (optional)
* `SOURCE_BUCKETS`: The space separated list of buckets to mount
* `SOURCE_S3_ACCESS_KEY` or `SOURCE_S3_ACCESS_KEY_FILE`: The access key for authentication
* `SOURCE_S3_SECRET_KEY` or `SOURCE_S3_SECRET_KEY_FILE`: The secret key for authentication

For restic:

* Any ENV variables listed here: https://restic.readthedocs.io/en/latest/040_backup.html#environment-variables
* `RESTIC_CACHE_DIR`: The cache dir, which should be on a volume/emptydir for optional performance. (optional, not specifying it disables caching)
* `RESTIC_BACKUP_TAG`: The value for the `--tag` option of the restic backup command
* `RESTIC_EXTRA_ARGS`: Extra arguments that are passed to any invocation of restic
* `RESTIC_BACKUP_EXTRA_ARGS`: Extra arguments that are passed to the invocation of the restic backup command
* `RESTIC_INIT_REPOSITORY`: The script will attempt to initialized the restic repository, if this variable is set to `true`. Initialization failures will be ignored under the assumption that the usual reason would be, that the repo is already initialized. If that is not the reason, then the following backup command will fail anyway.

### Privileges

Since the container uses a fuse filesystem, it must either be executed with `--privileged` or with the `/dev/fuse` device and the `SYS_ADMIN` capability.

### Example

```bash
podman run --rm -it --device /dev/fuse --cap-add SYS_ADMIN -e SOURCE_BUCKETS=some-bucket -e SOURCE_S3_ACCESS_KEY=some-access-key -e SOURCE_S3_SECRET_KEY=some-secret-key ghcr.io/pschichtel/s3-backup:main
```

