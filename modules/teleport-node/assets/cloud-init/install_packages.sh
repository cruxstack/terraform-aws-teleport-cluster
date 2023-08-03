#!/bin/bash -xe

# --- script------------------------------------------------

yum install -y binutils
yum install -y yum-plugin-kernel-livepatch
yum kernel-livepatch enable -y
yum install -y kpatch-runtime

systemctl enable kpatch.service
amazon-linux-extras enable livepatch
yum update -y
