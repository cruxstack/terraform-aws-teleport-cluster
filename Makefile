PROJ_ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# allows args to pass to run-cmd example: make run-cmd echo "hello world"
ifeq (run-cmd,$(firstword $(MAKECMDGOALS)))
  RUN_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(RUN_ARGS):;@:)
endif

all: deps build
	@exit 0

deps:
	@exit 0

build:
	@exit 0

clean:
	@find . -type d -name "dist" -exec rm -rf {} +
	@find . -type d -name ".terraform" -exec rm -rf {} +
	@find . -type d -name ".terraform.d" -exec rm -rf {} +
	@find . -type d -name ".tfstate" -exec rm -rf {} +
	@find . -type d -name ".tfstate.backup" -exec rm -rf {} +
	@touch .devcontainer/.terraform.d/.gitkeep || true
