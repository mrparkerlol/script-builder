--[[
	Written by Jacob (@monofur, https://github.com/mrteenageparker)

	You are allowed to modify the contents and
	redistribute it, provided you
	keep this above notice and
	republish the original source
	in a way that it is publicly
	available so other people can 
	potentially benefit from your 
	improvements/changes!

	Feel free to read the source of this
	script (including the latest changes)
	on my Github (or create helpful pull 
	requests, if that's your thing!):
	https://github.com/mrteenageparker/sb-in-a-require
]]

local Script = script:Clone();

wait();
script.Parent = nil;
script:Destroy();
script = nil;

local Players             = game:GetService("Players");
local ServerScriptService = game:GetService("ServerScriptService");
local HttpService         = game:GetService("HttpService");
local ReplicatedStorage   = game:GetService("ReplicatedStorage");
local ScriptContext       = game:GetService("ScriptContext");

local Settings = require(Script:WaitForChild("Config"));

-- setup global tables

-- these will be returned in sandboxed
-- scripts to prevent potential for
-- people to overwrite the script
-- builder tables in _G
_G.sandboxedShared = {};
_G.sandboxedG = {};
_G.protectedObjects = {};

local indexedScripts = {};

-- Setup the game

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

local ClientToServerRemote = Instance.new("RemoteEvent");
ClientToServerRemote.Name = "SB_Remote";
ClientToServerRemote.Parent = ReplicatedStorage;

-- our SB table to handle
-- our SB tasks between
-- scripts
setmetatable(shared, {
  __call = (function(self, arg, arg2)
    if arg == "Sandbox" then
      local Sandbox = Script.Essentials.dad_b0x:Clone();
      return Sandbox;
    elseif arg == "Output" and arg2 then
      ClientToServerRemote:FireClient(arg2.Owner, "output", {
        ['Type'] = arg2.Type,
        ['Message'] = arg2.Message
      });
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
        local LocalScript = Script.Scripts.LocalScript:Clone();
  
        sc.Parent = LocalScript;
        sc.Name = "LSource";

        LocalScript.Parent = plr.Character;
        LocalScript.Disabled = false;
      else
        -- do some sort of error checking here
      end;
    end;
  elseif type == "Server" then
    local Sc = Script.Scripts.Script:Clone();
    indexedScripts[Sc] = {
      ['src'] = code;
      ['owner'] = plr;
      ['Disabled'] = false;
      ['Sc'] = Sc;
    };

    Sc.Parent = workspace;
    Sc.Disabled = false;
  end;
end;

local function killScripts(command, plr)
  if command == "ns" or command == "ns/all" then
    for i,v in pairs(indexedScripts) do
      if plr then
        if v.owner == plr then
          v.Disabled = true;
          v = nil;
        end;
      else
        v.Disabled = true;
        v = nil;
      end;
    end;
  elseif command == "nl" or command == "nl/all" then
    -- logic here
  end;
end;

-- https://stackoverflow.com/a/7615129/4962676
-- modified a little to be more efficient
local function split(inputStr, sep)
  local sep = (sep == nil and "([^%s]+)") or sep;
  local t, sepString = {};
  for str in inputStr:gmatch(sep) do
    t[#t + 1] = str;
  end;

  return t;
end;

local function handleCommand(plr, msg)
  if msg:sub(0, 2) == "l/" then
    handleCode(plr, msg:sub(3), "Local");
  elseif msg:sub(0, 2) == "c/" then
    handleCode(plr, msg:sub(3), "Server");
  elseif msg:sub(0, 2) == "h/" then
    handleCode(plr, msg:sub(3), "hServer");
  elseif msg:sub(0, 3) == "hl/" then
    handleCode(plr, msg:sub(4), "hLocal");
  elseif msg:sub(0, 2) == "g/" then
    local msg = split(msg:sub(3));
    for _,word in pairs(msg) do
      spawn(function()
        if word:match("ns") then
          killScripts(word, plr);
        end
  
        if word:match("nl") then
          ClientToServerRemote:FireClient(plr, "nl");
        end
  
        if word:match("c") then
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
            if PlayerCharacters[v] or v.ClassName == "Script" or v.ClassName == "LocalScript" then
    
            else
              pcall(function()
                v:Destroy()
              end);
            end;
          end;
  
          BaseplateTemplate:Clone().Parent = workspace;
        end
    
        if word:match("r") then
          plr:LoadCharacter();
        end
  
        if word:match("ns/all") then
          killScripts(word);
        end
  
        if word:match("nl/all") then
          ClientToServerRemote:FireAllClients("nl/all", plr);
        end
  
        if word:match("ws/%w+") then
          pcall(function()
            plr.Character.Humanoid.WalkSpeed = tonumber(word:match("/%w+"):sub(2));
          end);
        end;
      end);
    end;
  end;
end;

if game:GetService("RunService"):IsStudio() then
  repeat wait() until #Players:GetPlayers() > 0

  for _,plr in pairs(Players:GetPlayers()) do
    repeat wait() until plr.Character;

    Script.ClientScripts.ClientHandler:Clone().Parent = plr.Backpack;

    plr.Chatted:connect(function(msg)
      handleCommand(plr, msg);
    end);
  end
end

Players.PlayerAdded:connect(function(plr)
  repeat wait() until plr.Character;

  Script.ClientScripts.ClientHandler:Clone().Parent = plr.Backpack;

  plr.Chatted:connect(function(msg)
    handleCommand(plr, msg);
  end);
end);

ClientToServerRemote.OnServerEvent:connect(function(plr, command)
  handleCommand(plr, command);
end);

ScriptContext.Error:connect(function(message, trace, sc)
  if indexedScripts[sc] then
    ClientToServerRemote:FireClient(indexedScripts[sc].owner, "output", {
      ['Type'] = "error",
      ['Message'] = message:gsub("Sandbox:%w+: ", "")
    });
  end;
end);

return true;