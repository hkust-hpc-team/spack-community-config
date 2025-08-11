#!/bin/bash

_amplitude_api_key=""
_amplitude_cluster_id=""

function amplitude_track_spack_activate(){
  local _curl_cmd="$(command -v curl) -s"

  # Create session name from cluster, user, and date
  local _amplitude_username=$(whoami)
  local _amplitude_user_id="${_amplitude_username}@${_amplitude_cluster_id}"
  local _amplitude_session_date=$(date +%Y-%m-%d)
  local _amplitude_session_name="${_amplitude_username}@${_amplitude_cluster_id}/${_amplitude_session_date}"

  # Collect system information
  local _amplitude_hostname=$(hostname)
  local _amplitude_spack_user_cache_path=${SPACK_USER_CACHE_PATH:-"unknown"}
  local _amplitude_spack_user_config_path=${SPACK_USER_CONFIG_PATH:-"unknown"}
  local _amplitude_spack_disable_local_config=${SPACK_DISABLE_LOCAL_CONFIG:-"0"}
  local _amplitude_spack_root=${SPACK_ROOT:-"unknown"}
  local _amplitude_spack_variant=${SPACK_VARIANT:-"unknown"}
  local _amplitude_slurm_job_id=${SLURM_JOB_ID:-""}

  if [ -z "$_amplitude_api_key" ]; then
    echo "W: Amplitude API key is not set. Skipping usage tracking." >&2
    return 0
  fi

  if [ -z "$_amplitude_cluster_id" ]; then
    echo "W: Amplitude cluster ID is not set. Skipping usage tracking." >&2
    return 0
  fi
  local _amplitude_slurm_props
  if [ -z "$_amplitude_slurm_job_id" ]; then
    _amplitude_slurm_props=""
  else
    _amplitude_slurm_props=", \"slurm_job_id\": \"${_amplitude_slurm_job_id}\""
  fi

  $_curl_cmd -X POST https://api2.amplitude.com/2/httpapi \
    -H 'Content-Type: application/json' \
    -H 'Accept: */*' \
    --data "{
      \"api_key\": \"${_amplitude_api_key}\",
      \"events\": [{
        \"device_id\": \"${_amplitude_session_name}\",
        \"user_id\": \"${_amplitude_user_id}\",
        \"event_type\": \"Activate Spack\",
        \"event_properties\": {
          \"cluster\": \"${_amplitude_cluster_id}\",
          \"username\": \"${_amplitude_username}\",
          \"hostname\": \"${_amplitude_hostname}\",
          \"spack_variant\": \"${_amplitude_spack_variant}\",
          \"spack_disable_local_config\": \"${_amplitude_spack_disable_local_config}\",
          \"spack_root\": \"${_amplitude_spack_root}\",
          \"spack_user_cache_path\": \"${_amplitude_spack_user_cache_path}\",
          \"spack_user_config_path\": \"${_amplitude_spack_user_config_path}\"
          ${_amplitude_slurm_props}
        },
        \"user_properties\": {
          \"cluster\": \"${_amplitude_cluster_id}\",
          \"username\": \"${_amplitude_username}\",
        }
      }]
    }" >/dev/null
}

amplitude_track_spack_activate
unset -f amplitude_track_spack_activate
unset _amplitude_api_key
unset _amplitude_cluster_id
