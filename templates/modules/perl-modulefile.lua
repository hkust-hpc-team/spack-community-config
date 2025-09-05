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

-- CPAN-specific settings
local cpan_home = os.getenv("HOME") .. "/.cpan"
execute{cmd = "mkdir -p " .. cpan_home, modeA={"load"}}
setenv("CPAN_HOME", cpan_home)
setenv("PERL_CPAN_MIRROR", "http://www.cpan.org/")
{% endblock %}
