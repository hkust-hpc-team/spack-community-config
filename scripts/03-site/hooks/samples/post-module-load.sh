#!/usr/bin/env bash
# Module-load hook: send a JSON event to Amplitude with module details.
# Args:
#   $1 = module full name (e.g., hdf5/1.14.2-01-zen4-ksodqwe)
#   $2 = module version    (e.g., 1.14.2-01-zen4-ksodqwe)

set -euo pipefail

# Source centralized config and helpers (do not export secrets to user env)
source "$SPACK_ROOT/dist/bin/hooks/env.sh"

[ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Script hooked: ${1:-} (${2:-})" >&2

# If missing config or curl, do not interfere with module loading; just exit 0.
curl_bin="$(command -v curl || true)"
if [ -z "${_amplitude_api_key}" ] || [ -z "${_amplitude_cluster_id}" ] ||
  [ -z "${_amplitude_httpapi_url}" ] || [ -z "${curl_bin}" ]; then
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing configuration or curl" >&2
  exit 0
fi

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing module arguments" >&2
  exit 0
fi

# JSON escape helper: escape backslashes, quotes, and newlines
json_escape() {
  local s=${1-}
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  echo -n "$s"
}

version_is_architecture() {
  local ver="${1:-}"
  case "${ver}" in
  # x86 (Intel/AMD) march
  i686 | x86 | x86_64 | x86_64_v2 | x86_64_v3 | x86_64_v4) return 0 ;;
  core2 | nocona | prescott | pentium2 | pentium3 | pentium4) return 0 ;;
  nehalem | westmere | sandybridge | ivybridge | haswell | broadwell) return 0 ;;
  skylake | skylake_avx512 | cannonlake | icelake | cascadelake | sapphirerapids) return 0 ;;
  k10 | bulldozer | piledriver | steamroller | excavator) return 0 ;;
  zen | zen2 | zen3 | zen4 | zen5) return 0 ;;
  mic_knl) return 0 ;;
  # Generic ARM
  arm | aarch64) return 0 ;;
  armv8.1a | armv8.2a | armv8.3a | armv8.4a | armv8.5a | armv9.0a) return 0 ;;
  cortex_a72 | neoverse_n1 | neoverse_n2 | neoverse_v1 | neoverse_v2 | a64fx) return 0 ;;
  m1 | m2) return 0 ;;
  thunderx2) return 0 ;;
  # PowerPC march
  ppc | ppc64 | ppc64le | ppcle) return 0 ;;
  power7 | power8 | power8le | power9 | power9le | power10 | power10le) return 0 ;;
  # SPARC march
  sparc | sparc64) return 0 ;;
  # RISC-V march
  riscv64 | u74mc) return 0 ;;
  *) return 1 ;;
  esac
}

