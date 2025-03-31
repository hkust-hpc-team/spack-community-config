{% extends "modules/modulefile.lua" %}
{% block footer %}
local matlab_user_home = "~/.matlab/{{ spec.version }}-{{ spec.dag_hash()[:7] }}"
execute{cmd = "mkdir -p " .. matlab_user_home, modeA={"load"}}
setenv("MATLABPATH", matlab_user_home)
{% endblock %}
