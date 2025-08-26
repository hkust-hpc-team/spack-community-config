#!/usr/bin/env bash
# Module-load hook: send a JSON event to Amplitude with module details.
# Args:
#   $1 = module full name (e.g., hdf5/1.14.2-01-zen4-ksodqwe)
#   $2 = module version    (e.g., 1.14.2-01-zen4-ksodqwe)
# Config (env):
#   SPACK_AMPLITUDE_API_KEY      (required)
#   SPACK_AMPLITUDE_CLUSTER_ID   (required)
#   SPACK_AMPLITUDE_HTTPAPI_URL  (optional, default: https://api2.amplitude.com/2/httpapi)

set -euo pipefail

[ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Script hooked: $1 ($2)" >&2

declare api_key="${SPACK_AMPLITUDE_API_KEY:-}"
declare cluster_id="${SPACK_AMPLITUDE_CLUSTER_ID:-}"
declare httpapi_url="${SPACK_AMPLITUDE_HTTPAPI_URL:-https://api2.amplitude.com/2/httpapi}"

if [ -z "${api_key}" ] || [ -z "${cluster_id}" ]; then
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing configuration" >&2
  exit 1
fi

curl_bin="$(command -v curl || true)"
if [ -z "${curl_bin}" ]; then
  exit 1
fi

if [ -z "${1:-}" ] || [ -z "${2:-}" ]; then
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: missing module arguments" >&2
  exit 1
fi

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
  *)
    return 1
    ;;
  esac
}

analytics_lmod_send_version() {
  local mod_name="${1%%/*}"
  local -r mod_ver_arr=("${2//-/ }")
  local mod_ver=""  # everything except last (and second last if architecture)
  local mod_arch="" # optional, second last token if matches known architecture
  local mod_hash="" # last, 7 characters [a-z0-9]

  # must have at least version and hash
  if [ "${#mod_ver_arr[@]}" -lt 2 ]; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module version format" >&2
    return 1
  fi

  # check hash format and assign mod_hash
  if [[ "${mod_ver_arr[-1]}" =~ ^[a-z0-9]{7}$ ]]; then
    mod_hash="${mod_ver_arr[-1]}"
  else
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module hash format" >&2
    return 1
  fi

  # check if second last token is architecture, mod_ver should exclude architecture
  if version_is_architecture "${mod_ver_arr[-2]}"; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Detected module architecture: ${mod_ver_arr[-2]}" >&2
    mod_arch="${mod_ver_arr[-2]}"
    if [ "${#mod_ver_arr[@]}" -lt 3 ]; then
      [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude event: invalid module version format" >&2
      return 1
    fi
    mod_ver="${mod_ver_arr[*]:0:$((${#mod_ver_arr[@]} - 2))}"
  else
    mod_ver="${mod_ver_arr[*]:0:$((${#mod_ver_arr[@]} - 1))}"
  fi
  mod_ver="${mod_ver// /-}"

  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Parsed module: name='${mod_name}', version='${mod_ver}', architecture='${mod_arch}', hash='${mod_hash}'" >&2

  amplitude_lmod_send_event "${mod_name}" "${mod_ver}" "${mod_version_long}" "${mod_arch}"
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
  local device_id="${username}@${cluster_id}/${session_date}"
  local user_id="${username}@${cluster_id}"

  # Build JSON payload (single event)
  local json_data=$(printf '{
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
      "module_version_long": "%s"%s
    },
    "user_properties": {
      "cluster": "%s",
      "username": "%s"
    }
  }]
}' \
    "${api_key}" \
    "${device_id}" \
    "${user_id}" \
    "${cluster_id}" \
    "${username}" \
    "${hostname_fqdn}" \
    "${mod_name}" \
    "${mod_version}" \
    "${mod_version_long}" \
    "$([ -n "${mod_arch}" ] && printf ', "module_architecture": "%s"' "${mod_arch}" || printf '')" \
    "${cluster_id}" \
    "${username}")
  [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Prepared Amplitude event JSON: ${json_data}" >&2
  echo "${json_data}"
}

amplitude_lmod_send_event() {
  local json_data="$(amplitude_lmod_prepare_event $@)"

  max_attempts=3
  attempt=1
  while ((attempt <= max_attempts)); do
    response_code=$("${curl_bin}" -s -o /dev/null -w "%{http_code}" \
      -X POST "${httpapi_url}" \
      -H 'Content-Type: application/json' \
      -H 'Accept: */*' \
      --data "${json_data}")
    if [ "${response_code}" = "200" ]; then
      return 0
    fi
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Attempt ${attempt} failed with HTTP status ${response_code}, retrying..." >&2
    sleep "0.$((attempt * 2))"
    attempt=$((attempt + 1))
  done
}

analytics_lmod_send_version "${mod_fullname}" "${mod_version_long}"
