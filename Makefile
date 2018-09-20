DC_MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))

# Output directory
DC_PREFIX ?= $(shell pwd)

# Set to true to disable fancy / colored output
NON_INTERACTIVE ?=

# Fancy output if interactive
ifndef NON_INTERACTIVE
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

all: build lint test

# Make happy
.PHONY: bootstrap lint-signed lint-code test-unit test-integration build lint test clean

# Simple clean: rm bin & lib

# Build dc-tooling and library
bootstrap:
	$(call title, $@)
	make -s -f sh-art/Makefile build-tooling build-library

$(DC_PREFIX)/bin/regander: $(DC_PREFIX)/lib/dc-sh-art $(DC_PREFIX)/lib/dc-sh-art-extensions source/core/*.sh source/cli/*.sh
	$(call title, $@)
	$(DC_PREFIX)/bin/dc-tooling-build --destination="$(shell dirname $@)" --name="$(shell basename $@)" --license="MIT license" --author="dubo-dubon-duponey" --description="docker registry shell script client" $^

lint-code: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/source
	$(DC_PREFIX)/bin/dc-tooling-lint $(DC_MAKEFILE_DIR)/examples

lint-signed: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/dc-tooling-git $(DC_MAKEFILE_DIR)

test-unit: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/dc-tooling-test --type=unit --tests=$(DC_MAKEFILE_DIR)/tests/unit source/core/*

test-integration: bootstrap
	$(call title, $@)
	$(DC_PREFIX)/bin/dc-tooling-test --type=integration --tests=$(DC_MAKEFILE_DIR)/tests/integration

lint: lint-signed lint-code
test: test-unit test-integration
build: bootstrap $(DC_PREFIX)/bin/regander

# Simple clean: rm bin & lib
clean:
	rm -Rf "${DC_PREFIX}/bin"
	rm -Rf "${DC_PREFIX}/lib"
