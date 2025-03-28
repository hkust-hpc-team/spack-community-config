# Temporary build automation solution

DEBUG ?= 0
DEVELOPMENT ?= 0
NUM_PARALLEL_BUILDS ?= 4
SPACK_CMD_ARGS ?=
SPACK_SYNC_ARGS ?=
SPACK_LOCK_ARGS ?= -U

SHELL := /usr/bin/bash -o pipefail
SUDO  := sudo
SPACK_EXE := spack $(SPACK_CMD_ARGS)
NPROC := $(shell nproc)

# for debugging
FILE_TARGETS :=
GENERATED_TARGETS :=
PHONY_TARGETS :=

default: build@__all__

include .makefile.incs/preflight.mk
include .makefile.incs/debug.mk
include .makefile.incs/dnf.mk
include .makefile.incs/spack/config.mk
include .makefile.incs/spack/make-cli.mk
include .makefile.incs/spack/spack-env-deps.mk
include .makefile.incs/spack/spack-build.mk
include .makefile.incs/spack/gc.mk

.SUFFIXES: .build .lock .yaml
.PHONY: $(PHONY_TARGETS)

check:
	_incomplete_build=0; \
	for env in $(SPACK_ENVS); do \
		if spack -e $$env find -c | grep -v -E '^(\[[+e]\]|-- |==> |$$)'; then \
			echo "[$$env] build incomplete"; \
			_incomplete_build=1; \
		fi; \
	done; \
	exit $$_incomplete_build

lmod:
	spack_args="--delete-tree -y"; \
	for env in $$(find -maxdepth 1 -mindepth 1 -type d | cut -d/ -f2); do \
		echo spack -e $$env lmod refresh $$spack_args; \
		spack -e $$env lmod refresh $$spack_args; \
		spack_args="-y"; \
	done
