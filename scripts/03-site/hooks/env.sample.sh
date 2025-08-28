#!/usr/bin/env bash
# Sample env for Amplitude hooks. Copy this to env.sh and fill values to enable.

# Do NOT export these variables; hooks source this file and keep them local to their process.
# Fill these values for your site. Leave empty to disable Amplitude posting.
_amplitude_api_key=""
_amplitude_cluster_id=""
_amplitude_httpapi_url="https://api2.amplitude.com/2/httpapi"

# Debugging: set SPACK_HOOK_DEBUG=1 in the environment to enable verbose logs from hooks
