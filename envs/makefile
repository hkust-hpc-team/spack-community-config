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
	spack lmod refresh -y --delete-tree

compiler-find:
	spack compiler find \
		$(SPACK_ROOT)/opt/spack/linux-*-x86_64_v4/gcc-*.spack/{aocc,gcc,intel-oneapi-compilers-classic,llvm}-[0-9]* \
		$(SPACK_ROOT)/opt/spack/linux-*-x86_64_v4/gcc-*.spack/intel-oneapi-compilers-2*/compiler/2*/{,linux}
	$(MAKE) clean

compiler-find-os:
	-rm $(SPACK_ROOT)/etc/spack/linux/compilers.yaml
	spack compiler find \
		$(SPACK_ROOT)/opt/spack/linux-*-x86_64_v4/gcc-*.os/gcc-11.5.0-*
	sed 's|gcc@=11.5.0|gcc@=11.5.0.spack|g' -i $(SPACK_ROOT)/etc/spack/linux/compilers.yaml
	$(MAKE) clean
