FROM mcr.microsoft.com/devcontainers/base:jammy

# install aws
RUN SYSTEM_ARCH=$(uname -m) \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-${SYSTEM_ARCH}.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && aws/install \
    && aws --version \
    && rm -rf aws

# install terraform
ENV TERRAFORM_VERSION=1.5.1
ENV TF_PLUGIN_CACHE_DIR=$HOME/.terraform.d/plugin-cache
RUN mkdir -p $TF_PLUGIN_CACHE_DIR
RUN SYSTEM_ARCH=$(dpkg --print-architecture) \
    && curl -OL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${SYSTEM_ARCH}.zip \
    && unzip terraform_${TERRAFORM_VERSION}_linux_${SYSTEM_ARCH}.zip \
    && mv terraform /usr/local/bin/ \
    && terraform version \
    && rm terraform_${TERRAFORM_VERSION}_linux_${SYSTEM_ARCH}.zip

# install tflint
RUN curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# install teleport tsh
ENV TELEPORT_VERSION=10.3.16
RUN SYSTEM_ARCH=$(dpkg --print-architecture) \
    && curl -OLk https://get.gravitational.com/teleport-v${TELEPORT_VERSION}-linux-${SYSTEM_ARCH}-bin.tar.gz \
    && tar -xvf teleport-v${TELEPORT_VERSION}-linux-${SYSTEM_ARCH}-bin.tar.gz teleport/tsh teleport/tctl \
    && mv teleport/tsh /usr/local/bin/tsh \
    && mv teleport/tctl /usr/local/bin/tctl \
    && chmod +x  /usr/local/bin/tsh \
    && chmod +x  /usr/local/bin/tctl \
    && rm -rf teleport/ teleport-*.tar.gz

# install pip
RUN apt-get update
RUN apt-get install -y \
    python3-pip \
    shellcheck

# install python packages
RUN python3 -m pip install \
    boto3 \
    black

# verify installs
RUN terraform --version \
    && aws --version
