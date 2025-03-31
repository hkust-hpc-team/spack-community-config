#!/bin/bash

set -uo pipefail

export BASHRCSOURCED="Y"
. ~/.bashrc

declare variant=${SPACK_VARIANT:-$1}

function spack::dist::reset_cache() {
  fd --one-file-system -uu0a "__pycache__" . | xargs -r0 -P $(nproc) -n 64 rm -rf
  yes | spack clean --all
}
function spack::dist::reset_config() {
  cd $SPACK_ROOT/etc/spack || return 1
  rm -f *.yaml linux licenses
  ln -s ../../site/conf/03-site/concretizer.yaml concretizer.yaml
  ln -s ../../site/conf/03-site/config.yaml config.yaml
  ln -s /opt/shared/licenses licenses
  ln -s ../../site/conf/03-site/linux linux
  ln -s ../../site/conf/03-site/modules.yaml modules.yaml
  ln -s ../../site/conf/03-site/packages.yaml packages.yaml
}

function spack::dist::reset_dist() {
  cd $SPACK_ROOT || return 1
  rm dist -rf
  mkdir -p dist
  cd dist || return 1
  ln -s ../opt/spack apps
  ln -s ../site/scripts/03-site bin
  ln -s ../site/envs/03-site envs
  ln -s /opt/shared/licenses licenses
  ln -s ../share/spack/lmod lmod
  ln -s ../site/templates/03-site templates
}

function spack::dist::reset_env() {
  cd $SPACK_ROOT/site || return 1
  rm -rf envs/03-site/*/{spack.lock,.spack-env}
}

function spack::dist::reset_apps() {
  cd $SPACK_ROOT/opt/spack || return 1
  fd --one-file-system -uu0a . . | xargs -r0 -P $(nproc) -n 64 rm -rf
}

function spack::dist::reset_lmod() {
  cd $SPACK_ROOT/share/spack/lmod || return 1
  fd --one-file-system -uu0a . . | xargs -r0 -P $(nproc) -n 64 rm -rf
}

function spack::dist::reset() {
  echo "I=> Cleaning spack cache"
  echo "I=> Resetting spack env"
  spack::dist::reset_env
  echo "I=> Resetting spack apps"
  spack::dist::reset_apps
  echo "I=> Resetting spack lmod"
  spack::dist::reset_lmod
  echo "I=> Resetting spack config"
  spack::dist::reset_config
  echo "I=> Resetting spack dist folder"
  spack::dist::reset_dist
  cd $SPACK_ROOT || return 1
  spack::global::unload_variant
  spack::global::load_variant $variant
  echo "I=> Bootstrap spack dist"
  spack bootstrap now
  echo "I=> Refreshing lmod"
  spack lmod refresh -y --delete-tree
}

if [ -z "$variant" ]; then
  echo "E=> SPACK_VARIANT is not set"
  exit 1
fi
unset SPACK_DISABLE_LOCAL_CONFIG
spack::global::unload_variant
spack::global::load_variant $variant

echo "I=> Resetting spack instance"
echo "    SPACK_VARIANT: $variant"
echo "    SPACK_ROOT: $SPACK_ROOT"

read -p "I=> Continue? [y/N] " -r
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
  return 1
fi

export SPACK_DISABLE_LOCAL_CONFIG="1"
spack::global::unload_variant
spack::global::load_variant $variant
spack::dist::reset
