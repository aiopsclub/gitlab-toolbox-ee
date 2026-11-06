# gitlab-toolbox-ee

Hardened [GitLab toolbox](https://gitlab.com/gitlab-org/build/CNG/-/tree/master/gitlab-toolbox)
container image for GitLab backup jobs (`gitlab-backup` uploads to object
storage via the bundled s3cmd).

Default base image: `registry.jihulab.com/gitlab-cn/build/cng-images/gitlab-toolbox-jh:v16.1.8`
(JiHu / 极狐 GitLab). Override at build time with `--build-arg BASE_IMAGE=...`,
e.g. the official EE image `registry.gitlab.com/gitlab-org/build/cng/gitlab-toolbox-ee:v16.1.8`.

## What it patches

s3cmd 2.3.0 (bundled in the toolbox image) verifies uploads by comparing the
ETag returned by the object store with the locally computed MD5 hexdigest,
**case-sensitively** (`S3/S3.py`, `send_file()`):

```python
if ('-' not in md5_from_s3) and (md5_from_s3 != md5_hash.hexdigest()) and ...
```

Object stores that return UPPERCASE hex etags make every upload fail with
`MD5 Sums don't match!`, aborting `gitlab-backup`. The image build patches
that single line in place to compare `md5_from_s3.lower()` — case-insensitive,
still skipping multipart (`-`) ETags and KMS-encrypted objects.

## Why patch in place instead of copying a full S3.py

- Future base-image bumps keep all upstream s3cmd fixes; only this one line
  changes semantics.
- A silent no-op is impossible: `grep` fails the build if upstream ever
  rewrites the target line, and `py_compile` fails it if the patch corrupts
  the file.
- The `S3` package path is resolved at build time via `S3.__path__[0]`, so a
  python version bump in the base image needs no Dockerfile edit.
- The patch runs as `root` (site-packages is root-owned); the image default
  user `git:git` is restored afterwards.

## Upgrade procedure

1. Bump `BASE_IMAGE` in the `Dockerfile`.
2. Build. If the bundled s3cmd changed the target line, the build fails at
   the `grep` guard — re-evaluate the patch against the new s3cmd source.
3. Tag `v*` to publish a release image (or merge to `main` for `canary`).

Images are published to `ghcr.io/aiopsclub/gitlab-toolbox-ee` on pushes to
`main` (`canary` tag) and `v*` tags (release) via GitHub Actions.
