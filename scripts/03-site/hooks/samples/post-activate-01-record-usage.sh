#!/bin/bash

# Source centralized config and helpers (do not export secrets to user env)
source "$SPACK_ROOT/dist/bin/hooks/env.sh"
source "$SPACK_ROOT/dist/bin/hooks/amplitude-common.sh"


amplitude_track_spack_activate() {
  if ! amplitude_is_configured; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Amplitude not configured. Skipping usage tracking." >&2
    return 0
  fi

  local event_props user_props
  event_props=$(printf '{"cluster":"%s","username":"%s","hostname":"%s","spack_variant":"%s","spack_disable_local_config":"%s","spack_root":"%s","spack_user_cache_path":"%s","spack_user_config_path":"%s"%s}' \
    "$(json_escape "${_amplitude_cluster_id}")" \
    "$(json_escape "${USER:-$(whoami 2>/dev/null || echo)}")" \
    "$(json_escape "$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo)")" \
    "$(json_escape "${SPACK_VARIANT:-unknown}")" \
    "$(json_escape "${SPACK_DISABLE_LOCAL_CONFIG:-0}")" \
    "$(json_escape "${SPACK_ROOT:-unknown}")" \
    "$(json_escape "${SPACK_USER_CACHE_PATH:-unknown}")" \
    "$(json_escape "${SPACK_USER_CONFIG_PATH:-unknown}")" \
    "$([ -n "${SLURM_JOB_ID:-}" ] && printf ',"slurm_job_id":"%s"' "$(json_escape "${SLURM_JOB_ID}")")")
  user_props=$(amplitude_default_user_props)

  local json
  json=$(amplitude_build_json "Activate Spack" "${event_props}" "${user_props}")
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Prepared Amplitude event JSON: ${json}" >&2
  amplitude_send_json "${json}"
}

amplitude_track_spack_activate || true
unset -f amplitude_track_spack_activate
