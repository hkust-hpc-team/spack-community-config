{% extends "modules/modulefile.lua" %}
{% block footer %}
-- Put this file in $spack/share/templates
-- export SPACK_LMOD_LOAD_HOOK_SCRIPT=/raid/spack-test/site/scripts/03-site/hooks/samples/post-module-load.sh 

local ok, m = pcall(mode)
if ok and m == "load" then
  local script = os.getenv("SPACK_LMOD_LOAD_HOOK_SCRIPT")
  if script and #script > 0 then
    local function sh_quote(s)
      s = s or ""
      s = string.gsub(s, "'", "'\"'\"'")
      return "'" .. s .. "'"
    end
    local cmd = sh_quote(script) .. " " .. sh_quote(myModuleFullName()) .. " " .. sh_quote(myModuleVersion())
    local debug = os.getenv("SPACK_HOOK_DEBUG")
    local suffix
    if debug and #debug > 0 then
      -- keep backgrounding but don’t silence output
      suffix = " &"
    else
      suffix = " >/dev/null 2>&1 &"
    end
    pcall(function() os.execute(cmd .. suffix) end)
  end
end
{% endblock %}