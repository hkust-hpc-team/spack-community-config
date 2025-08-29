#!/bin/bash

set -euo pipefail

# Source centralized config and helpers (do not export secrets to user env)
HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_SH="${HOOKS_DIR}/env.sh"
COMMON_SH="${HOOKS_DIR}/amplitude-common.sh"

# Fallback to SPACK_ROOT if files are missing and SPACK_ROOT is set
if [ ! -f "$ENV_SH" ] && [ -n "${SPACK_ROOT}" ] && [ -d "${SPACK_ROOT}/dist/bin/hooks" ]; then
  ENV_SH="${SPACK_ROOT}/dist/bin/hooks/env.sh"
fi
if [ ! -f "$COMMON_SH" ] && [ -n "${SPACK_ROOT}" ] && [ -d "${SPACK_ROOT}/dist/bin/hooks" ]; then
  COMMON_SH="${SPACK_ROOT}/dist/bin/hooks/amplitude-common.sh"
fi

# Check if files exist and are readable
if [ ! -f "$ENV_SH" ] || [ ! -r "$ENV_SH" ]; then
  exit 0
fi
if [ ! -f "$COMMON_SH" ] || [ ! -r "$COMMON_SH" ]; then
  exit 0
fi

# Source the files
source "${ENV_SH}" || { echo "Error sourcing env.sh" >&2; exit 0; }
source "${COMMON_SH}" || { echo "Error sourcing amplitude-common.sh" >&2; exit 0; }


amplitude_track_spack_activate() {
  if ! amplitude_is_configured; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Amplitude not configured. Skipping usage tracking." >&2
    return 0
  fi

  local event_props user_props
  event_props=$(amplitude_common_event_props \
    "$([ -n "${SLURM_JOB_ID:-}" ] && printf '"slurm_job_id":"%s"' "$(json_escape "${SLURM_JOB_ID}")")")
  user_props=$(amplitude_default_user_props)

  local json
  json=$(amplitude_build_json "Activate Spack" "${event_props}" "${user_props}")
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Prepared Amplitude event JSON: ${json}" >&2
  amplitude_send_json "${json}"
}

amplitude_track_spack_activate || true
unset -f amplitude_track_spack_activate
