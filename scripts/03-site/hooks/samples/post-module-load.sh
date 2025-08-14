#!/usr/bin/env bash
# Module-load hook: send a JSON event to Amplitude with module details.
# Args:
#   $1 = module full name (e.g., hdf5/1.14.2-ksodqwe)
#   $2 = module version    (e.g., 1.14.2-ksodqwe)
# Config (env):
#   SPACK_AMPLITUDE_API_KEY      (required)
#   SPACK_AMPLITUDE_CLUSTER_ID   (required)
#   SPACK_AMPLITUDE_HTTPAPI_URL  (optional, default: https://api2.amplitude.com/2/httpapi)

set -u

curl_bin="$(command -v curl || true)"
if [ -z "${curl_bin}" ]; then
  exit 0
fi

api_key="${SPACK_AMPLITUDE_API_KEY:-}"
cluster_id="${SPACK_AMPLITUDE_CLUSTER_ID:-}"
httpapi_url="${SPACK_AMPLITUDE_HTTPAPI_URL:-https://api2.amplitude.com/2/httpapi}"

if [ -z "${api_key}" ] || [ -z "${cluster_id}" ]; then
  # Missing configuration; skip silently.
  exit 0
fi

mod_fullname="${1:-}"
mod_version_long="${2:-}"
mod_name="${mod_fullname%%/*}"

# Derive short version by trimming the first dash-suffix if present.
mod_version="${mod_version_long%%-*}"
if [ -z "${mod_version}" ]; then
  mod_version="${mod_version_long}"
fi

# Best-effort architecture extraction from the long version string.
# Expect long form: <version>-<arch?>-<hash>, so grab the token after the first '-'.
arch_token="$(printf '%s' "${mod_version_long}" | awk -F- '{print $2}')"
mod_arch=""
case "${arch_token}" in
  x86_64|x86_64_v[0-9]*) mod_arch="${arch_token}" ;;
  aarch64|arm64|ppc64le|powerpc64le) mod_arch="${arch_token}" ;;
  *) mod_arch="" ;;
esac

username="${USER:-$(whoami 2>/dev/null || echo)}"
hostname_fqdn="$(hostname -f 2>/dev/null || hostname 2>/dev/null || echo)"
session_date="$(date +%Y-%m-%d)"
device_id="${username}@${cluster_id}/${session_date}"
user_id="${username}@${cluster_id}"

# Build JSON payload (single event) similar to the post-activate flow
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

max_attempts=3
attempt=1
while (( attempt <= max_attempts )); do
  response_code=$("${curl_bin}" -s -o /dev/null -w "%{http_code}" \
    -X POST "${httpapi_url}" \
    -H 'Content-Type: application/json' \
    -H 'Accept: */*' \
    --data "${json_data}")
  if [ "${response_code}" = "200" ]; then
    exit 0
  fi
  sleep "0.$((attempt * 2))"
  attempt=$((attempt + 1))
done

exit 0
