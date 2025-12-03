SPACK_COMPILER_PREFIX := $(wildcard $(SPACK_ROOT)/opt/spack/linux-*-x86_64_v4/gcc-*.spack)
SPACK_MPI_COMPILERS := aocc intel-oneapi
SPACK_COMPILERS := ${SPACK_MPI_COMPILERS} gcc nvhpc
SPACK_MPI_COMPILER_TARGETS := $(wildcard $(foreach cc,$(SPACK_MPI_COMPILERS),100*-cc-$(cc)/spack.build))
SPACK_COMPILER_TARGETS := $(wildcard $(foreach cc,$(SPACK_COMPILERS),100*-cc-$(cc)/spack.build))

compiler-find-mpi.build: $(SPACK_MPI_COMPILER_TARGETS)
	spack compiler find \
		$(SPACK_COMPILER_PREFIX)/{aocc,intel-oneapi-compilers-classic}-[0-9]* \
		$(SPACK_COMPILER_PREFIX)/intel-oneapi-compilers-2*/compiler/2*/{,linux}
	$(MAKE) clean
	touch $@

compiler-find-all.build: $(SPACK_COMPILER_TARGETS)
	spack compiler find \
		$(SPACK_COMPILER_PREFIX)/{aocc,gcc,intel-oneapi-compilers-classic}-[0-9]* \
		$(SPACK_COMPILER_PREFIX)/intel-oneapi-compilers-2*/compiler/2*/{,linux} \
		$(SPACK_COMPILER_PREFIX)/nvhpc-2*/Linux_x86_64/2*.*/compilers
	$(MAKE) clean
	touch $@

compiler-find-os:
	-rm $(SPACK_ROOT)/etc/spack/linux/compilers.yaml
	spack compiler find \
		$(SPACK_ROOT)/opt/spack/linux-*-x86_64_v4/gcc-*.os/gcc-11.5.0-*
	sed 's|gcc@=11.5.0|gcc@=11.5.0.spack|g' -i $(SPACK_ROOT)/etc/spack/linux/compilers.yaml
	$(MAKE) clean

PHONY_TARGETS := $(PHONY_TARGETS) compiler-find-os
FILE_TARGETS := $(FILE_TARGETS) compiler-find-mpi.build compiler-find-all.build
