#!/bin/bash -xe

# --- script------------------------------------------------

yum install -y binutils
yum install -y kpatch-dnf
yum kernel-livepatch -y auto
yum install -y kpatch-runtime

systemctl enable kpatch.service
systemctl start kpatch.service

yum update -y
