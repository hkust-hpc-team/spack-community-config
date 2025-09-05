# Python package management

We provide python bootstrapping without using spack.


## Script

```
set -euo pipefail

for i in 3.9 3.10 3.11 3.12 3.13; do
  module load python/$i
  python_cmd="$(command -v python$i)"
  echo "Using $python_cmd"
  $python_cmd -m ensurepip --upgrade
  $python_cmd -m pip install --upgrade pip virtualenv uv pdm poetry
  which pip
  which uv
  which pdm
  which poetry
  module purge
done
```
