#!/bin/bash

# Module-load hook: send a JSON event to Amplitude with module details.
# Args:
#   $1 = module full name (e.g., hdf5/1.14.2-01-zen4-ksodqwe)
#   $2 = module version    (e.g., 1.14.2-01-zen4-ksodqwe)

set -euo pipefail

[ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Script hooked: ${1:-} (${2:-})" >&2

# Source centralized config and helpers (do not export secrets to user env)
HOOKS_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")")"
ENV_SH="${HOOKS_DIR}/env.sh"
COMMON_SH="${HOOKS_DIR}/amplitude/common.sh"

# Fallback to SPACK_ROOT if files are missing and SPACK_ROOT is set
if [ ! -f "$ENV_SH" ] && [ -n "${SPACK_ROOT}" ] && [ -d "${SPACK_ROOT}/dist/bin/hooks" ]; then
  ENV_SH="${SPACK_ROOT}/dist/bin/hooks/env.sh"
fi
if [ ! -f "$COMMON_SH" ] && [ -n "${SPACK_ROOT}" ] && [ -d "${SPACK_ROOT}/dist/bin/hooks" ]; then
  COMMON_SH="${SPACK_ROOT}/dist/bin/hooks/amplitude/common.sh"
fi

if [ ! -f "$ENV_SH" ] || [ ! -r "$ENV_SH" ] || [ ! -f "$COMMON_SH" ] || [ ! -r "$COMMON_SH" ]; then
  exit 0
fi

source "${ENV_SH}" || {
  echo "Error sourcing env.sh" >&2
  exit 0
}
source "${COMMON_SH}" || {
  echo "Error sourcing amplitude/common.sh" >&2
  exit 0
}

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing module arguments" >&2
  exit 0
fi

analytics_lmod_send_version() {
  local mod_name="${1%%/*}"
  local -a mod_ver_arr=()
  IFS=' ' read -r -a mod_ver_arr <<<"${2//-/ }"

  local mod_ver="" mod_arch="" mod_hash=""
  if [ "${#mod_ver_arr[@]}" -lt 2 ]; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module version format" >&2
    return 0
  fi

  local version_last_index=${#mod_ver_arr[@]}
  local last_idx=$((version_last_index - 1))
  if [[ "${mod_ver_arr[last_idx]}" =~ ^[a-z0-9]{7}$ ]]; then
    mod_hash="${mod_ver_arr[last_idx]}"
    version_last_index=$((version_last_index - 1))
  else
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module hash format" >&2
    return 0
  fi

  last_idx=$((version_last_index - 1))
  if version_is_architecture "${mod_ver_arr[last_idx]}"; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Detected module architecture: ${mod_ver_arr[last_idx]}" >&2
    mod_arch="${mod_ver_arr[last_idx]}"
    if [ "${#mod_ver_arr[@]}" -lt 3 ]; then
      [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module version format" >&2
      return 0
    fi
    version_last_index=$((version_last_index - 1))
  fi

  local -a ver_elems=("${mod_ver_arr[@]:0:${version_last_index}}")
  mod_ver="$(join_by '-' "${ver_elems[@]}")"

  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Parsed module: name='${mod_name}', version='${mod_ver}', architecture='${mod_arch}', hash='${mod_hash}'" >&2

  amplitude_lmod_send_event "${mod_name}" "${mod_ver}" "$2" "${mod_arch}"
}

amplitude_lmod_send_event() {
  local mod_name="${1:-}"
  local mod_version="${2:-}"
  local mod_version_long="${3:-}"
  local mod_arch="${4:-${_spack_module_default_arch}}"
  if [ -z "${mod_name}" ] || [ -z "${mod_version}" ] || [ -z "${mod_version_long}" ]; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing module details" >&2
    return 0
  fi

  local event_props=$(amplitude_common_event_props \
    $(printf '"module_name":"%s","module_version":"%s","module_version_long":"%s","module_arch":"%s"' \
      "$(json_escape "${mod_name}")" \
      "$(json_escape "${mod_version}")" \
      "$(json_escape "${mod_version_long}")" \
      "$(json_escape "${mod_arch}")"))
  local user_props=$(amplitude_default_user_props)

  local json=$(amplitude_build_json "Module Load" "${event_props}" "${user_props}")
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Prepared Amplitude event JSON: ${json}" >&2
  amplitude_send_json "${json}"
}

analytics_lmod_send_version "$1" "$2"
