define check_not_in_env
@if spack env status | grep -q 'In environment'; then \
	echo "Error: Cannot perform this action while in a spack environment."; \
	echo "Please run 'spack env deactivate' first."; \
	exit 1; \
fi
endef

gc-unmark:
	$(call check_not_in_env)
	echo n | spack gc -E -b \
		| grep @ | grep -v -E ' / ' | awk '{printf "/%s\n",$$1}' \
		| xargs -r -t -P $(NPROC) spack mark --all -i;

gc-delete:
	$(call check_not_in_env)
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
