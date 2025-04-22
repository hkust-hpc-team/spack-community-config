#!/bin/bash

set -exuo pipefail

if [ -z "$SPACK_ROOT" ]; then
  echo "E: SPACK_ROOT not set"
  echo "E: Please set SPACK_ROOT to the root of the Spack installation"
  echo "E: This package should be under $SPACK_ROOT/site"
  exit 1
fi

PYTHON31X_CMD="$(which $(ls /usr/bin/python3.1[012]))"
LS_CMD="ls -l --color=always"
MKDIR_CMD="mkdir -p"
LN_CMD="ln -s -f -n"

if [ -z "$PYTHON31X_CMD" ]; then
  echo "E: Python >=3.10,<3.13 not found"
  exit 1
fi

pushd $SPACK_ROOT

declare _spack_branch="$(git rev-parse --abbrev-ref HEAD)"
echo $_spack_branch >$SPACK_ROOT/.spack-config.variant.log

pdm venv create -f "$(which $(ls /usr/bin/python3.1[012]))"
pdm lock -d -G dev --python ">=3.10" --platform linux --implementation cpython
pdm sync -d -G dev

(
  pushd site
  pdm venv create -f "$(which $(ls /usr/bin/python3.1[012]))"
  pdm lock -d -G dev --python ">=3.10" --platform linux --implementation cpython
  pdm sync -d -G dev
  popd
)

$MKDIR_CMD dist
$LN_CMD ../opt/spack dist/apps
$LN_CMD ../site/scripts/03-site dist/bin
$LN_CMD ../var/spack/bootstrap dist/bootstrap
$LN_CMD ../var/spack/cache dist/cache
$LN_CMD ../site/envs/03-site dist/envs
$LN_CMD /opt/shared/installers dist/installers
$LN_CMD /opt/shared/licenses dist/licenses
$LN_CMD ../share/spack/lmod dist/lmod
$LN_CMD ../share/spack/templates dist/templates
$LS_CMD dist

$MKDIR_CMD var/spack
$LN_CMD ../../site/envs/03-site var/spack/environments
$LS_CMD var/spack

$MKDIR_CMD etc/spack
$LN_CMD ../../site/conf/03-site/concretizer.yaml etc/spack/concretizer.yaml
$LN_CMD ../../site/conf/03-site/config.yaml etc/spack/config.yaml
$LN_CMD ../../site/conf/03-site/linux etc/spack/linux
$LN_CMD /opt/shared/licenses etc/spack/licenses
$LN_CMD ../../site/conf/03-site/mirrors.yaml etc/spack/mirrors.yaml
$LN_CMD ../../site/conf/03-site/modules.yaml etc/spack/modules.yaml
$LN_CMD ../../site/conf/03-site/packages.yaml etc/spack/packages.yaml
$LN_CMD ../../site/conf/03-site/repos.yaml etc/spack/repos.yaml
$LS_CMD etc/spack

set +x

if [ ! -d var/spack/bootstrap ]; then
  export SPACK_DISABLE_LOCAL_CONFIG=1
  export SPACK_USER_CACHE_PATH="$(pwd)/var/spack"
  . share/spack/setup-env.sh
  spack bootstrap now
  unset SPACK_DISABLE_LOCAL_CONFIG
  unset SPACK_USER_CACHE_PATH="$(pwd)/var/spack"
fi

set -x

$LS_CMD dist
