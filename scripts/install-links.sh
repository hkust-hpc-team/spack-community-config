#!/bin/bash

if [ "$DEBUG" == "1" ]; then
  set -x
fi

set -euo pipefail

# TODO: Modify these variables to your needs
declare ENABLE_DEVELOPMENT="1"
# declare SPACK_LICENSES_PATH=""
# declare SPACK_SOURCE_CACHE_PATH=""

if [ "$USER" == "root" ]; then
  echo "E: Do not run this script as root"
  exit 1
fi

declare python3_cmd="$(which $(ls /usr/bin/python3.1[0123]))"
if [ -z "$python3_cmd" ]; then
  echo "W: Python >=3.10,<=3.13 not found"
  echo "W: Trying python 3.9 (experimental)"
  python3_cmd="$(which $(ls /usr/bin/python3.9))"
fi
declare git_cmd="$(which git)"
declare ls_cmd="ls -l --color=always"
declare ln_cmd="ln -sfn"
declare cp_cmd="cp -f"
declare mkdir_cmd="mkdir -p"

if [ -z "$python3_cmd" ]; then
  echo "E: Python >=3.9,<=3.13 not found"
  exit 1
fi
if [ -z "$git_cmd" ]; then
  echo "E: Git not found"
  exit 1
fi
if [ "$ENABLE_DEVELOPMENT" == "1" ]; then
  declare pdm_cmd="$(which pdm)"
  if [ -z "$pdm_cmd" ]; then
    echo "E: Development dependency PDM not found"
    exit 1
  fi
fi

if [ -z "${SPACK_ROOT:-}" ]; then
  echo "W: This repo should be under \$SPACK_ROOT/site"
  declare _spack_root="$(realpath $(dirname $0)/../..)"
  read -p "Please confirm \$SPACK_ROOT: [$_spack_root] (y/n) " answer
  if [ "$answer" == "y" ]; then
    export SPACK_ROOT="$_spack_root"
  else
    echo "E: Please set SPACK_ROOT to the root of the Spack installation"
    echo "E: SPACK_ROOT not set"
    exit 1
  fi
fi

export SPACK_LICENSES_PATH="${SPACK_LICENSES_PATH:-$SPACK_ROOT/opt/licenses}"
export SPACK_SOURCE_CACHE_PATH="${SPACK_SOURCE_CACHE_PATH:-$SPACK_ROOT/opt/installers}"

echo
echo "Installation summary: (You can change them in $SPACK_ROOT/site/scripts/install-links.sh)"
echo "  Package detection:"
echo "    Python: $python3_cmd"
echo "    Git: $git_cmd"
if [[ "$ENABLE_DEVELOPMENT" == "1" ]]; then
  echo "    PDM: $pdm_cmd"
else
  echo "    PDM: Not required"
fi
echo "  Configs:"
echo "   SPACK_ROOT: $SPACK_ROOT"
echo "   SPACK_LICENSES_PATH: $SPACK_LICENSES_PATH"
echo "   SPACK_SOURCE_CACHE_PATH: $SPACK_SOURCE_CACHE_PATH"
echo "   ENABLE_DEVELOPMENT: $ENABLE_DEVELOPMENT"
echo

read -p "Please confirm to start installation: [y/n] " answer
if [ "$answer" != "y" ]; then
  echo "E: Installation aborted"
  exit 1
fi
echo "==> Starting installation"

pushd $SPACK_ROOT

declare _spack_branch="$(git rev-parse --abbrev-ref HEAD)"
echo "$_spack_branch" > "$SPACK_ROOT/.spack-config.variant.log"
echo "==> Spack branch: $_spack_branch"

$git_cmd -C site submodule update --init --recursive --force --remote

if [ "$ENABLE_DEVELOPMENT" == "1" ]; then
  $pdm_cmd venv create -f $python3_cmd
  $pdm_cmd lock -d -G dev --python ">=3.9,<=3.13" --platform linux --implementation cpython
  $pdm_cmd sync -d -G dev

  (
    pushd site
    $pdm_cmd venv create -f $python3_cmd
    $pdm_cmd lock -d -G dev --python ">=3.9,<=3.13" --platform linux --implementation cpython
    $pdm_cmd sync -d -G dev
    popd
  )
fi

$mkdir_cmd dist
$mkdir_cmd $SPACK_SOURCE_CACHE_PATH $SPACK_LICENSES_PATH

$ln_cmd $SPACK_ROOT/site/envs/03-site var/spack/environments
echo "==> Configured directory: var/spack"
$ls_cmd var/spack

$ln_cmd $SPACK_ROOT/opt/spack dist/apps
$ln_cmd $SPACK_ROOT/site/scripts/03-site dist/bin
$ln_cmd $SPACK_ROOT/var/spack/bootstrap dist/bootstrap
$ln_cmd $SPACK_ROOT/var/spack/cache dist/cache
$ln_cmd $SPACK_ROOT/site/envs/03-site dist/envs
$ln_cmd $SPACK_SOURCE_CACHE_PATH dist/installers
$ln_cmd $SPACK_LICENSES_PATH dist/licenses
$ln_cmd $SPACK_ROOT/share/spack/lmod dist/lmod
$ln_cmd $SPACK_ROOT/share/spack/templates dist/templates
echo "==> Configured directory: dist"
$ls_cmd dist

$mkdir_cmd etc/spack
$ln_cmd $SPACK_ROOT/site/conf/03-site/concretizer.yaml etc/spack/concretizer.yaml
$ln_cmd $SPACK_ROOT/site/conf/03-site/config.yaml etc/spack/config.yaml
$ln_cmd $SPACK_ROOT/site/conf/03-site/linux etc/spack/linux

for policy in gui-external mpi-external os-external; do
  $cp_cmd "$SPACK_ROOT/etc/spack/linux/package-policies/externals/${policy}.sample.yaml" "$SPACK_ROOT/etc/spack/linux/package-policies/externals/${policy}.yaml"
done

$ln_cmd $SPACK_LICENSES_PATH etc/spack/licenses
$ln_cmd $SPACK_ROOT/site/conf/03-site/mirrors.yaml etc/spack/mirrors.yaml
$ln_cmd $SPACK_ROOT/site/conf/03-site/modules.yaml etc/spack/modules.yaml
$ln_cmd $SPACK_ROOT/site/conf/03-site/repos.yaml etc/spack/repos.yaml

echo "==> Configured directory: etc/spack"
$ls_cmd etc/spack

set +x

if [ ! -d var/spack/bootstrap ]; then
  export SPACK_DISABLE_LOCAL_CONFIG=1
  export SPACK_USER_CACHE_PATH="$(pwd)/var/spack"
  . share/spack/setup-env.sh
  spack bootstrap now
  unset SPACK_DISABLE_LOCAL_CONFIG
  unset SPACK_USER_CACHE_PATH="$(pwd)/var/spack"
fi

$ls_cmd dist
echo "==> Installation completed successfully"
