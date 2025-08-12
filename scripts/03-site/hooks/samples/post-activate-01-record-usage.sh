#!/bin/bash

_amplitude_api_key=""
_amplitude_cluster_id=""

function amplitude_track_spack_activate() {
  local _curl_cmd="$(command -v curl)"
  if [ -z "$_curl_cmd" ]; then
    echo "Error: curl command not found" >&2
    return 1
  fi

  local _amplitude_username="$(whoami)"
  local _amplitude_user_id="${_amplitude_username}@${_amplitude_cluster_id}"
  local _amplitude_session_date="$(date +%Y-%m-%d)"
  local _amplitude_session_name="${_amplitude_username}@${_amplitude_cluster_id}/${_amplitude_session_date}"

  local _amplitude_hostname="$(hostname)"
  local _amplitude_spack_user_cache_path="${SPACK_USER_CACHE_PATH:-unknown}"
  local _amplitude_spack_user_config_path="${SPACK_USER_CONFIG_PATH:-unknown}"
  local _amplitude_spack_disable_local_config="${SPACK_DISABLE_LOCAL_CONFIG:-0}"
  local _amplitude_spack_root="${SPACK_ROOT:-unknown}"
  local _amplitude_spack_variant="${SPACK_VARIANT:-unknown}"
  local _amplitude_slurm_job_id="${SLURM_JOB_ID:-}"

  if [ -z "${_amplitude_api_key}" ]; then
    echo "W: Amplitude API key is not set. Skipping usage tracking." >&2
    return 0
  fi

  if [ -z "${_amplitude_cluster_id}" ]; then
    echo "W: Amplitude cluster ID is not set. Skipping usage tracking." >&2
    return 0
  fi

  local _amplitude_slurm_props
  if [ -n "${_amplitude_slurm_job_id}" ]; then
    _amplitude_slurm_props=", \"slurm_job_id\": \"${_amplitude_slurm_job_id}\""
  fi

  local json_data=$(printf '{
      "api_key": "%s",
      "events": [{
        "device_id": "%s",
        "user_id": "%s",
        "event_type": "Activate Spack",
        "event_properties": {
          "cluster": "%s",
          "username": "%s",
          "hostname": "%s",
          "spack_variant": "%s",
          "spack_disable_local_config": "%s",
          "spack_root": "%s",
          "spack_user_cache_path": "%s",
          "spack_user_config_path": "%s"
          %s
        },
        "user_properties": {
          "cluster": "%s",
          "username": "%s"
        }
      }]
    }' "${_amplitude_api_key}" "${_amplitude_session_name}" "${_amplitude_user_id}" "${_amplitude_cluster_id}" "${_amplitude_username}" "${_amplitude_hostname}" "${_amplitude_spack_variant}" "${_amplitude_spack_disable_local_config}" "${_amplitude_spack_root}" "${_amplitude_spack_user_cache_path}" "${_amplitude_spack_user_config_path}" "${_amplitude_slurm_props}" "${_amplitude_cluster_id}" "${_amplitude_username}")

  local max_attempts=3
  local attempt=1

  while ((attempt <= max_attempts)); do
    response_code=$("${_curl_cmd}" -s -o /dev/null -w "%{http_code}" \
      -X POST https://api2.amplitude.com/2/httpapi \
      -H 'Content-Type: application/json' \
      -H 'Accept: */*' \
      --data "${json_data}")
    if [ "$response_code" = "200" ]; then
      return 0
    fi
    sleep "0.$((attempt * 2))"
    ((attempt++))
  done
  return 1
}

amplitude_track_spack_activate
unset -f amplitude_track_spack_activate
unset _amplitude_api_key
unset _amplitude_cluster_id
