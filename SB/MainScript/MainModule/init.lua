local Players             = game:GetService("Players");
local ServerScriptService = game:GetService("ServerScriptService");
local HttpService         = game:GetService("HttpService");

local Settings = require(script:WaitForChild("Config"));

-- setup global tables

-- these will be returned in sandboxed
-- scripts to prevent potential for
-- people to overwrite the script
-- builder tables in _G
_G.sandboxedShared = {};
_G.sandboxedG = {};

local indexedScripts = {};

-- Our default baseplate to restore to
-- when things go wrong (and they will)
local BaseplateTemplate = Instance.new("Part")
BaseplateTemplate.Size = Vector3.new(1200, 2, 1200);
BaseplateTemplate.Position = Vector3.new(-30, -10, 13);
BaseplateTemplate.Color = Color3.fromRGB(31, 128, 29);
BaseplateTemplate.Material = Enum.Material.Grass
BaseplateTemplate.TopSurface = Enum.SurfaceType.Smooth
BaseplateTemplate.BottomSurface = Enum.SurfaceType.Smooth
BaseplateTemplate.Anchored = true;
BaseplateTemplate.Locked = true;
BaseplateTemplate.Name = "Base";

BaseplateTemplate:Clone().Parent = workspace;

-- our SB table to handle
-- our SB tasks between
-- scripts
setmetatable(shared, {
  __call = (function(self, arg)
    if arg == "Sandbox" then
      return require(script.Essentials.Sandbox);
    elseif typeof(arg) == "Instance" then
      if arg.ClassName == "Script" then
        local copy = indexedScripts[arg];
        return copy;
      end;
    end;
  end);

  __index = "Locked. (shared)";
  __metatable = "Locked. (shared)";
});

local function handleCode(plr, code, type)
  if type == "hServer" or type == "hLocal" then
    local s,m = pcall(function()
      return HttpService:GetAsync(code, false);
    end);

    if s then
      if type == "hLocal" then
        handleCode(plr, m, "Local");
      else
        handleCode(plr, m, "Server");
      end;
    else
      -- TODO: let the person know the request failed
    end;
  end;

  if type == "Local" then
    local to_upload = "return function() " .. code .." end;";
  
    local result = HttpService:JSONDecode(HttpService:PostAsync(Settings.APIUrl, to_upload));
    if result and typeof(result) == "table" then
      if result.AssetId then
        local sc = require(result.AssetId)():Clone();
        local LocalScript = script.Scripts.LocalScript:Clone();
  
        sc.Parent = LocalScript;
        sc.Name = "LSource";

        LocalScript.Parent = plr.Character;
        LocalScript.Disabled = false;
      else
        -- do some sort of error checking here
      end;
    end;
  elseif type == "Server" then
    local Sc = script.Scripts.Script:Clone();
      indexedScripts[Sc] = {
        ['src'] = code;
        ['owner'] = plr;
        ['Disabled'] = false;
      };

      Sc.Parent = workspace;
      Sc.Disabled = false;
  end;
end;

local function killScripts(command, plr)
  if command == "ns" or command == "ns/all" then
    for _,v in pairs(indexedScripts) do
      if plr then
        if v.owner == plr then
          v.Disabled = true;
        end;
      else
        v.Disabled = true;
      end;
    end;
  elseif command == "nl" or command == "nl/all" then
    -- logic here
  end;
end;

Players.PlayerAdded:connect(function(plr)
  plr.Chatted:connect(function(msg)
    if msg:sub(0, 2) == "l/" then
      handleCode(plr, msg:sub(3), "Local");
    elseif msg:sub(0, 2) == "c/" then
      handleCode(plr, msg:sub(3), "Server");
    elseif msg:sub(0, 2) == "h/" then
      handleCode(plr, msg:sub(3), "hServer");
    elseif msg:sub(0, 3) == "hl/" then
      handleCode(plr, msg:sub(4), "hLocal");
    elseif msg:sub(0, 2) == "g/" then
      local msg = msg:sub(3);
      if msg:sub(0, 2) == "ns" then
        killScripts(msg, plr);
      elseif msg:sub(0, 6) == "ns/all" then
        killScripts(msg);
      elseif msg:sub(0, 1) == "c" then
        local PlayerCharacters = {};

        for _,v in pairs(Players:GetPlayers()) do
          local pos = nil;
          if v.Character and v.Character:FindFirstChild("HumanoidRootPart") then
            pos = v.Character.HumanoidRootPart.CFrame;
          end;

          v:LoadCharacter();

          if pos then
            v.Character.HumanoidRootPart.CFrame = pos;
          end;

          PlayerCharacters[v.Character] = v.Character;
        end;

        for _,v in pairs(workspace:GetChildren()) do
          if not PlayerCharacters[v] then
            pcall(function()
              v:Destroy()
            end);
          end;
        end;

        BaseplateTemplate:Clone().Parent = workspace;
      elseif msg:sub(0, 3) == "ws/" then
        pcall(function()
          plr.Character.Humanoid.WalkSpeed = tonumber(msg:sub(4));
        end);
      end;
    end;
  end);
end);

return true;