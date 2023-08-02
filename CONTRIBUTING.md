# Contributing

We welcome contributions to the project. This document provides information and
guidelines for contributing.

## Development Environment

This repository includes a configuration for a development container using the
[VS Code Remote - Containers extension](https://code.visualstudio.com/docs/remote/containers).
This setup allows you to develop within a Docker container that already has all
the necessary tools and dependencies installed.

The development container is based on Ubuntu 22.04 (Jammy) and includes the
following tools:

- AWS CLI
- Python v3.8
- Python Packages: `boto3`, `black`
- Docker CLI
- Shellcheck
- Terraform

### Prerequisites

- [Docker](https://www.docker.com/products/docker-desktop) installed on your
  local machine.
- [Visual Studio Code](https://code.visualstudio.com/) installed on your
  local machine.
- [Remote - Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)
  for Visual Studio Code.

### Usage

1. Clone and open this repository:

    ```bash
    git clone https://github.com/sgtoj/terraform-aws-teleport-cluster.git
    code terraform-aws-teleport-cluster
    ```

2. When prompted to "Reopen in Container", click "Reopen in Container". This
   will start building the Docker image for the development container. If you're
   not prompted, you can open the Command Palette (F1 or Ctrl+Shift+P), and run
   the "Remote-Containers: Reopen Folder in Container" command.

3. After the development container is built and started, you can use the
   Terminal in Visual Studio Code to interact with the container. All commands
  you run in the Terminal will be executed inside the container.

### Troubleshooting

If you encounter any issues while using the development container, you can try
rebuilding the container. To do this, open the Command Palette and run the
"Remote-Containers: Rebuild Container" command.

## Contribution Guidelines

We appreciate your interest in contributing to the project. Here are some
guidelines to help ensure your contributions are accepted.

### Issues

- Use the GitHub issue tracker to report bugs or propose new features.
- Before submitting a new issue, please search to make sure it has not already
  been reported. If it has, add a comment to the existing issue instead of
  creating a new one.
- When reporting a bug, include as much detail as you can. Include the version
  of the module you're using, what you expected to happen, what actually
  happened, and steps to reproduce the bug.

### Pull Requests

- Submit your changes as a pull request.
- All pull requests should be associated with an issue. If your change isn't
  associated with an existing issue, please create one before submitting a pull
  request.
- In your pull request, include a summary of the changes, the issue number it
  resolves, and any additional information that might be helpful for
  understanding your changes.
- Make sure your changes do not break any existing functionality. If your
  changes require updates to existing tests or the addition of new ones, include
  those in your pull request.
- Follow the existing code style. We use a linter to maintain code quality, so
  make sure your changes pass the linter checks.

Thank you for your contributions!
