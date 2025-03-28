DNF_UPGRADE_TARGET := .dnf-upgrade.build


dnf-upgrade:
	$(SUDO) dnf --refresh upgrade -y 2>&1

$(DNF_UPGRADE_TARGET):
	$(MAKE) dnf-upgrade | tee $@

FILE_TARGETS := $(FILE_TARGETS) $(DNF_UPGRADE_TARGET)
PHONY_TARGETS := $(PHONY_TARGETS) dnf-upgrade
