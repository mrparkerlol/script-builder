return function(code)
  return [[
  local Script = script:Clone();

  if not shared(Script) then
    -- TODO:
    -- add support for NLS
    shared(Script, game.Players.LocalPlayer);
  end;

  local sharedTable = shared;
  local realPrint = print;
  local realWarn = warn;

  local function handleOutput(type, ...)
    local args = {...};
    local output = "";

    for i=1, #args do
      output = output .. ' ' .. tostring(args[i]);
    end;

    sharedTable(output, type);
  end;

  local _env = getfenv();
  _env['shared'] = _G.fakeSharedTable;
  _env['_G'] = _G.fakeGTable;
  _env['print'] = (function(...)
    handleOutput("print", ...);

    realPrint(...);
  end);
  _env['warn'] = (function(...)
    handleOutput("warn", ...);

    realWarn(...);
  end);

  local env = setmetatable({}, {
    __index = (function(self, index)
      if sharedTable(Script) and sharedTable(Script).Disabled == true then
        error("Script disabled.", 0);
      end;

      if typeof(_env[index]) == "Instance" and (sharedTable(_env[index]) or sharedTable(_env[index].ClassName)) then
        return nil;
      else
        return _env[index];
      end;
    end);

    __newindex = (function(self, index, newindex)
      if sharedTable(Script) and sharedTable(Script).Disabled == true then
        error("Script disabled.", 0);
      end;

      local s,m = pcall(function()
        _env[index] = newindex;
      end);

      if not s then
        return error(m, 2);
      end;
    end);

    __metatable = getmetatable(_env);
  });

  setfenv(0, env);
  setfenv(1, env);
  setfenv(function()
]]
    .. code ..
[[
  end, env)();
]]
end;