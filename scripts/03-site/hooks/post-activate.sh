#!/bin/bash

while IFS= read -r -d '' _post_activate_hook; do
  if [ -x "$_post_activate_hook" ]; then
    "$_post_activate_hook" || {
      echo "E=> Failed to run post-activate hook: $_post_activate_hook" >&2
      continue
    }
  else
    echo "W=> post-activate hook is not executable: $_post_activate_hook" >&2
  fi
done < <(find "$SPACK_ROOT/dist/bin/hooks" -maxdepth 1 -type f -name 'post-activate-*.sh' -print0)

unset _post_activate_hook
