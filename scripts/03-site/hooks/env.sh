#!/usr/bin/env bash

# Centralized environment for hook scripts.
# Do NOT export these; hooks source this file and keep values local to their process.

# Fill these in for your site (or leave empty to disable Amplitude posting)
_amplitude_api_key=""
_amplitude_cluster_id=""
_amplitude_httpapi_url="https://api2.amplitude.com/2/httpapi"

# Debugging: set SPACK_HOOK_DEBUG=1 to see verbose logs from hooks