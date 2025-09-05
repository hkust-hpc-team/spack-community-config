{% extends "modules/modulefile.lua" %}
{% block footer %}
local perl5_home = os.getenv("HOME") .. "/.perl5"
execute{cmd = "mkdir -p " .. perl5_home .. "/lib/perl5", modeA={"load"}}
execute{cmd = "mkdir -p " .. perl5_home .. "/bin", modeA={"load"}}

setenv("PERL5LIB", perl5_home .. "/lib/perl5")
setenv("PERL_LOCAL_LIB_ROOT", perl5_home)
setenv("PERL_MB_OPT", "--install_base \"" .. perl5_home .. "\"")
setenv("PERL_MM_OPT", "INSTALL_BASE=" .. perl5_home)
prepend_path("PATH", perl5_home .. "/bin")
{% endblock %}
