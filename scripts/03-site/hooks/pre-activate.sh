#!/bin/bash

while IFS= read -r -d '' _pre_activate_hook; do
  if [ -x "$_pre_activate_hook" ]; then
    "$_pre_activate_hook" || {
      echo "E=> Failed to run pre-activate hook: $_pre_activate_hook" >&2
      continue
    }
  else
    echo "W=> Pre-activate hook is not executable: $_pre_activate_hook" >&2
  fi
done < <(find "$SPACK_ROOT/dist/bin/hooks" -maxdepth 1 -type f -name 'pre-activate-*.sh' -print0)

unset _pre_activate_hook
