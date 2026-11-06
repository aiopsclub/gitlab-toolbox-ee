# gitlab-toolbox image with an in-place patch to s3cmd's upload MD5/ETag check.
#
# Why: s3cmd 2.3.0 (bundled in the toolbox image) compares the S3 ETag
# case-sensitively against the local lowercase MD5 hexdigest in send_file().
# Object stores that answer with UPPERCASE hex etags fail every upload with
# "MD5 Sums don't match!" until s3cmd gives up, aborting gitlab-backup.
# Lowercasing the received etag makes the comparison case-insensitive --
# behaviorally equal to s3cmd 1.x's digest comparison, without its
# Python-3 hex-decode crash and its uncaught binascii.Error on multipart
# etags.
#
# The file is patched in place (no whole-file overwrite) so future base
# image bumps keep every upstream s3cmd fix. Guards make a silent no-op
# impossible: grep fails the build if upstream ever rewrites the line,
# py_compile fails it if the sed corrupts the file.
ARG BASE_IMAGE=registry.jihulab.com/gitlab-cn/build/cng-images/gitlab-toolbox-jh:v16.1.8
FROM ${BASE_IMAGE}

USER root
RUN S3DIR=$(python3 -c 'import S3; print(S3.__path__[0])') \
    && sed -i 's|(md5_from_s3 != md5_hash\.hexdigest())|(md5_from_s3.lower() != md5_hash.hexdigest())|' "$S3DIR/S3.py" \
    && grep -q 'md5_from_s3\.lower()' "$S3DIR/S3.py" \
    && python3 -m py_compile "$S3DIR/S3.py" \
    && rm -rf "$S3DIR/__pycache__"
USER git:git
