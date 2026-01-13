# Spack Community Config

A curated, opinionated configuration for building HPC software stacks with [Spack](https://github.com/spack/spack), designed for reproducible deployments and easy customization.

## Why Use This Configuration?

Building a complete HPC software stack from scratch is complex and time-consuming. This repository provides battle-tested defaults that solve common challenges:

- **🎯 Deterministic Builds**: Reproducible package versions and configurations across deployments
- **⚙️ Sensible Defaults**: Pre-configured compilers, MPI implementations, and common libraries
- **🔗 Library Interoperability**: Ensures compatibility between different compilers (GCC, Intel oneAPI, AOCC, NVHPC) and MPI libraries (OpenMPI, Intel MPI)
- **🧩 Modular Environments**: Composable environment definitions that users can extend and customize for their specific needs
- **📊 Optional Analytics**: Track module usage patterns to inform package development priorities and identify deprecated software

## Overview

This configuration works with two synchronized Git repositories:

- **`$SPACK_ROOT`**: Main Spack instance ([hkust-hpc-team/spack](https://github.com/hkust-hpc-team/spack))
- **`$SPACK_ROOT/site`**: Community configuration (this repository)

The branch name serves as a unique identifier, allowing multiple Spack instances to coexist independently on the same system.

## Key Features

### Modular Environment Architecture

The configuration provides ~50 pre-defined environments organized by build order:

- **`0000-spack-gcc`**: Bootstrap GCC toolchain (independent of OS compiler)
- **`1000-*`**: Core packages and additional compiler suites (Intel oneAPI, AOCC, NVHPC)
- **`2000-*`**: MPI implementations (OpenMPI, Intel MPI) for various compilers
- **`3000-*`**: Math and I/O libraries (FFTW, MKL, NetCDF) with compiler/MPI combinations
- **`4001-*`**: Scientific applications (LAMMPS, MPAS, OpenFOAM)
- **`5000-*`**: Developer tools, language runtimes (Python, R, MATLAB), and utilities

Each environment is self-contained and can be built independently or customized for site-specific needs.

### Cross-Compiler & MPI Interoperability

The configuration ensures that libraries built with different compilers can coexist without conflicts:

```text
# Example: FFTW built with multiple compiler/MPI combinations
3000-fftw-aocc-openmpi/      # AMD AOCC + OpenMPI
3000-fftw-oneapi-impi/       # Intel oneAPI + Intel MPI
3000-fftw-oneapi-openmpi/    # Intel oneAPI + OpenMPI
```

This allows users to switch between toolchains while maintaining consistent library interfaces.

### OS-Agnostic Bootstrap

The configuration works on any Linux distribution with a basic GCC toolchain:

- **Tested on**: Ubuntu 22.04, RHEL 9.5-9.7, Rocky Linux 9.3-9.5, Fedora 41
- **Initial requirements**: gcc, g++, gfortran (OS packages)
- **After bootstrap**: Independent of OS compiler

## Quick Start

### Prerequisites

Install basic compiler toolchain:

```bash
# RHEL/Rocky/Fedora
sudo dnf install gcc gcc-c++ gcc-gfortran

# Ubuntu/Debian
sudo apt install gcc g++ gfortran
```

### Installation

```bash
# Clone main Spack repository
git clone -b edge https://github.com/hkust-hpc-team/spack.git /opt/shared/spack-2025
cd /opt/shared/spack-2025

# Clone this configuration repository
git clone -b edge https://github.com/hkust-hpc-team/spack-community-config.git site

# Link configurations and bootstrap
export SPACK_ROOT=$(pwd)
cd site/scripts
./install-links.sh

# Activate Spack (shared instance)
export CI=1
export SPACK_DISABLE_LOCAL_CONFIG=1
source $SPACK_ROOT/dist/setup-env.sh -y

# Build bootstrap GCC toolchain (~20-30 minutes)
cd $SPACK_ROOT/dist/envs
make build@0000-spack-gcc

# Register new compiler
spack compiler find opt/spack/linux-*/gcc-*/gcc-11.5.0-*/
vi etc/spack/linux/compilers.yaml  # Change gcc@=11.5.0 to gcc@=11.5.0.spack
```

### Build Additional Environments

```bash
# Intel oneAPI compiler suite
make build@1001-cc-intel-oneapi

# Register all MPI-capable compilers (aocc, intel-oneapi)
make compiler-find-mpi.build

# Intel MPI with oneAPI
make build@2000-oneapi-impi

# LAMMPS with Intel oneAPI + Intel MPI
make build@4001-lammps-oneapi-impi
```

**Note**: After building `1001-cc-*` compiler environments, use `make compiler-find-mpi.build` (for AOCC/Intel) or `make compiler-find-all.build` (for all compilers including NVHPC) to register them. These targets handle compiler paths automatically, including special cases like Intel oneAPI which uses non-standard installation layouts.

## Detailed Setup Guide

### Repository Setup

#### 1. Prepare the Main Spack Repository

Choose a location for your Spack installation (e.g., `/opt/shared/spack-2025`):

```shell
# Create the installation directory
mkdir -p /opt/shared/spack-2025
cd /opt/shared/spack-2025

# Clone the desired branch (e.g., 'edge' - the semi-stable branch)
git clone -b edge https://github.com/hkust-hpc-team/spack.git .

# Or, if you already have a Spack repository elsewhere, copy its .git directory
# cp /path/to/existing/spack/.git/ ./.git/ -dr
# git reset --hard

# Verify the branch (this will be your instance identifier)
git branch -a
```

**Note**: The branch name (e.g., `edge`, `v2025`) will be used as a unique identifier for this Spack instance, keeping environments separate.

#### 2. Prepare the Community Configuration Repository

```shell
# Create the site directory
mkdir -p site
cd site

# Clone the same branch from the community config repository
git clone -b edge https://github.com/hkust-hpc-team/spack-community-config.git .

# Or copy from existing repository
# cp /path/to/existing/site/.git/ ./.git/ -dr
# git reset --hard

# Verify branch alignment
git log --oneline | head -5
cd ..
```

#### 3. Create a Branch Identifier (Optional)

If you want to create a new local branch identifier:

```shell
cd /opt/shared/spack-2025
git checkout -b v2025

cd site
git checkout -b v2025
cd ..
```

### Configuration and Linking

#### 1. Run the Installation Link Script

Set the `SPACK_ROOT` environment variable and run the linking script:

```shell
export SPACK_ROOT=$(pwd)
cd site/scripts
./install-links.sh
```

The script will display configuration paths:

```text
Installation summary:
  Package detection:
    Python: /usr/bin/python3.11
    Git: /usr/bin/git
    PDM: Not required
  Configs:
   SPACK_ROOT: /opt/shared/spack-2025
   SPACK_LICENSES_PATH: /opt/shared/licenses
   SPACK_SOURCE_CACHE_PATH: /opt/shared/installers
   ENABLE_DEVELOPMENT: 0

Please confirm to start installation: [y/n]
```

**Important**: Note the paths for `SPACK_LICENSES_PATH` and `SPACK_SOURCE_CACHE_PATH`. You may need to create these directories or adjust them in the script to fit your site's requirements.

Type `y` to proceed. The script will:

- Link site configurations into `$SPACK_ROOT/etc/spack`
- Link environment definitions into `$SPACK_ROOT/var/spack/environments`
- Create symbolic links in `$SPACK_ROOT/dist`
- Bootstrap Spack's internal dependencies (clingo, patchelf, etc.)

#### 2. Review Site Configuration

Before building packages, review and customize the configuration files for your site:

```shell
cd $SPACK_ROOT

# Review external package detection
ls etc/spack/linux/package-policies/externals/
# Edit as needed: gui-external.yaml, mpi-external.yaml, os-external.yaml

# Review package keys (e.g., licensed software)
ls etc/spack/linux/package-keys/
# Edit as needed: matlab.yaml, etc.

# Review and configure mirrors (source/binary cache)
cat site/conf/03-site/mirrors.yaml
# Edit as needed to add your site's mirror URLs

# Review compiler and OS settings
cat site/envs/0000-spack-gcc/spack.yaml
```

**Important**: Update `0000-spack-gcc/spack.yaml` to match your OS and compiler version:

```yaml
compilers:
  - compiler:
      spec: gcc@=11.4.1.os  # Update this to match your OS GCC version
      paths:
        cc: /usr/bin/gcc
        cxx: /usr/bin/g++
        f77: /usr/bin/gfortran
        fc: /usr/bin/gfortran
      operating_system: rocky9  # Update to match your OS
```

### Activating the Spack Instance

#### For Shared Instance (System-wide)

```shell
export CI=1
export SPACK_DISABLE_LOCAL_CONFIG=1
source $SPACK_ROOT/dist/setup-env.sh -y
```

- `CI=1`: Disables analytics during CI/automated builds
- `SPACK_DISABLE_LOCAL_CONFIG=1`: Uses only site configuration, ignoring user-specific configs
- `-y`: Skips confirmation prompt

#### For User Instance (Personal)

```shell
source $SPACK_ROOT/dist/setup-env.sh -y
```

Omitting `SPACK_DISABLE_LOCAL_CONFIG` allows users to maintain their own configurations in `~/.spack-<branch>`.

### Building the Initial Compiler Toolchain

#### 1. Review Available Environments

```shell
cd $SPACK_ROOT/dist/envs
ls
```

Available environments include:

- `0000-spack-gcc`: Bootstrap compiler toolchain (build first)
- `1000-core-packages`: Core utilities and tools
- `1001-cc-*`: Additional compiler suites (Intel oneAPI, AOCC, NVHPC, etc.)
- `2000-*`: MPI libraries
- `3000-*`: Math libraries (FFTW, MKL, NetCDF)
- `4001-*`: Scientific applications (LAMMPS, MPAS, OpenFOAM)
- `5000-*`: Developer tools, VCS tools, cloud tools
- `5001-*`: Language runtimes (Python, R, MATLAB, etc.)

#### 2. Review the Bootstrap Environment Configuration

```shell
cd 0000-spack-gcc
cat spack.yaml
```

This displays the environment configuration. Key sections to verify:

```yaml
spack:
  compilers:
    - compiler:
        spec: gcc@=11.4.1.os  # Match your OS GCC version
        paths:
          cc: /usr/bin/gcc
          cxx: /usr/bin/g++
          f77: /usr/bin/gfortran
          fc: /usr/bin/gfortran
        operating_system: rocky9  # Match your OS
  specs:
    - "gcc@11.5.0 +binutils+bootstrap+graphite+piclibs+profiled languages=c,c++,fortran,lto ^binutils@2.36:"
```

#### 3. Build the Compiler Toolchain

Use the makefile to build the environment:

```shell
cd $SPACK_ROOT/dist/envs
make build@0000-spack-gcc
```

This will install 33 packages including the new GCC toolchain. The build process:

1. Detects external glibc from OS
2. Builds gcc-runtime from the OS compiler
3. Builds essential build tools (gmake, autoconf-archive, diffutils, zlib-ng, etc.)
4. Builds compression libraries (xz, zstd, bzip2, pigz)
5. Builds text utilities (ncurses, readline, gettext, m4)
6. Builds Perl with required database support (gdbm, berkeley-db)
7. Builds GMP, MPFR, MPC for GCC dependencies
8. Builds binutils
9. Finally builds the new GCC 11.5.0 toolchain (~18 minutes for GCC build)

**Sample output (abbreviated):**

```text
==> Installing gcc-runtime-11.4.1.os [2/33]
==> Installing gmake-4.4.1 [3/33]
==> Installing diffutils-3.10, autoconf-archive-2023.02.20, zlib-ng-2.2.3 [4/33]
...
==> Installing gcc-11.5.0 [33/33]
==> gcc: Executing phase: 'build'
==> gcc: Successfully installed gcc-11.5.0
  Build: 17m 11.11s.  Total: 17m 50.04s
[0000-spack-gcc] build completed
```

**Total build time:** Approximately 20-30 minutes depending on hardware.

#### 4. Register the New Compiler

After the build completes, register the new GCC compiler with Spack:

```shell
cd $SPACK_ROOT
spack compiler find opt/spack/linux-rocky9-x86_64_v4/gcc-11.4.1.os/gcc-11.5.0-*/
```

Output:

```text
==> Added 1 new compiler to /opt/shared/spack-2025/etc/spack/linux/compilers.yaml
    gcc@11.5.0
==> Compilers are defined in the following files:
    /opt/shared/spack-2025/etc/spack/linux/compilers.yaml
```

#### 5. Rename Bootstrap GCC with Unique Identifier

**Important**: The bootstrap GCC compiler should be given a unique identifier to distinguish it from other GCC installations. Edit the compiler configuration:

```shell
vi etc/spack/linux/compilers.yaml
# Change the spec from gcc@=11.5.0 to gcc@=11.5.0.spack
```

Before:

```yaml
compilers:
  - compiler:
      spec: gcc@=11.5.0
```

After:

```yaml
compilers:
  - compiler:
      spec: gcc@=11.5.0.spack
```

**Note**: This renaming is **only required for the bootstrap GCC**. Other compilers installed later do not need this special identifier.

Verify the change:

```shell
spack compiler list
```

Output:

```text
==> Available compilers
-- gcc rocky9-x86_64 --------------------------------------------
gcc@11.5.0.spack
```

Complete compiler configuration:

```yaml
compilers:
  - compiler:
      spec: gcc@=11.5.0.spack
      paths:
        cc: /opt/shared/spack-2025/opt/spack/linux-rocky9-x86_64_v4/gcc-11.4.1.os/gcc-11.5.0-osvvfdv4yevcqsitdlqp6arlxlnyecsl/bin/gcc
        cxx: /opt/shared/spack-2025/opt/spack/linux-rocky9-x86_64_v4/gcc-11.4.1.os/gcc-11.5.0-osvvfdv4yevcqsitdlqp6arlxlnyecsl/bin/g++
        f77: /opt/shared/spack-2025/opt/spack/linux-rocky9-x86_64_v4/gcc-11.4.1.os/gcc-11.5.0-osvvfdv4yevcqsitdlqp6arlxlnyecsl/bin/gfortran
        fc: /opt/shared/spack-2025/opt/spack/linux-rocky9-x86_64_v4/gcc-11.4.1.os/gcc-11.5.0-osvvfdv4yevcqsitdlqp6arlxlnyecsl/bin/gfortran
      flags: {}
      operating_system: rocky9
      target: x86_64
      modules: []
      environment: {}
      extra_rpaths: []
```

#### 6. Building Additional Compilers

After the bootstrap GCC is registered, you can build additional compiler suites:

```shell
cd $SPACK_ROOT/dist/envs

# Build Intel oneAPI compilers
make build@1001-cc-intel-oneapi

# Build AMD AOCC compilers
make build@1001-cc-aocc

# Build NVIDIA HPC SDK (optional)
make build@1001-cc-nvhpc
```

**Register Compilers**: After building compiler environments, use the automated makefile targets:

```shell
# Register MPI-capable compilers (AOCC, Intel oneAPI)
make compiler-find-mpi.build

# OR register all compilers including NVHPC
make compiler-find-all.build
```

These targets automatically handle compiler registration, including special cases:
- **Intel oneAPI**: Compilers are in `compiler/2024.x/linux/`, not `bin/`
- **NVHPC**: Compilers are in `Linux_x86_64/24.x/compilers/`
- **AOCC/GCC**: Standard `bin/` layout

Verify registered compilers:

```shell
spack compiler list
```

Example output:

```text
==> Available compilers
-- aocc rocky9-x86_64 -------------------------------------------
aocc@5.0.0  aocc@4.2.0
-- gcc rocky9-x86_64 --------------------------------------------
gcc@11.5.0.spack
-- oneapi rocky9-x86_64 -----------------------------------------
oneapi@2024.2.1
```

**Manual Registration** (if needed): For custom compiler installations, you can manually register:

```shell
# Intel oneAPI requires special path
spack compiler find opt/spack/linux-*/gcc-*/intel-oneapi-compilers-*/compiler/2*/linux

# Standard compilers
spack compiler find opt/spack/linux-*/gcc-*/aocc-*/
```

### Configuring Module Usage Analytics (Optional)

The setup includes optional Amplitude integration for tracking Lmod module usage statistics.

#### 1. Understanding the Analytics Hooks

Analytics are implemented through Spack hooks located in `$SPACK_ROOT/dist/bin/hooks/`:

- `pre-activate.sh`: Runs before environment activation
- `post-activate.sh`: Runs after environment activation  
- `post-module-load.sh`: Records module load events
- `post-activate-01-record-usage.sh`: Sends usage data to Amplitude

#### 2. Configure Analytics Credentials

Create or edit the configuration file:

```shell
cd $SPACK_ROOT/dist/bin/hooks
cp env.sample.sh env.sh
vi env.sh  # or nano, etc.
```

Set the following variables in `env.sh`:

```bash
# Do NOT export these variables; hooks source this file and keep them local to their process.
# Fill these values for your site. Leave empty to disable Amplitude posting.
_amplitude_api_key="your-amplitude-api-key-here"
_amplitude_cluster_id="your-cluster-identifier"
_amplitude_httpapi_url="https://api2.amplitude.com/2/httpapi"
_spack_module_default_arch="x86_64_v4"
```

**Important notes:**

- Do NOT export these variables - hooks will source this file internally
- Leave `_amplitude_api_key` empty to disable analytics
- These values are kept local to the hook processes

#### 3. Testing and Debugging Analytics

##### Disable Analytics During CI/Testing

```shell
export CI=1
```

Setting `CI=1` disables analytics to avoid polluting production data during continuous integration or testing.

##### Enable Debug Output for Hooks

```shell
export SPACK_HOOK_DEBUG=1
```

This enables verbose logging to see the analytics hooks running in real-time.

##### Example Debug Output

```text
[HOOK DEBUG] post-module-load: Module gcc/11.5.0 loaded
[HOOK DEBUG] Sending analytics event to Amplitude...
[HOOK DEBUG] Event recorded: {"event_type": "module_load", "module": "gcc/11.5.0"}
```

## Configuration Structure

This repository contains:

- **`conf/`**: Spack configuration files
  - `02-system/`: System-level configurations (config.yaml, modules.yaml, upstreams.yaml)
  - `03-site/`: Site-specific configurations (compilers, packages, mirrors, repos)
    - `linux/`: Linux-specific compiler and package configurations
    - `package-keys/`: Licensed software keys (e.g., MATLAB)
    - `package-policies/externals/`: External package detection policies

- **`envs/`**: Environment definitions organized by build order
  - `03-site/`: Main environment definitions
  - `04-tests/`: Test environments for compiler validation

- **`repos/meta-pkgs/`**: Custom Spack package repository for meta-packages

- **`scripts/`**: Installation and setup scripts
  - `install-links.sh`: Main installation script
  - `03-site/`: Environment setup scripts and hooks

- **`templates/modules/`**: Lmod module file templates

## Customization

### Extending Environments

Each environment is defined in a `spack.yaml` file. To customize:

```bash
cd $SPACK_ROOT/var/spack/environments/<env-name>
vi spack.yaml  # Edit specifications, compilers, or variants

# Rebuild the environment
cd $SPACK_ROOT/dist/envs
make build@<env-name>
```

### Adding New Environments

Create a new directory under `envs/03-site/` with a `spack.yaml` file:

```yaml
spack:
  specs:
    - your-package@version %compiler-spec ^dependency-spec
  view: true
  concretizer:
    unify: true
```

### Site-Specific Package Configuration

Edit package preferences in [conf/03-site/linux/packages.yaml](conf/03-site/linux/packages.yaml):

```yaml
packages:
  your-package:
    version: [preferred-version]
    variants: +feature1 ~feature2
    compiler: [preferred-compiler]
```

## Environment Variables

| Variable                       | Purpose                                |
| ------------------------------ | -------------------------------------- |
| `SPACK_ROOT`                   | Path to Spack installation             |
| `SPACK_DISABLE_LOCAL_CONFIG=1` | Use only site config (shared instance) |
| `CI=1`                         | Disable analytics during CI/testing    |
| `SPACK_HOOK_DEBUG=1`           | Enable verbose hook logging            |
| `SPACK_LICENSES_PATH`          | Path to licensed software keys         |
| `SPACK_SOURCE_CACHE_PATH`      | Path to source tarballs cache          |

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Test your changes with a clean Spack instance
4. Submit a pull request with a clear description

## Support

- **Documentation**: See this README and [Spack documentation](https://spack.readthedocs.io/)
- **Issues**: Report bugs or request features via GitHub Issues
- **Discussions**: Use GitHub Discussions for questions and community support

## License

This project follows the same license as the main Spack project. See [LICENSE](LICENSE) for details.

## Acknowledgments

Maintained by the HKUST HPC team. This configuration is designed for production HPC environments and is continuously tested across multiple Linux distributions.
