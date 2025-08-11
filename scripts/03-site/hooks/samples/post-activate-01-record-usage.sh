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
  # Check if required variables are set
  required_vars=(
    "_amplitude_api_key"
    "_amplitude_session_name"
    "_amplitude_user_id"
    "_amplitude_cluster_id"
    "_amplitude_username"
    "_amplitude_hostname"
    "_amplitude_spack_variant"
    "_amplitude_spack_disable_local_config"
    "_amplitude_spack_root"
    "_amplitude_spack_user_cache_path"
    "_amplitude_spack_user_config_path"
  )
  for var in "${required_vars[@]}"; do
    if [ -z "${!var}" ]; then
      echo "Error: $var is not set" >&2
      return 1
    fi
  done

  # Validate curl command exists
  if ! command -v "${_curl_cmd:-curl}" >/dev/null 2>&1; then
    echo "Error: curl command not found" >&2
    return 1
  fi
  _curl_cmd="${_curl_cmd:-curl}"

  # Build slurm properties safely
  _amplitude_slurm_props=""
  if [ -n "$_amplitude_slurm_job_id" ]; then
    _amplitude_slurm_props=", \"slurm_job_id\": \"$(printf '%s' "$_amplitude_slurm_job_id" | jq -R .)\""
  fi

  # Escape JSON values to prevent injection
  json_escape() {
    printf '%s' "$1" | jq -R .
  }

  # Construct JSON payload with escaped values
  payload=$(jq -n --arg device_id "$(json_escape "$_amplitude_session_name")" \
                --arg user_id "$(json_escape "$_amplitude_user_id")" \
                --arg cluster "$(json_escape "$_amplitude_cluster_id")" \
                --arg username "$(json_escape "$_amplitude_username")" \
                --arg hostname "$(json_escape "$_amplitude_hostname")" \
                --arg spack_variant "$(json_escape "$_amplitude_spack_variant")" \
                --arg spack_disable "$(json_escape "$_amplitude_spack_disable_local_config")" \
                --arg spack_root "$(json_escape "$_amplitude_spack_root")" \
                --arg cache_path "$(json_escape "$_amplitude_spack_user_cache_path")" \
                --arg config_path "$(json_escape "$_amplitude_spack_user_config_path")" \
                --arg slurm_props "$_amplitude_slurm_props" \
                '{
                  api_key: $ENV._amplitude_api_key,
                  events: [{
                    device_id: $device_id,
                    user_id: $user_id,
                    event_type: "Activate Spack",
                    event_properties: {
                      cluster: $cluster,
                      username: $username,
                      hostname: $hostname,
                      spack_variant: $spack_variant,
                      spack_disable_local_config: $spack_disable,
                      spack_root: $spack_root,
                      spack_user_cache_path: $cache_path,
                      spack_user_config_path: $config_path
                      + ($slurm_props | fromjson)
                    },
                    user_properties: {
                      cluster: $cluster,
                      username: $username
                    }
                  }]
                }')

  # Execute curl with timeout and retry logic
  max_attempts=3
  attempt=1
  while [ $attempt -le $max_attempts ]; do
    response=$($_curl_cmd -s -w "%{http_code}" -X POST https://api2.amplitude.com/2/httpapi \
      -H 'Content-Type: application/json' \
      -H 'Accept: */*' \
      --data "$payload" \
      --max-time 10 \
      2>/dev/null)
    
    http_code=${response: -3}
    if [ "$http_code" -eq 200 ]; then
      return 0
    fi
    echo "Attempt $attempt failed with HTTP $http_code" >&2
    sleep $((attempt * 2))
    ((attempt++))
  done

  echo "Error: Failed to send event to Amplitude after $max_attempts attempts" >&2
  return 1
}

amplitude_track_spack_activate
unset -f amplitude_track_spack_activate
unset _amplitude_api_key
unset _amplitude_cluster_id
