META_ACTIONS := lock relock build rebuild
META_ENV_GROUPS:= __all__ __spack__ __cc__ __core__ __dev__ __test__  __faillock__ __failbuild__
META_ALL_TARGETS := $(foreach E,$(META_ENV_GROUPS),$(addsuffix @$E,$(META_ACTIONS)))

SPACK_ENVS := $(shell find -maxdepth 2 -mindepth 2 -iname "spack.yaml" | cut -d/ -f2)
SPACK_ENVS_ALL := $(shell echo -n $(SPACK_ENVS) | tr ' ' '\n' | grep -v -E '^spack-')
SPACK_ENVS_SPACK := $(shell echo -n $(SPACK_ENVS) | tr ' ' '\n' | grep -E '^spack-')
SPACK_ENVS_CORE := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -v -E '^(cc|dev|test|failbuild|faillock)-')
SPACK_ENVS_CC := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -E '^cc-')
SPACK_ENVS_DEV := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -E '^dev-')
SPACK_ENVS_TEST := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -E '^test-')
SPACK_ENVS_FAILBUILD := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -E '^failbuild-')
SPACK_ENVS_FAILLOCK := $(shell echo -n $(SPACK_ENVS_ALL) | tr ' ' '\n' | grep -E '^faillock-')

$(META_ALL_TARGETS):
	$(eval LVAR_ACTION := $(shell echo $@ | cut -d@ -f1))
	$(eval LVAR_TARGET := $(shell echo $@ | cut -d_ -f3))
	$(MAKE) PVAR_ACTION=$(LVAR_ACTION) PVAR_TARGET=$(LVAR_TARGET) .meta_build
	$(eval LVAR_TARGET :=)
	$(eval LVAR_ACTION :=)

.meta_build:
	$(eval LVAR_SPACK_ENVS := $(SPACK_ENVS_$(shell echo $(PVAR_TARGET) | tr 'a-z' 'A-Z')))
	@if [ -z "$(LVAR_SPACK_ENVS)" ]; then \
		echo "No such group: $(PVAR_TARGET)"; \
		exit 1; \
	fi
	$(MAKE) $(addprefix $(PVAR_ACTION)@,$(LVAR_SPACK_ENVS))
	$(eval LVAR_SPACK_ENVS :=)
	@echo "[meta:$(PVAR_TARGET)] $(PVAR_ACTION) completed"

LOCK_TARGETS=$(addprefix lock@,$(SPACK_ENVS))
RELOCK_TARGETS=$(addprefix relock@,$(SPACK_ENVS))
BUILD_TARGETS=$(addprefix build@,$(SPACK_ENVS))
REBUILD_TARGETS=$(addprefix rebuild@,$(SPACK_ENVS))

$(LOCK_TARGETS):
lock@%: %/spack.yaml
	touch $*/spack.yaml
	$(MAKE) $*/spack.lock
	@echo "[$*] lock completed"

$(RELOCK_TARGETS):
relock@%: %/spack.yaml
	-rm $*/spack.lock
	$(MAKE) $*/spack.lock
	@echo "[$*] relock completed"

$(BUILD_TARGETS):
build@%: %/spack.yaml
	$(MAKE) $*/spack.build
	@echo "[$*] build completed"

$(REBUILD_TARGETS):
rebuild@%: %/spack.yaml 
	-rm $*/spack.build
	$(MAKE) relock@$* $*/spack.build
	@echo "[$*] rebuild completed"

GENERATED_TARGETS := $(GENERATED_TARGETS) $(LOCK_TARGETS) $(RELOCK_TARGETS) $(BUILD_TARGETS) $(REBUILD_TARGETS)
PHONY_TARGETS := $(PHONY_TARGETS) $(META_ALL_TARGETS)
