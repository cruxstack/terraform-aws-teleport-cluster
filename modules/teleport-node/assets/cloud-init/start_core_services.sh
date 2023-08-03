#!/bin/bash -xe

function cwagent_ctl {
  /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl "$@"
}
export -f cwagent_ctl

chmod 644 /var/log/cloud-init-output.log
chmod 644 /var/log/messages

cwagent_ctl -a fetch-config -s -m ec2 \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.d/user.json
