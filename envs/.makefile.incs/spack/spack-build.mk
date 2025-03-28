SPACK_ENV_LOCK_FILES := $(addsuffix /spack.lock,$(SPACK_ENVS))
SPACK_ENV_BUILD_FILES := $(addsuffix /spack.build,$(SPACK_ENVS))


$(SPACK_ENV_LOCK_FILES):
%/spack.lock: %/spack.yaml $(SPACK_CONFIG_MAIN) $(DNF_UPGRADE_TARGET) $(FORCE_REBUILD_TARGET)
	$(SPACK_EXE) -e $* lock $(SPACK_LOCK_ARGS) 2>&1 \
		&& touch $@

$(SPACK_ENV_BUILD_FILES):
%/spack.build: %/spack.lock $(SPACK_CONFIG_MAIN) $(FORCE_REBUILD_TARGET)
	( \
		for i in {1..$(NUM_PARALLEL_BUILDS)}; do \
			$(SPACK_EXE) -e $* sync $(SPACK_SYNC_ARGS) & \
			sleep 0.5; \
		done; \
		exitcode=0; \
		for i in {1..$(NUM_PARALLEL_BUILDS)}; do \
			wait -n -f; \
			_exitcode=$$?; \
			if [ $$_exitcode -ne 127 ]; then \
				exitcode=$$((exitcode + _exitcode)); \
			fi; \
		done; \
		if [ $$exitcode -eq 0 ]; then \
			touch $@; \
		fi; \
		exit $$exitcode \
	) 2>&1

FILE_TARGETS := $(FILE_TARGETS) $(SPACK_ENV_LOCK_FILES) $(SPACK_ENV_BUILD_FILES)
