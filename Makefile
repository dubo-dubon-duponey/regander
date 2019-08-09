# Ouch - necessary for globbing to work
SHELL=/bin/bash -O extglob -c

DC_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Output directory
DC_PREFIX ?= $(shell pwd)

# Set to true to disable fancy / colored output
DC_NO_FANCY ?=

# Fancy output if interactive
ifndef DC_NO_FANCY
    NC := \033[0m
    GREEN := \033[1;32m
    ORANGE := \033[1;33m
    BLUE := \033[1;34m
    RED := \033[1;31m
endif

# Helper to put out nice title
define title
	@echo "$(GREEN)------------------------------------------------------------------------------------------------------------------------"
	@printf "$(GREEN)%*s\n" $$(( ( $(shell echo "☆ $(1) ☆" | wc -c ) + 120 ) / 2 )) "☆ $(1) ☆"
	@echo "$(GREEN)------------------------------------------------------------------------------------------------------------------------$(ORANGE)"
endef

# List of dckr platforms to test
DCKR_PLATFORMS ?= ubuntu-lts-old ubuntu-lts-current ubuntu-current ubuntu-next alpine-current alpine-next debian-old debian-current debian-next

#######################################################
# Targets
#######################################################
all: build lint test test-all

# Make happy
.PHONY: bootstrap build-binaries lint-signed lint-code test-unit test-integration test-all build lint test clean

#######################################################
# Base private tasks
#######################################################
# Build dc-tooling and library
bootstrap:
	$(call title, $@)
	DC_PREFIX=$(DC_PREFIX)/bin/tooling make -s -f $(DC_MAKEFILE_DIR)/sh-art/Makefile build-tooling build-library

#######################################################
# Base building tasks
#######################################################
# Builds the main library
# XXX FIXME: the library itself depends on extensions...
$(DC_PREFIX)/lib/libregander: $(DC_PREFIX)/bin/tooling/lib/dc-sh-art $(DC_PREFIX)/bin/tooling/lib/dc-sh-art-extensions $(DC_MAKEFILE_DIR)/source/core/*.sh
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT License" --author="dubo-dubon-duponey" --description="the library version" --with-git-info $^

$(DC_PREFIX)/lib/libregander-strip: $(DC_MAKEFILE_DIR)/source/core/*.sh
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT License" --author="dubo-dubon-duponey" --description="the library version" --with-git-info $^

# Builds all the CLIs that depend just on the main library
$(DC_PREFIX)/bin/%: $(DC_PREFIX)/lib/libregander $(DC_MAKEFILE_DIR)/source/cli/%
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT License" --author="dubo-dubon-duponey" --description="another fancy piece of shcript" $^

# Builds all the CLIs that depend on the main library and extensions
$(DC_PREFIX)/bin/%: $(DC_PREFIX)/lib/libregander $(DC_PREFIX)/bin/tooling/lib/dc-sh-art-extensions $(DC_MAKEFILE_DIR)/source/cli-ext/%
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT License" --author="dubo-dubon-duponey" --description="another fancy piece of shcript" $^

#######################################################
# Tasks to be called on
#######################################################
# High-level task to build the library
build-library: bootstrap $(DC_PREFIX)/lib/libregander # $(DC_PREFIX)/lib/libregander-strip

# High-level task to build all CLIs
build-binaries: bootstrap $(patsubst $(DC_MAKEFILE_DIR)/source/cli-ext/%/cmd.sh,$(DC_PREFIX)/bin/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli-ext/*/cmd.sh)) \
				$(patsubst $(DC_MAKEFILE_DIR)/source/cli/%/cmd.sh,$(DC_PREFIX)/bin/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli/*/cmd.sh))

lint-signed: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-git $(DC_MAKEFILE_DIR)

lint-code: bootstrap build-library build-binaries
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/source
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/tests
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_PREFIX)/lib
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_PREFIX)/bin/!(tooling)
#	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/examples

# Unit tests
unit/%: bootstrap build-library
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-test $(DC_MAKEFILE_DIR)/tests/$@

test-unit: $(patsubst $(DC_MAKEFILE_DIR)/tests/unit/%,unit/%,$(wildcard $(DC_MAKEFILE_DIR)/tests/unit/*.sh))

# Integration tests
integration/%: bootstrap $(DC_PREFIX)/bin/%
	$(call title, $@)
	PATH=$(DC_PREFIX)/bin:${PATH} $(DC_PREFIX)/bin/tooling/bin/dc-tooling-test $(DC_MAKEFILE_DIR)/tests/$@/*.sh

test-bed:
	if [ "$(shell docker ps -aq --filter "name=regander-registry")" ]; then docker rm -f -v regander-registry; fi
	docker run -d -p 5000:5000 --restart=always --name regander-registry registry:2

test-integration: test-bed build-binaries $(patsubst $(DC_MAKEFILE_DIR)/source/cli/%/cmd.sh,integration/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli/*/cmd.sh)) \
	$(patsubst $(DC_MAKEFILE_DIR)/source/cli-ext/%/cmd.sh,integration/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli-ext/*/cmd.sh))

dckr/%:
	$(call title, $@)
	DOCKERFILE=./sh-art/dckr.Dockerfile TARGET="$(patsubst dckr/%,%,$@)" dckr make test

test-all: $(patsubst %,dckr/%,$(DCKR_PLATFORMS))

build: build-library build-binaries
lint: lint-signed lint-code
test: test-unit test-integration

# Simple clean: rm bin & lib
clean:
	$(call title, $@)
	rm -Rf "${DC_PREFIX}/bin"
	rm -Rf "${DC_PREFIX}/lib"
