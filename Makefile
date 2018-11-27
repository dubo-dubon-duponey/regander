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

#######################################################
# Targets
#######################################################
all: build lint test

# Make happy
.PHONY: bootstrap lint-signed lint-code test-unit test-integration build lint test clean

# Build dc-tooling and library
bootstrap:
	$(call title, $@)
	DC_PREFIX=$(DC_PREFIX)/bin/tooling make -s -f sh-art/Makefile build-tooling build-library

$(DC_PREFIX)/bin/%: $(DC_PREFIX)/bin/tooling/lib/dc-sh-art $(DC_PREFIX)/bin/tooling/lib/dc-sh-art-extensions $(DC_MAKEFILE_DIR)/source/core/*.sh $(DC_MAKEFILE_DIR)/source/cli/%
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT License" --author="dubo-dubon-duponey" --description="docker registry shell script client" $^

lint-signed: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-git $(DC_MAKEFILE_DIR)

lint-code: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/source
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/examples
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_PREFIX)/bin/regander
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-lint $(DC_PREFIX)/bin/reghigh

# Unit tests
unit/%: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/tooling/bin/dc-tooling-test $(DC_MAKEFILE_DIR)/tests/$@

test-unit: $(patsubst $(DC_MAKEFILE_DIR)/tests/unit/%,unit/%,$(wildcard $(DC_MAKEFILE_DIR)/tests/unit/*.sh)) \

# Integration tests
integration/%: bootstrap $(DC_PREFIX)/bin/%
	$(call title, $@)
	PATH=$(DC_PREFIX)/bin:${PATH} $(DC_PREFIX)/bin/tooling/bin/dc-tooling-test $(DC_MAKEFILE_DIR)/tests/$@/*.sh

test-bed:
	if [ "$(shell docker ps -aq --filter "name=registry")" ]; then docker rm -f -v registry; fi
	docker run -d -p 5000:5000 --restart=always --name registry registry:2

test-integration: test-bed $(patsubst $(DC_MAKEFILE_DIR)/source/cli/%/cmd.sh,integration/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli/*/cmd.sh)) \
	$(patsubst $(DC_MAKEFILE_DIR)/source/cli-ext/%/cmd.sh,integration/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli-ext/*/cmd.sh))

build-binaries: $(patsubst $(DC_MAKEFILE_DIR)/source/cli/%/cmd.sh,$(DC_PREFIX)/bin/%,$(wildcard $(DC_MAKEFILE_DIR)/source/cli/*/cmd.sh))


build: bootstrap $(DC_PREFIX)/bin/regander $(DC_PREFIX)/bin/reghigh
lint: lint-signed lint-code
test: test-unit test-integration

# Simple clean: rm bin & lib
clean:
	$(call title, $@)
	rm -Rf "${DC_PREFIX}/bin"
	rm -Rf "${DC_PREFIX}/lib"
