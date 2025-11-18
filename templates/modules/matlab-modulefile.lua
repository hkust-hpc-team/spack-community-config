{% extends "modules/modulefile.lua" %}
{% block footer %}
local matlab_user_home = os.getenv("HOME") .. "/.matlab/{{ spec.version }}"
execute{cmd = "mkdir -p " .. matlab_user_home, modeA={"load"}}
prepend_path("MATLABPATH", matlab_user_home)
{% endblock %}
