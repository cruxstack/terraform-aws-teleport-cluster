#!/bin/bash -xe
# shellcheck disable=SC2154,SC2686

# --- terraform inputs -------------------------------------

SRC_BUCKET_NAME=${src_bucket_name}
SRC_BUCKET_PATH=${src_bucket_path}
DST_PATH=${dst_path}

# --- script------------------------------------------------

aws s3 cp "s3://$SRC_BUCKET_NAME/$SRC_BUCKET_PATH/" "$DST_PATH/" --recursive
chmod 755 "$DST_PATH"/teleport*
