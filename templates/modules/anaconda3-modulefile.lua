{% extends "modules/modulefile.lua" %}
{% block footer %}
local home = os.getenv("HOME")

-- Remove conda initialize block from $HOME/.bashrc if it exists
local bashrc_file = pathJoin(home, ".bashrc")
execute{cmd="sed -i '/# >>> conda initialize >>>/,/# <<< conda initialize <<</d' " .. bashrc_file, modeA={"load"}}

-- Set up symlink in $HOME/.bashrc.d/anaconda3.sh to conda.sh
--   1. Create $HOME/.bashrc.d if it doesn't exist
--   2. symlink $HOME/.bashrc.d/anaconda3.sh -> <install_prefix>/etc/profile.d/conda.sh
-- Since conda lifecycle works independently of module load/unload
-- We do not remove the symlink on unload.
-- Instead we force recreate it on load to ensure it points to the correct version.

-- Create .bashrc.d directory if it doesn't exist
local bashrc_dir = pathJoin(home, ".bashrc.d")
execute{cmd="mkdir -p " .. bashrc_dir, modeA={"load"}}

-- Force create symlink to conda.sh (overwrites existing link)
local conda_init = pathJoin("{{ spec.prefix }}", "etc", "profile.d", "conda.sh")
local link_target = pathJoin(bashrc_dir, "anaconda3.sh")
execute{cmd="ln -sf " .. conda_init .. " " .. link_target, modeA={"load"}}

-- Although bash function does not work in modulefiles
-- We still source it to set up environment variables.
source_sh("bash", conda_init)

-- Prompt user to activate conda
local current_mode = mode()
if current_mode == "switch" then
    LmodMessage([[

Anaconda3 version has been switched. 
Please logout and login again to ensure the new version is properly initialized.
]])
elseif current_mode == "load" then
    LmodMessage([[

==> On your NEXT login, Anaconda3 will be available automatically.
==> To activate conda NOW, run:

    source ~/.bashrc.d/anaconda3.sh

==> To UNINSTALL Anaconda3, run: `rm -f ~/.bashrc.d/anaconda3.sh`
]])
end
{% endblock %}
