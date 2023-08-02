FROM mcr.microsoft.com/vscode/devcontainers/base:jammy

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

# install docker
COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/

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
    && aws --version \
    && docker --version
