gc:
	@if [ "$$SPACK_DISABLE_LOCAL_CONFIG" == "1" ]; then \
		$(MAKE) .gc-impl-root-rapid; \
	else \
		$(MAKE) .gc-impl-stable; \
	fi

# TODO: need verify not to delete sth strange
# This is a hackery version of gc, only for site
# Breakdown by line:
# L2-3. get all gc candidates into "<hash> <pkg> <version>" per line
# L4. transform into "<pkg>@<version>/<hash>"
# L5. get the path of the package, got "<pkg@version> <path>"
# L6. IMPORTANT: filter away packages not in spack install root
# L7-8. print only <path> and do `mv <path> $SPACK_ROOT/opt/trash/` (fast)
# L9-10. rebuild index
# L11. gc again to remove those related to fix index & remove externals
.gc-impl-root-rapid:
	# $(eval LVAR_TRASHDIR := $(SPACK_ROOT)/opt/.trash-$(shell date +%s)/)
	# @test "$$SPACK_DISABLE_LOCAL_CONFIG" == "1"
	# -@mkdir -p $(LVAR_TRASHDIR)
	# - echo n | spack gc -E -b \
	# | grep @ | grep -v -E ' / ' | tr '@' ' ' \
	# | awk '{printf "%s@%s/%s\n",$$2,$$3,$$1}' \
	# | xargs -r -P $(NPROC) -n 8 spack find -p \
	# | grep -E "$$SPACK_ROOT/opt/spack" \
	# | awk '{print $$2}' \
	# | xargs -r -P $(NPROC) -t -i echo mv {} $(LVAR_TRASHDIR)
	# - fd -uu0a '\.backup.*' $$SPACK_ROOT/opt/spack | xargs -rt0 -P $(NPROC) -i mv {} $(LVAR_TRASHDIR)
	# spack clean -dfms
	# spack reindex
	# $(eval LVAR_TRASHDIR :=)
	- $(MAKE) .gc-impl-stable

.gc-impl-stable:
	@if ( spack env status | grep 'In environment' ); then \
		echo "Error: Cannot gc all in environment"; \
		echo "Please run `spack env deactivate` first"; \
		exit 1; \
	fi
	while echo n | spack gc -E -b | grep 'Do you want to proceed'; do \
	 	echo n | spack gc -E -b \
			| grep @ | grep -v -E ' / ' | awk '{printf "/%s\n",$$1}' \
			| xargs -r -t -P $(NPROC) -i spack uninstall --force -y {}; \
	done
	spack clean -dfms
	- spack gc -E -b -y

clean:
	spack clean -dfms

dist-clean:
	spack clean -bdfms
