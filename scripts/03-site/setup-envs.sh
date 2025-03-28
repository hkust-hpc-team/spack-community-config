#!/bin/bash

if [ "$(id -u)" -eq 0 ]; then
  echo "E=> This script should not be run as root" >&2
  if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    return 1
  else
    exit 1
  fi
fi

declare _spack_script_path
declare _spack_no_confirm

if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
  _spack_script_path="${BASH_SOURCE[0]}"
else
  _spack_script_path="$0"
  echo -e "\nThis script should be sourced:\n  source $_spack_script_path\n" >&2
  if groups | grep -qE '\b(wheel|itscspod)\b'; then
    echo "Continue in debug mode" >&2
  else
    echo "Nothing to do." >&2
    unset _spack_script_path
    exit 1
  fi
fi

if [ "${1:-}" == "-y" ]; then
  _spack_no_confirm=1
  shift
else
  _spack_no_confirm=0
fi

function get_variant() {
  local script_path=$1
  local variant
  script_path="$(realpath "$script_path")"
  variant="$(echo "$script_path" | grep -oP '(?<=\.spack-)[^/]*(?=/)')"
  echo $variant
}

declare _spack_variant="$(get_variant $_spack_script_path)"
unset -f get_variant
unset _spack_script_path

declare _spack_correspondent="kftse   (kftse@ust.hk)"

function _spack_variant_init() {
  local _spack_confirm
  local _spack_root="/opt/shared/.spack-$_spack_variant"
  local _spack_system_config_path="$_spack_root/site/conf/02-system"
  local _spack_user_config_path="$(realpath --canonicalize-missing ${SPACK_USER_CONFIG_PATH:-$HOME/.spack-$_spack_variant})"
  local _spack_user_cache_path="$(realpath --canonicalize-missing ${SPACK_USER_CACHE_PATH:-$HOME/.spack-$_spack_variant})"

  (
    echo
    echo "You are using non-default spack instances."
    echo "Please do not mix packages installed from different spack instances."
    echo
    echo "This script will unload all other spack instances and modules automatically."
    echo
  ) >&2

  if [ $_spack_no_confirm -eq 1 ]; then
    echo "==> Forcing to activate spack instance [$_spack_variant]" >&2
  else
    read -p "==> Activate spack instance [$_spack_variant]? [y/N] " -r _spack_confirm
    if [[ ! "$_spack_confirm" =~ ^[Yy]$ ]]; then
      return 1
    fi
    (
      echo
      echo "i=> You can use '-y' option to skip this confirmation next time."
      echo
      sleep 3
    ) >&2
  fi

  (
    echo "==> Checking spack config and cache paths"
    echo
    echo "    Shared apps and modules are located at $_spack_root/dist"
  ) >&2

  if [[ "$_spack_user_config_path/" =~ "$HOME/.spack/" ]]; then
    (
      echo "E=> Refuse to use ~/.spack as spack config path"
      echo "    Please unset SPACK_USER_CONFIG_PATH in environment, or contact $_spack_correspondent if you are unsure."
    ) >&2
    return 1
  elif [ -d "${_spack_user_config_path}" ]; then
    if ! (cat "${_spack_user_config_path}/.spack-config.variant" 2>/dev/null | grep -s -q "^$_spack_variant\$"); then
      (
        echo "E=> Found existing spack config at ${_spack_user_config_path}"
        echo "    But the config is not for [$_spack_variant]"
        echo "    Please remove this directory if you want to use this path, or contact $_spack_correspondent if you are unsure."
      ) >&2
      return 1
    fi
  else
    mkdir -p "${_spack_user_config_path}"
    (
      echo "$_spack_variant" >"${_spack_user_config_path}/.spack-config.variant"
      echo "$_spack_variant" >"${_spack_user_config_path}/.spack-cache.variant"
    ) >&2
  fi
  (
    echo "    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~"
    echo "    Your spack config is located at ${_spack_user_config_path}"
  ) >&2

  if [[ "$_spack_user_cache_path/" =~ "$HOME/.spack/" ]]; then
    (
      echo "E=> Refuse to use ~/.spack as spack cache path"
      echo "    Please unset SPACK_USER_CACHE_PATH in environment, or contact $_spack_correspondent if you are unsure."
    ) >&2
    return 1
  elif [ -d "${_spack_user_cache_path}" ]; then
    if ! (cat "${_spack_user_cache_path}/.spack-cache.variant" 2>/dev/null | grep -s -q "^$_spack_variant\$"); then
      (
        echo "E=> Found existing spack cache at ${_spack_user_cache_path}"
        echo "    But the cache is not for [$_spack_variant]"
        echo "    Please remove this directory if you want to use this path, or contact $_spack_correspondent if you are unsure."
      ) >&2
      return 1
    fi
  else
    mkdir -p "${_spack_user_cache_path}"
    echo "$_spack_variant" >"${_spack_user_cache_path}/.spack-cache.variant" >&2
  fi
  (
    echo "    Your spack apps are located at ${_spack_user_cache_path}"
    echo
  ) >&2
  export SPACK_VARIANT="$_spack_variant"
  export SPACK_ROOT="$_spack_root"
  export SPACK_SYSTEM_CONFIG_PATH="$_spack_system_config_path"
  export SPACK_USER_CONFIG_PATH="$_spack_user_config_path"
  export SPACK_USER_CACHE_PATH="$_spack_user_cache_path"
  export TMPDIR="${TMPDIR:-/dev/shm/user-$(id -u)}"
  export TMP="${TMPDIR}"
  mkdir -p "$TMP"
  return $?
}

_spack_variant_init
_spack_variant_init_ret=$?
unset -f _spack_variant_init
unset _spack_variant _spack_no_confirm _spack_root _spack_system_config_path _spack_user_config_path _spack_user_cache_path
if [ $_spack_variant_init_ret -eq 0 ]; then
  unset _spack_variant_init_ret
  echo "==> Setting up spack [$SPACK_VARIANT] environment" >&2
  export MODULEPATH="$(echo $MODULEPATH | tr ':' '\n' | grep -v 'spack' | tr '\n' ':')"
  module use $SPACK_ROOT/dist/lmod/linux-*/Core || true
  source $SPACK_ROOT/share/spack/setup-env.sh
  if [ ! -d "$SPACK_USER_CACHE_PATH/bootstrap" ]; then
    if [ ! -e "$SPACK_USER_CACHE_PATH/config.yaml" ]; then
      echo "config: {}" >"$SPACK_USER_CACHE_PATH/config.yaml"
    fi
    (
      echo "==> First launch: bootstrapping spack [$SPACK_VARIANT]"
      echo "    This may take a few minutes, please wait..."
    ) >&2
    spack bootstrap now
  fi
  (
    echo "==> Spack [$SPACK_VARIANT] environment is ready"
    echo
    echo "    Please kindly send bug reports or suggestions to $_spack_correspondent"
  ) >&2
else
  unset _spack_variant_init_ret
  (
    echo "E=> Failed to setup spack [$SPACK_VARIANT] environment"
    echo "    Please fix the above error and try again, or contact $_spack_correspondent if you are unsure."
  ) >&2
fi
echo >&2
unset _spack_correspondent
