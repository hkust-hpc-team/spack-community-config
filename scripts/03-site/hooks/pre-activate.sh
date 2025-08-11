#!/bin/bash

for _pre_activate_hook in $(ls $SPACK_ROOT/dist/bin/hooks/pre-activate-*.sh 2>/dev/null); do
  if [ -x "$_pre_activate_hook" ]; then
    "$_pre_activate_hook" ||
    echo "E=> Failed to run pre-activate hook: $_pre_activate_hook" >&2
  else
    echo "W=> Pre-activate hook is not executable: $_pre_activate_hook" >&2
  fi
done

unset _pre_activate_hook
