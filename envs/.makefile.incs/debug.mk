ifeq ($(DEBUG),1) # DEBUG=1
DEVELOPMENT := 1
SPACK_EXE := $(SPACK_EXE) -d
endif # end DEBUG


ifeq ($(DEVELOPMENT),1) # DEVELOPMENT=1
FORCE_REBUILD_TARGET := 1


$(FORCE_REBUILD_TARGET):
	true

list-phony-targets:
	@( \
		export LC_COLLATE=C; \
		echo $(PHONY_TARGETS) | tr ' ' '\n' | sort -V -u | grep -i -E '^[a-z]' \
	)

list-phony-targets-all:
	@( \
		export LC_COLLATE=C; \
		echo $(PHONY_TARGETS) | tr ' ' '\n' | sort -V -u \
	)

list-file-targets:
	@( \
		export LC_COLLATE=C; \
		echo $(FILE_TARGETS) | tr ' ' '\n' | sort -V -u \
	)

list-generated-targets:
	@( \
		export LC_COLLATE=C; \
		echo $(GENERATED_TARGETS) | tr ' ' '\n' | sort -V -u \
	)

PHONY_TARGETS := $(PHONY_TARGETS) $(FORCE_REBUILD_TARGET) list-phony-targets list-phony-targets-all list-file-targets list-generated-targets

else # DEVELOPMENT=0
FORCE_REBUILD_TARGET ?=
endif # end DEVELOPMENT