# Join array elements by delimiter
join_by() {
  local d="$1"
  shift
  if [ $# -gt 0 ]; then
    printf "%s" "$1"
    shift
    printf "%s" "${@/#/$d}"
  fi
}


analytics_lmod_send_version() {
  local mod_name="${1%%/*}"

  # Split long version into tokens on '-'
  local -a mod_ver_arr=()
  IFS=' ' read -r -a mod_ver_arr <<<"${2//-/ }"

  local mod_ver=""  # everything except last (and second last if architecture)
  local mod_arch="" # optional, second last token if matches known architecture
  local mod_hash="" # last, 7 characters [a-z0-9]

  # must have at least version and hash
  if [ "${#mod_ver_arr[@]}" -lt 2 ]; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module version format" >&2
    return 0
  fi

  # check hash format and assign mod_hash
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

amplitude_lmod_prepare_event() {
  local mod_name="${1:-}"
  local mod_version="${2:-}"
  local mod_version_long="${3:-}"
  local mod_arch="${4:-}"

  if [ -z "${mod_name}" ] || [ -z "${mod_version}" ] || [ -z "${mod_version_long}" ]; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing module details" >&2
    return 1
  fi

  local username="${USER:-$(whoami 2>/dev/null || echo)}"
  local hostname_fqdn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo)"
  local session_date="$(date +%Y-%m-%d)"
  local device_id="${username}@${_amplitude_cluster_id}/${session_date}"
  local user_id="${username}@${_amplitude_cluster_id}"

  local _amplitude_spack_variant="${SPACK_VARIANT:-unknown}"
  local _amplitude_spack_disable_local_config="${SPACK_DISABLE_LOCAL_CONFIG:-0}"
  local _amplitude_spack_root="${SPACK_ROOT:-unknown}"
  local _amplitude_spack_user_cache_path="${SPACK_USER_CACHE_PATH:-unknown}"
  local _amplitude_spack_user_config_path="${SPACK_USER_CONFIG_PATH:-unknown}"

  # Optional extra event properties
  local extra_props=""
  add_json_prop() {
    if [ -n "$2" ]; then
      extra_props+=$(printf ', "%s": "%s"' "$1" "$(json_escape "$2")")
    fi
  }
  add_json_prop "module_architecture" "${mod_arch}"
  unset -f add_json_prop

  # Build JSON payload (single event)
  local json_data
  json_data=$(printf '{
  "api_key": "%s",
  "events": [{
    "device_id": "%s",
    "user_id": "%s",
    "event_type": "Module Load",
    "event_properties": {
      "cluster": "%s",
      "username": "%s",
      "hostname": "%s",
      "module_name": "%s",
      "module_version": "%s",
      "module_version_long": "%s",
      "spack_variant": "%s",
      "spack_disable_local_config": "%s",
      "spack_root": "%s",
      "spack_user_cache_path": "%s",
      "spack_user_config_path": "%s"%s
    },
    "user_properties": {
      "cluster": "%s",
      "username": "%s"
    }
  }]
}' \
    "$(json_escape "${_amplitude_api_key}")" \
    "$(json_escape "${device_id}")" \
    "$(json_escape "${user_id}")" \
    "$(json_escape "${_amplitude_cluster_id}")" \
    "$(json_escape "${username}")" \
    "$(json_escape "${hostname_fqdn}")" \
    "$(json_escape "${mod_name}")" \
    "$(json_escape "${mod_version}")" \
    "$(json_escape "${mod_version_long}")" \
    "$(json_escape "${_amplitude_spack_variant}")" \
    "$(json_escape "${_amplitude_spack_disable_local_config}")" \
    "$(json_escape "${_amplitude_spack_root}")" \
    "$(json_escape "${_amplitude_spack_user_cache_path}")" \
    "$(json_escape "${_amplitude_spack_user_config_path}")" \
    "${extra_props}" \
    "$(json_escape "${_amplitude_cluster_id}")" \
    "$(json_escape "${username}")")
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Prepared Amplitude event JSON: ${json_data}" >&2
  echo "${json_data}"
}

amplitude_lmod_send_event() {
  local json_data
  json_data="$(amplitude_lmod_prepare_event "$@" || true)"
  if [ -z "${json_data}" ]; then
    return 0
  fi

  local max_attempts=3
  local attempt=1
  while ((attempt <= max_attempts)); do
    # Small timeouts to avoid blocking module loads
    local response_code
    response_code=$("${curl_bin}" -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout 1 --max-time 2 \
      -A "spack-module-hook/1.0" \
      -X POST "${_amplitude_httpapi_url}" \
      -H 'Content-Type: application/json' \
      -H 'Accept: */*' \
      --data-binary "${json_data}" || echo "000")
    if [[ "${response_code}" =~ ^20[0-9]$ ]]; then
      return 0
    fi
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Amplitude post attempt ${attempt} failed (HTTP ${response_code}), retrying..." >&2
    sleep "$(awk "BEGIN {printf 0.2 * $attempt}")"
    attempt=$((attempt + 1))
  done
  # Never fail the module load due to analytics
  return 0
}

analytics_lmod_send_version "$1" "$2"
