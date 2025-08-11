#!/bin/bash

for _post_activate_hook in $SPACK_ROOT/dist/bin/hooks/post-activate-*.sh; do
  if [ -x "$_post_activate_hook" ]; then
    "$_post_activate_hook" ||
    echo "E=> Failed to run post-activate hook: $_post_activate_hook" >&2
  else
    echo "W=> Post-activate hook is not executable: $_post_activate_hook" >&2
  fi
done

unset _post_activate_hook
