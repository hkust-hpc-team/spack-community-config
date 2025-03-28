{% extends "modules/modulefile.lua" %}
{% block footer %}
local r_libs_user = "~/.R/R-{{ spec.version }}-{{ spec.compiler.name }}-{{ spec.compiler.version }}-{{ spec.target.name }}-{{ spec.dag_hash()[:7] }}/library"
execute{cmd = "mkdir -p " .. r_libs_user, modeA={"load"}}
setenv("R_LIBS_USER", r_libs_user)
{% endblock %}
