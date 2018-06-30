if not shared(script) then
  -- TODO:
  -- add support for NLS
  shared(script, game.Players.LocalPlayer);
end;

local sharedTable = shared;
local realPrint = print;
local realWarn = warn;

local _env = getfenv();
_env['shared'] = _G.fakeSharedTable;
_env['_G'] = _G.fakeGTable;

setfenv(require(script:WaitForChild("LSource")), setmetatable({}, {
  __index = (function(self, index)
    if sharedTable(script) and sharedTable(script).Disabled == true then
      return error("Script disabled.", 0);
    end;

    if typeof(_env[index]) == "Instance" and (sharedTable(_env[index]) or sharedTable(_env[index].ClassName)) then
      return nil;
    else
      return _env[index];
    end;
  end);

  __newindex = (function(self, index, newindex)
    if sharedTable(script) and sharedTable(script).Disabled == true then
      return error("Script disabled.", 0);
    end;

    local s,m = pcall(function()
      _env[index] = newindex;
    end);

    if not s then
      return error(m, 2);
    end;
  end);

  __metatable = getmetatable(_env);
}))();