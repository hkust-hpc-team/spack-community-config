#!/usr/bin/env bash
# Common helpers for Amplitude-related hooks.
# Assumes env.sh has been sourced to provide _amplitude_api_key, _amplitude_cluster_id, _amplitude_httpapi_url.

set -o pipefail

amplitude_is_configured() {
  command -v curl >/dev/null 2>&1 || return 1
  [ -n "${_amplitude_api_key:-}" ] && [ -n "${_amplitude_cluster_id:-}" ] && [ -n "${_amplitude_httpapi_url:-}" ]
}

json_escape() {
  local s=${1-}
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//$'\n'/\\n}
  s=${s//$'\r'/}
  echo -n "$s"
}

# Join array elements by delimiter
join_by() {
  local d="$1"; shift
  if [ $# -gt 0 ]; then
    printf "%s" "$1"; shift
    printf "%s" "${@/#/$d}"
  fi
}

# Heuristic: whether a token looks like a CPU architecture name
version_is_architecture() {
  local ver="${1:-}"
  case "${ver}" in
    i686|x86|x86_64|x86_64_v2|x86_64_v3|x86_64_v4|
    core2|nocona|prescott|pentium2|pentium3|pentium4|
    nehalem|westmere|sandybridge|ivybridge|haswell|broadwell|
    skylake|skylake_avx512|cannonlake|icelake|cascadelake|sapphirerapids|
    k10|bulldozer|piledriver|steamroller|excavator|
    zen|zen2|zen3|zen4|zen5|mic_knl|
    arm|aarch64|armv8.1a|armv8.2a|armv8.3a|armv8.4a|armv8.5a|armv9.0a|
    cortex_a72|neoverse_n1|neoverse_n2|neoverse_v1|neoverse_v2|a64fx|m1|m2|thunderx2|
    ppc|ppc64|ppc64le|ppcle|power7|power8|power8le|power9|power9le|power10|power10le|
    sparc|sparc64|
    riscv64|u74mc) return 0 ;;
    *) return 1 ;;
  esac
}

# Send a single event JSON to Amplitude. Never fails the caller; retries briefly and returns 0.
amplitude_send_json() {
  local json_data="$1"
  if ! amplitude_is_configured; then
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Skipping Amplitude: not configured or curl missing" >&2
    return 0
  fi
  local curl_bin; curl_bin="$(command -v curl)"
  local max_attempts=3 attempt=1
  while (( attempt <= max_attempts )); do
    local code
    code=$("${curl_bin}" -sS -o /dev/null -w "%{http_code}" \
      --connect-timeout 1 --max-time 2 \
      -A "spack-module-hook/1.0" \
      -X POST "${_amplitude_httpapi_url}" \
      -H 'Content-Type: application/json' \
      -H 'Accept: */*' \
      --data-binary "${json_data}" || echo "000")
    [[ "${code}" =~ ^20[0-9]$ ]] && return 0
    [ -n "${SPACK_HOOK_DEBUG:-}" ] && echo "Amplitude post attempt ${attempt} failed (HTTP ${code}), retrying..." >&2
    sleep "$(awk "BEGIN {printf 0.2 * ${attempt}}")"
    attempt=$((attempt+1))
  done
  return 0
}

# Build common identity fields
amplitude_identity_fill() {
  local username hostname_fqdn session_date
  username="${USER:-$(whoami 2>/dev/null || echo)}"
  hostname_fqdn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo)"
  session_date="$(date +%Y-%m-%d)"
  echo "${username}" "${hostname_fqdn}" "${session_date}"
}

# Build an Amplitude JSON for an event with event_properties and user_properties.
# Args: event_type, kv pairs for event_properties (already JSON escaped), and optional extra fields hook may add.
amplitude_build_json() {
  local event_type="$1"; shift
  local username hostname_fqdn session_date
  read -r username hostname_fqdn session_date < <(amplitude_identity_fill)
  local device_id="${username}@${_amplitude_cluster_id}/${session_date}"
  local user_id="${username}@${_amplitude_cluster_id}"

  local event_props="$1"; shift || true
  local user_props=${1:-""}; shift || true

  printf '{
  "api_key": "%s",
  "events": [{
    "device_id": "%s",
    "user_id": "%s",
    "event_type": "%s",
    "event_properties": %s,
    "user_properties": %s
  }]
}' \
    "$(json_escape "${_amplitude_api_key}")" \
    "$(json_escape "${device_id}")" \
    "$(json_escape "${user_id}")" \
    "$(json_escape "${event_type}")" \
    "${event_props}" \
    "${user_props}"
}

# Default user_properties include cluster and username
amplitude_default_user_props() {
  local username; username="${USER:-$(whoami 2>/dev/null || echo)}"
  printf '{"cluster":"%s","username":"%s"}' \
    "$(json_escape "${_amplitude_cluster_id}")" \
    "$(json_escape "${username}")"
}
