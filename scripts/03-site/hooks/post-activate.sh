#!/bin/bash

for _post_activate_hook in $SPACK_ROOT/dist/bin/hooks/post-activate-*.sh; do
  if [ -x "$_post_activate_hook" ]; then
    "$_post_activate_hook" ||
    echo "E=> Failed to run pre-activate hook: $_post_activate_hook" >&2
  else
    echo "W=> Pre-activate hook is not executable: $_post_activate_hook" >&2
  fi
done

unset -f _post_activate_hook
