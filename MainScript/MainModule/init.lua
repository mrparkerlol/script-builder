--[[
	Written by Jacob (mrparkerlol on Github), with contributions by others.

	This is the main script source for the Script Builder Project,
	licensed GPL V3 only.

	This is provided free of charge, no warranty or liability
	provided. Use of this project is at your own risk.

	Documentation is also provided on Github, if needed.
]]

-- Cloning the script is nessessary
-- in order to prevent destroying
-- of the internals of the script builder
local Script = script:Clone();

-- This code destroys the module
-- to prevent the destruction of
-- the script builder internals
wait();
script.Parent = nil;
script:Destroy();
script = nil;

-- This part of the code allows
-- for the use case for when shared
-- is already defined, and if it is
-- it will use a nested table instead.
local shared = shared;
if getmetatable(shared) ~= nil and shared.SB == nil then
	shared.SB = {};
	shared = shared.SB;
elseif (getmetatable(shared) ~= nil and pcall(shared, "IsSB")) or shared.SB ~= nil then
	return error("Duplicate script builders detected! Make sure you aren't attempting to run duplicate instances!");
end;

local typeof = typeof;
local game = game;

-- Services used inside the script builder
local Players = game:GetService("Players");
local HttpService = game:GetService("HttpService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ScriptContext = game:GetService("ScriptContext");
local RunService = game:GetService("RunService");
local MarketplaceService = game:GetService("MarketplaceService");
local InsertService = game:GetService("InsertService");
local Teams = game:GetService("Teams");
local Lighting = game:GetService("Lighting");
local TeleportService = game:GetService("TeleportService");

-- Helper to get the name of the place
local PLACE_INFO = game.PlaceId ~= 0 and MarketplaceService:GetProductInfo(game.PlaceId) or nil;

-- The ClientHandler and ConsoleGui used
local ClientHandler = Script.ClientEssentials.ClientHandler:Clone();
local ConsoleGui = Script.ClientEssentials.Console:Clone();

--[[
	This module is a helper module
	in which returns the assets
	used for the dummies and for
	morphing to/from R6 and R15
	in-game, as well as assets
	for the F3X tools and
	terrain tools

	It should never be obfuscated
]]
local HelperAssets = require(5519739474); -- Module is open source

--[[
	Global LightingSettings helps with
	the settings in which can change
	in lighting - whatever is set
	here in the beginning when the
	game runs will be the "defaults"
]]
local LightingSettings = {
	Ambient = Lighting.Ambient,
	Brightness = Lighting.Brightness,
	ColorShift_Bottom = Lighting.ColorShift_Bottom,
	ColorShift_Top = Lighting.ColorShift_Top,
	EnvironmentDiffuseScale = Lighting.EnvironmentDiffuseScale,
	EnvironmentSpecularScale = Lighting.EnvironmentSpecularScale,
	GlobalShadows = Lighting.GlobalShadows,
	OutdoorAmbient = Lighting.OutdoorAmbient,
	ShadowSoftness = Lighting.ShadowSoftness,
	ClockTime = Lighting.ClockTime,
	GeographicLatitude = Lighting.GeographicLatitude,
	Name = Lighting.Name,
	TimeOfDay = Lighting.TimeOfDay,
	Archivable = Lighting.Archivable,
	ExposureCompensation = Lighting.ExposureCompensation,
	FogColor = Lighting.FogColor,
	FogEnd = Lighting.FogEnd,
	FogStart = Lighting.FogStart
};

--[[
	ServerGUID Uniquely identifies each server instance - can only be set once on the backend
	This is not supposed to be accessable - and prevents the API from being accessed
	in an unauthorized way

	Again, this shouldn't be accessable at all
]]
local ServerGUID = HttpService:GenerateGUID(false);

--[[
	Global SB exposes the public APIs
	to the requiring script - allows for
	great customization of the SB
]]
local SB = {};
SB.Commands = {
	GCommands = {}, -- Custom commands for g/ or get/ in the script builder
	Commands = {}, -- Commands which don't require a prefix
};
SB.Settings = { -- Stores settings (such as API url, etc)
	API_BASE_URL = "https://rbxapi.mrparker.pw", -- default URL (can be changed by passing desired settings when required)
};
SB.Sandbox = require(Script.Essentials.Sandbox); -- Allows indexing of the public members of the sandbox

-- Add tables for _G and shared to the sandbox
SB.Sandbox.setUnWrappedGlobalOverride("shared", setmetatable({}, { __metatable = "The metatable is locked" }));
SB.Sandbox.setUnWrappedGlobalOverride("_G", setmetatable({}, { __metatable = "The metatable is locked" }));

local indexedScripts = {};
local indexedPromptedLocalScripts = {};

-- Our default baseplate to restore to
local BaseplateTemplate = Instance.new("Part");
BaseplateTemplate.Size = Vector3.new(1200, 2, 1200);
BaseplateTemplate.Position = Vector3.new(0, -1, 0);
BaseplateTemplate.BrickColor = BrickColor.new("Dark green");
BaseplateTemplate.Material = Enum.Material.Grass
BaseplateTemplate.TopSurface = Enum.SurfaceType.Smooth
BaseplateTemplate.BottomSurface = Enum.SurfaceType.Smooth
BaseplateTemplate.Anchored = true;
BaseplateTemplate.Locked = true;
BaseplateTemplate.Name = "Base";

-- The current baseplate
local currentBase;
currentBase = BaseplateTemplate:Clone();
currentBase.Parent = workspace;

-- Current walls around the baseplate
local currentWalls = {};

-- Current remotes
local ClientToServerRemote, ClientToServerRemoteFunction;

-- Output handler for use in this script
local function handleOutput(player, type, message)
	shared("Output", {
		Owner = player,
		Type = type,
		Message = message
	});
end;

-- Cached function for handling ClientToServerRemoteFunction
local function getConfig(_, arg)
	if arg == "PLACE_NAME" then -- Returns the place name to the client
		return SB.Settings.PLACE_NAME;
	elseif arg == "healthCheck" then -- Returns a response to the client
		return "good";
	end;
end;

-- Internal function used for interfacing
-- with the backend for the script builder
local function handleAPICall(apiUrlString, data)
	return HttpService:PostAsync(SB.Settings.API_BASE_URL .. apiUrlString, HttpService:JSONEncode({
		["jobId"] = game.JobId,
		["GUID"] = ServerGUID, -- ServerGUID should never be shared - this would allow spoofing of requests
		["data"] = data,
	}));
end;

-- Internal function used to recover the script builder
-- from the destruction of the remotes
local function recreateRemote()
	if not ReplicatedStorage:FindFirstChild("SB_Config") then -- SB_Config was destroyed
		ClientToServerRemoteFunction = Instance.new("RemoteFunction");
		ClientToServerRemoteFunction.Name = "SB_Config";
		ClientToServerRemoteFunction.Parent = ReplicatedStorage;

		SB.Sandbox.addProtectedObject(ClientToServerRemoteFunction);

		ClientToServerRemoteFunction.OnServerInvoke = getConfig;

		-- Prevent renaming
		ClientToServerRemoteFunction.Changed:Connect(function(property)
			if property == "name" then
				ClientToServerRemoteFunction.Name = "SB_Config";
			end;
		end);
	end;

	if not ReplicatedStorage:FindFirstChild("SB_Remote") then -- SB_Remote was destroyed
		ClientToServerRemote = Instance.new("RemoteEvent");
		ClientToServerRemote.Name = "SB_Remote";
		ClientToServerRemote.Parent = ReplicatedStorage;

		SB.Sandbox.addProtectedObject(ClientToServerRemote);

		ClientToServerRemote.OnServerEvent:connect(function(player, ...)
			local args = {...};
			local command = args[1];
			if command == "NewGui" then -- Client requested a fresh Console GUI
				-- Create a fresh Console gui
				local guiClone = ConsoleGui:Clone();
				guiClone.Parent = player.PlayerGui;

				-- Add it to the sandbox to prevent indexing
				SB.Sandbox.addObjectToProtectedList(guiClone);
			elseif command == "yesLocal" then -- When a client has approved a local script
				local ScriptTable = args[2] and indexedPromptedLocalScripts[args[2]];
				if ScriptTable then
					local Script = ScriptTable.LocalScript;
					local Parent = ScriptTable.Parent;
					Script.Parent = Parent;
					ClientToServerRemoteFunction:InvokeClient(player, {
						["Handler"] = "LocalScript",
						["LocalScript"] = Script
					});
					Script.Disabled = false;
				end;
			else
				SB.handleCommand(player, command);
			end;
		end);

		-- Prevent renaming
		ClientToServerRemote.Changed:Connect(function(property)
			if property == "name" then
				ClientToServerRemote.Name = "SB_Remote";
			end;
		end);
	end;
end;

-- Prevent destroying the remote
RunService.Heartbeat:Connect(function()
	if not ReplicatedStorage:FindFirstChild("SB_Remote") or not ReplicatedStorage:FindFirstChild("SB_Config") then -- one of them hasn't been found
		recreateRemote();
	end;
end);

--[[
	SB.runCode()

	Runs code in the script builder of the specified type
	either on the player themself, or on another player
	based on the parent property
]]
function SB.runCode(player, type, source, parent)
	if type == "HttpServer" or type == "HttpLocal" then
		local success, code = pcall(function()
			return HttpService:GetAsync(source, false);
		end);

		if success then
			if type == "HttpServer" then
				return SB.runCode(player, "Server", code, workspace);
			end;
			return SB.runCode(player, "Local", code, player.Character);
		else
			handleOutput(player, "error", "Failed to get script. If you are a place owner, check output.");
			warn("HTTPService:GetAsync() failed with reason:", code);
		end;
	elseif type == "Server" then
		local Script = Script.Scripts.Script:Clone();
		indexedScripts[Script] = {
			Source = source,
			Owner = player,
			Script = Script,
			SandboxInstance = {},
		};

		if parent ~= nil then
			Script.Parent = parent;
		end;

		Script.Disabled = false;
		return Script;
	elseif type == "Local" then
		local func, message = loadstring(source, 'SB-LocalScript');
		if not func then
			handleOutput(player, "error", message);
		else
			local success, response = pcall(function()
				local postData = {
					["code"] = source,
					["assetId"] = SB.Settings.ASSET_ID,
				};
				local response = handleAPICall("/api/uploadLocalScript", postData);
				return HttpService:JSONDecode(HttpService:JSONDecode(response).message);
			end);

			if success then
				local Script = nil;
				if SB.Settings.ASSET_ID ~= nil and SB.Settings.ASSET_ID ~= 0 then
					Script = InsertService:LoadAssetVersion(response.AssetVersionId):GetChildren()[1];
				else
					-- Expects a LocalScript to be returned
					Script = require(response.AssetId);

					-- This part is important for deleting the
					-- local script after it is done with being
					-- used. This needs to be kept to prevent
					-- people from stealing local scripts.
					spawn(function()
						handleAPICall("/api/deleteLocalScript", {
							["assetId"] = response.AssetId
						});
					end);
				end;

				if parent ~= nil and Script ~= nil then
					if parent:IsDescendantOf(player) or parent == player.Character then
						Script.Parent = parent;
						ClientToServerRemoteFunction:InvokeClient(player, {
							["Handler"] = "LocalScript",
							["LocalScript"] = Script,
						});
						Script.Disabled = false;
					else
						local Player = Players:GetPlayerFromCharacter(parent) or
										parent:FindFirstAncestorOfClass("Player");
						if Player then
							local GUID = HttpService:GenerateGUID(false);
							ClientToServerRemote:FireClient(Player, {
								["Handler"] = "PromptLocal",
								["Player"] = player,
								["GUID"] = GUID,
							});

							indexedPromptedLocalScripts[GUID] = {
								Parent = parent,
								LocalScript = Script
							};
						end;
					end;
				end;

				return Script;
			else
				handleOutput(player, "error", "Failed to upload local script. If you are a place owner, check output.");
				warn("HTTPService:PostAsync() failed with reason:", response);
			end;
		end;
	end;
end;

--[[
	SB.addCommand()
	Adds a g/ command to the script builder
	It does not allow function parameters to be passed

	commandIndex can be a table with more aliases for
	the specific command, or just a string
]]
function SB.addCommand(commandType, commandName, usage, commandIndex, func)
	assert(typeof(commandType) == "string", "Expected string as first argument to SB.addCommand");
	assert(typeof(commandName) == "string", "Expected string as second argument to SB.addCommand");
	assert(typeof(usage) == "string", "Expected string as third argument to SB.addCommand");
	assert(typeof(commandIndex) == "string" or typeof(commandIndex) == "table", "Expected string or table as foruth argument to SB.addCommand");
	assert(typeof(func) == "function", "Expected function as fifth argument to SB.addCommand");

	if usage:find("/") then
		usage = usage:sub(usage:find("/"), usage:len());
	else
		usage = "";
	end;

	if typeof(commandIndex) == "table" then
		for i = 1, #commandIndex do
			local command = commandIndex[i];
			if not SB.Commands[command] then
				if commandType == "g" then
					SB.Commands.GCommands[command] = {
						Function = func,
						Name = commandName,
						Usage = (command:find("/") and command:sub(1, command:find("/") - 1) or command) .. usage,
					};
				elseif commandType == "prefixless" then
					SB.Commands.Commands[command] = {
						Function = func,
						Name = commandName,
						Usage = (command:find("/") and command:sub(1, command:find("/") - 1) or command) .. usage,
					};
				end;
			end;
		end;
	else
		if not SB.Commands[commandIndex] then
			if commandType == "g" then
				SB.Commands.GCommands[commandIndex] = {
					Function = func,
					Name = commandName,
					Usage = (commandIndex:find("/") and commandIndex:sub(1, commandIndex:find("/") - 1) or commandIndex) .. usage,
				};
			elseif commandType == "prefixless" then
				SB.Commands.Commands[commandIndex] = {
					Function = func,
					Name = commandName,
					Usage = (commandIndex:find("/") and commandIndex:sub(1, commandIndex:find("/") - 1) or commandIndex) .. usage,
				};
			end;
		end;
	end;
end;

--[[
	SB.getCommand()
	Returns the table for the command found
	with the given index
]]
function SB.getCommand(commandType, commandIndex)
	assert(typeof(commandType) == "string", "Expected string as the first argument to SB.getCommand");
	assert(typeof(commandIndex) == "string", "Expected string as second argument to SB.getCommand");

	commandIndex = commandIndex:lower();

	if commandType == "g" then
		for index, commandTable in pairs(SB.Commands.GCommands) do
			if SB.Commands.GCommands[commandIndex] then
				return SB.Commands.GCommands[commandIndex];
			elseif commandIndex:match(index) and not SB.Commands.GCommands[commandIndex:match(index)] then
				return commandTable;
			end;
		end;
	else
		for index, commandTable in pairs(SB.Commands.Commands) do
			if SB.Commands.Commands[commandIndex] then
				return SB.Commands.Commands[commandIndex];
			elseif commandIndex:match(index) and not SB.Commands.Commands[commandIndex:match(index)] then
				return commandTable;
			end;
		end;
	end;

	return nil;
end;

-- Initialize script builder internals
setmetatable(shared, { -- shared is specifically used between server scripts
	__call = (function(_, arg, ...)
		local args = {...};
		if arg == "Sandbox" then -- Return the sandbox
			return SB.Sandbox;
		elseif arg == "runScript" then -- NS
			assert(typeof(args[1]) == "string", "Expected a string when calling shared(\"runScript\") arg #1");
			assert(typeof(args[3]) == "Instance", "Expected a Instance when calling shared(\"runScript\") arg #3");

			local code, parent, player = args[1], args[2], args[3];
			return SB.runCode(player, "Server", code, parent);
		elseif arg == "runLocal" then -- NLS
			local code, parent, player = args[1], args[2], args[3];

			assert(typeof(code) == "string", "Expected a string when calling shared(\"runLocal\") arg #1");
			assert(typeof(player) == "Instance" and player.ClassName == "Player", "Expected a Player when calling shared(\"runLocal\") arg #3");

			return SB.runCode(player, "Local", code, parent);
		elseif arg == "Output" and args[1] then -- Sends output to the client
			local argsTable = args[1];
			if argsTable.Owner and argsTable.Type and argsTable.Message then
				ClientToServerRemote:FireClient(argsTable.Owner, {
					['Handler'] = "Output",
					['Type'] = argsTable.Type,
					['Message'] = argsTable.Message
				});
			elseif argsTable.Type and argsTable.Message then
				ClientToServerRemote:FireAllClients({
					['Handler'] = "Output",
					['Type'] = argsTable.Type,
					['Message'] = argsTable.Message
				});
			end;
		elseif typeof(arg) == "Instance" and arg.ClassName == "Script" then -- A server script is asking for the source to run
			if indexedScripts[arg] then
				return indexedScripts[arg];
			end;
		elseif arg == "IsSB" then
			return true;
		end;
	end),

	__metatable = "The metatable is locked" -- Prevents overwriting the metatable
});

--[[
	SB.killScripts()
	Takes a player and command - if command is equal to "all"
	it will kill all running scripts

	This is specifically for server scripts
]]
function SB.killScripts(player, command)
	if player and command == "all" then
		handleOutput(nil, "general", "g/ns/all from " .. player.Name);
	end;

	for index, tbl in pairs(indexedScripts) do
		if tbl.Owner == player then
			-- Set the script as disabled
			SB.Sandbox.kill(tbl.Script);

			-- Remove the reference to the script entirely
			indexedScripts[index] = nil;
		elseif command == "all" then
			-- Set the script as disabled
			SB.Sandbox.kill(tbl.Script);
		end;
	end;

	if command == "all" then
		indexedScripts = {};
	end;
end;

--[[
	SB.handleCommand()
	Takes a player and a string, the string is specifically
	the command the player ran

	This handles prefixless commands (such as c/ and l/)
	and get commands (g/ and get/ commands)
]]
function SB.handleCommand(player, commandString)
	local commandSub = commandString:find("/") and commandString:sub(1, commandString:find("/") - 1):lower(); -- Get the command
	if commandSub then
		local command = SB.getCommand("prefixless", commandSub);
		if command then
			command.Function(player, commandString:sub(commandString:find("/") + 1, commandString:len()));
		elseif commandSub == "g" or commandSub == "get" then
			local commands = commandString:sub(commandString:find("/") + 1, commandString:len()):split(" "); -- split the command into pieces
			for _, command in pairs(commands) do
				local commandIndex = SB.getCommand("g", command);
				if commandIndex then
					-- Remove the command itself from the command arguments
					local commandSlash = command:find("/") or 0;

					-- Send to output
					handleOutput(player, "general", "Got " .. commandIndex.Name);

					-- Call the function (with the player who called it, and command)
					commandIndex.Function(player, unpack(string.split(command:sub(commandSlash + 1, command:len()), "/")));
				end;
			end;
		end;
	end;
end;

-- Handles breaking down the game
game:BindToClose(function()
	-- Unregister the server with the backend
	handleAPICall("/api/unRegisterServer", HttpService:JSONEncode({
		["jobId"] = game.JobId,
		["GUID"] = ServerGUID
	}));
end);

--[[
	init()

	Initializes the script builder with all default commands,
	and initializes connections for the game such as adding
	GUIs and handling output

	This is a particularly intensive function, and is only
	executed after important tasks
]]
local function init()
	local function createDummy(player, type)
		local dummy = HelperAssets.Dummies[type]:Clone();
		dummy.Name = "Dummy";
		dummy.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, -4);

		table.insert(SB.Sandbox.CreatedInstances, dummy);

		dummy.Parent = workspace;
	end;

	-- Initialize prefixless commands
	SB.addCommand("prefixless", "run Script", "%w+/code", { "script", "s", "c", "do" }, function(player, code)
		SB.runCode(player, "Server", code, workspace);
	end);

	SB.addCommand("prefixless", "run Local", "%w+/code", { "local", "x", "l" }, function(player, code)
		SB.runCode(player, "Local", code, player.Character);
	end);

	SB.addCommand("prefixless", "run HttpScript", "%w+/url", { "runh", "rsh", "rh", "h" }, function(player, code)
		SB.runCode(player, "HttpServer", code, workspace);
	end);

	SB.addCommand("prefixless", "run HttpLocal", "%w+/url", { "httplocal", "hl", "rhl" }, function(player, code)
		SB.runCode(player, "HttpLocal", code, player.Character);
	end);

	SB.addCommand("prefixless", "run HttpLocalTo", "%w+/player1,player2/url", { "httplocalto", "hlt", "rlth" }, function(player, argString)
		local playerArgs = string.split(argString:sub(1, argString:find("/") - 1), ","); -- Seperates players by the delimiter ","
		local urlPassed = argString:sub(argString:find("/") + 1); -- Gets url of script
		for _, playerObject in pairs(Players:GetPlayers()) do
			for i = 1, #playerArgs do
				local playerSelected = playerArgs[i];
				if playerObject.Name:lower():match(playerSelected) then
					SB.runCode(player, "HttpLocal", urlPassed, playerObject.Character);
				end;
			end;
		end;
	end);

	--[[
		TODO: In the future make this command
		work on any model from anyone as long
		as it is public
	]]
	SB.addCommand("prefixless", "insert", "%w+/assetId", { "insert", "ins", "i" }, function(player, assetId)
		local success, model = pcall(function()
			return InsertService:LoadAsset(assetId);
		end);

		if success then
			model.Parent = workspace;
			table.insert(SB.Sandbox.CreatedInstances, model);
			handleOutput(player, "general", "Inserted assetid: " .. assetId);
		else
			handleOutput(player, "error", "Failed to insert model - make sure it is public");
		end;
	end);

	-- Initialize get commands
	SB.addCommand("g", "help", "%w+", { "help", "h" }, function(player)
		local prefixlessTable, GCommands = {}, {};
		for _, command in pairs(SB.Commands.Commands) do
			if not prefixlessTable[command.Name] then
				prefixlessTable[command.Name] = command.Name .. " - ";
			end;

			prefixlessTable[command.Name] = prefixlessTable[command.Name] .. " " .. command.Usage .. ",";
		end;

		for index, command in pairs(SB.Commands.GCommands) do
			if index:find("/%w+") then
				index = index:sub(1, index:find("/%w+") - 1);
			end;

			if not GCommands[command.Name] then
				GCommands[command.Name] = command.Name .. " - ";
			end;

			GCommands[command.Name] = GCommands[command.Name] .. " " .. command.Usage .. ",";
		end;

		handleOutput(player, "general", "General commands");

		for _, command in pairs(prefixlessTable) do
			handleOutput(player, "print", command:sub(1, command:len() - 1));
		end;

		handleOutput(player, "general", "Get commands");

		for _, command in pairs(GCommands) do
			handleOutput(player, "print", command:sub(1, command:len() - 1));
		end;
	end);

	SB.addCommand("g", "no scripts", "%w+", {"ns", "nos", "noscripts"}, function(player)
		SB.killScripts(player);
	end);

	SB.addCommand("g", "no scripts all", "%w+/all", {"noscripts/all", "ns/all", "nos/all"}, function(player)
		SB.killScripts(player, "all");
	end);

	SB.addCommand("g", "no locals all", "%w+/all", {"nl/all", "nolocal/all", "nol/all"}, function(player)
		ClientToServerRemote:FireAllClients({
			['Handler'] = "nl/all",
			['Player'] = player,
		});
	end);

	SB.addCommand("g", "no locals", "%w+", { "nl", "nol", "nolocal" }, function(player)
		ClientToServerRemote:FireClient(player, {
			['Handler'] = "nl",
		});
	end);

	SB.addCommand("g", "walkspeed", "%w+/number", { "ws/%w+", "walkspeed/%w+" }, function(player, commandArg)
		if player.Character and player.Character:FindFirstChild("Humanoid") then
			player.Character.Humanoid.WalkSpeed = tonumber(commandArg);
		end;
	end);

	SB.addCommand("g", "base", "%w+", { "b", "base", "bs" }, function()
		if currentBase then
			currentBase:Destroy();
		end;

		currentBase = BaseplateTemplate:Clone();
		currentBase.Parent = workspace;
	end);

	SB.addCommand("g", "no base", "%w+", { "nb", "nobase" }, function()
		if currentBase then
			currentBase:Destroy();
		end;
	end);

	SB.addCommand("g", "clear", "%w+", { "c", "cl", "clean", "clear" }, function()
		for i = 1, #SB.Sandbox.CreatedInstances do
			-- The instance might already be destroyed
			-- so we have to pcall it
			pcall(function()
				SB.Sandbox.CreatedInstances[i]:Destroy();
			end);
		end;

		-- Clear the table so that way it will
		-- not cause a memory leak
		SB.Sandbox.CreatedInstances = {};
	end);

	SB.addCommand("g", "clear terrain", "%w+", { "cleart", "clearterrain", "ct" }, function()
		workspace:FindFirstChildOfClass("Terrain"):Clear();
	end);

	SB.addCommand("g", "reset", "%w+", { "r", "reset" }, function(player)
		player:LoadCharacter();
	end);

	SB.addCommand("g", "stationary reset", "%w+", { "sr", "superreset", "sreset" }, function(player)
		local cframe = player.Character and
						player.Character:FindFirstChild("HumanoidRootPart") and
						player.Character.HumanoidRootPart.CFrame or BaseplateTemplate.CFrame + Vector3.new(0, 5, 0);
		player:LoadCharacter();
		player.Character:WaitForChild("HumanoidRootPart").CFrame = cframe;
	end);

	SB.addCommand("g", "no tools", "%w+", { "nt", "not", "notools" }, function(player)
		player.Backpack:ClearAllChildren();
	end);

	SB.addCommand("g", "no teams", "%w+", { "noteams", "noteam" }, function()
		for _, team in pairs(Teams:GetTeams()) do
			pcall(function()
				team:Destroy();
			end);
		end;
	end);

	SB.addCommand("g", "no sky", "%w+", { "noskies", "nosky" }, function()
		for _, object in pairs(Lighting:GetChildren()) do
			if object.ClassName == "Sky" then
				pcall(function()
					object:Destroy();
				end);
			end;
		end;
	end);

	SB.addCommand("g", "nil", "%w+", { "nil", "nilchar", "nilcharacter" }, function(player)
		player.Character:Destroy();
	end);

	SB.addCommand("g", "no forcefield", "%w+", { "noff", "nff", "noforcefield" }, function(player)
		for _, object in pairs(player.Character:GetChildren()) do
			if object.ClassName == "ForceField" then
				pcall(function()
					object:Destroy();
				end);
			end;
		end;
	end);

	SB.addCommand("g", "public", "%w+", { "public", "pub" }, function(player)
		TeleportService:Teleport(game.PlaceId, player);
	end);

	SB.addCommand("g", "R6", "%w+", "r6", function(player)
		local humanoidDescription = Players:GetHumanoidDescriptionFromUserId(player.UserId);
		local character = HelperAssets.CharacterModels.R6:Clone();
		local humanoid = character.Humanoid;

		character.PrimaryPart = character.HumanoidRootPart;
		character.Name = player.Name;

		character:SetPrimaryPartCFrame(player.Character:GetPrimaryPartCFrame());

		player.Character.Parent = nil;
		player.Character = character;

		character.Parent = workspace;
		humanoid:ApplyDescription(humanoidDescription);
	end);

	SB.addCommand("g", "R15", "%w+", "r15", function(player)
		local humanoidDescription = Players:GetHumanoidDescriptionFromUserId(player.UserId);
		local character = HelperAssets.CharacterModels.R15:Clone();
		local humanoid = character.Humanoid;

		character.PrimaryPart = character.HumanoidRootPart;
		character.Name = player.Name;

		character:SetPrimaryPartCFrame(player.Character:GetPrimaryPartCFrame());

		player.Character.Parent = nil;
		player.Character = character;

		character.Parent = workspace;
		humanoid:ApplyDescription(humanoidDescription);
	end);

	SB.addCommand("g", "rejoin", "%w+", { "rejoin", "rj" }, function(player)
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, player);
	end);

	SB.addCommand("g", "teleport", "%w+/name", { "tp/%w+", "teleport/%w+" }, function(player, commandArg)
		for _, findPlayer in pairs(Players:GetPlayers()) do
			if findPlayer.Name:lower():match(commandArg) then
				local cframe = findPlayer.Character:GetPrimaryPartCFrame();
				if cframe then
					player.Character:SetPrimaryPartCFrame(cframe + Vector3.new(0, 5, 0));
				end;
			end;
		end;
	end);

	SB.addCommand("g", "forcefield", "%w+", { "ff", "forcefield" }, function(player)
		Instance.new("ForceField", player.Character);
	end);

	SB.addCommand("g", "heal", "%w+", "heal", function(player)
		player.Character.Humanoid.Health = player.Character.Humanoid.MaxHealth;
	end);

	SB.addCommand("g", "jump power", "%w+/number", { "jumppower/%w+", "jp/%w+" }, function(player, power)
		player.Character.Humanoid.JumpPower = tonumber(power) or 50;
	end);

	SB.addCommand("g", "join", "%w+/name", { "j/%w+", "join/%w+" }, function(player, followName)
		local userId = Players:GetUserIdFromNameAsync(followName);
		if userId then
			local success, found, placeId, jobId = pcall(function()
				return TeleportService:GetPlayerPlaceInstanceAsync(userId);
			end);

			if success and found then
				TeleportService:TeleportToPlaceInstance(game.PlaceId, jobId, player);
			else
				handleOutput(player, "error", "Error: player not found in a server.");
			end;
		end;
	end);

	SB.addCommand("g", "wall", "%w+", { "wall", "w" }, function()
		--[[
			This command is primarily based off of
			Pkamara's wall command from his script builder,
			located: https://github.com/MathematicalDessert/Script-Builder/blob/master/Server.lua
		]]

		if #currentWalls == 4 then
			for _, wall in pairs(currentWalls) do
				wall:Destroy();
			end;

			currentWalls = {};
		end;

		for i = 1, 4 do
			local exists = currentBase:FindFirstChild("Wall_" .. i);
			if exists then
				exists:Destroy();
			end;

			local Wall = Instance.new("Part");
			Wall.CastShadow = false;
			Wall.Locked = true;
			Wall.Anchored = true;
			Wall.Material = currentBase.Material;
			Wall.Name = "Wall_" .. i;
			Wall.Locked = true;
			Wall.Color = currentBase.Color;
			Wall.Size = Vector3.new(currentBase.Size.X, currentBase.Size.Y * 100, currentBase.Size.Y);
			Wall.CFrame = CFrame.Angles(0, math.rad(90 * i), 0) *
							CFrame.new(0, currentBase.Position.Y + ((Wall.Size.Y / 2) + (currentBase.Size.Y / 2)), (currentBase.Size.Z / 2) + (currentBase.Size.Y / 2));
			Wall.Parent = currentBase;

			table.insert(currentWalls, Wall);
		end;
	end);

	SB.addCommand("g", "no walls", "%w+", { "nowalls", "nowall", "nwl", "nw" }, function()
		for _, wall in pairs(currentWalls) do
			wall:Destroy();
		end;
	end);

	SB.addCommand("g", "fix lighting", "%w+", { "fixl", "fixlighting", "fl" }, function()
		for index, value in pairs(LightingSettings) do
			Lighting[index] = value;
		end;
	end);

	SB.addCommand("g", "debug", "%w+", { "debug", "deb", "db" }, function()
		for _, object in pairs(workspace:GetDescendants()) do
			if object.ClassName == "Message" or object.ClassName == "Hint" then
				pcall(function()
					object:Destroy();
				end);
			end;
		end;
	end);

	SB.addCommand("g", "dummy", "%w+/amount", { "dummy/%w+", "dum/%w+", "d/%w+", "dummy", "dum", "d" }, function(player, num)
		num = tonumber(num);
		if num then
			if num > 20 then
				handleOutput(player, "warn", "The number of dummies has been limited to 20.");
				num = 20;
			end;

			for i = 1, num do
				createDummy(player, "R6");
			end;
		else
			createDummy(player, "R6");
		end;
	end);

	SB.addCommand("g", "R15 dummy", "%w+/amount", { "rdummy/%w+", "rdum/%w+", "rd/%w+", "rdummy", "rdum", "rd" }, function(player, num)
		num = tonumber(num);
		if num then
			if num > 20 then
				handleOutput(player, "warn", "The number of dummies has been limited to 20.");
				num = 20;
			end;

			for i = 1, num do
				createDummy(player, "R15");
			end;
		else
			createDummy(player, "R15");
		end;
	end);

	SB.addCommand("g", "camera fix", "%w+", { "fixc", "fixcamera", "fixcam", "fc" }, function(player)
		Script.Essentials.Scripts.FixCamera:Clone().Parent = player.Character;
	end);

	local function joinHandler(player)
		-- Create the Console
		local guiClone = ConsoleGui:Clone();
		guiClone.Parent = player.PlayerGui;

		-- Create the client handler
		local clone = ClientHandler:Clone();
		clone.Parent = player.PlayerGui;
		clone.Disabled = false;

		-- Protect the objects
		SB.Sandbox.addProtectedObject(clone);
		SB.Sandbox.addProtectedObject(guiClone);

		player.Chatted:Connect(function(message)
			SB.handleCommand(player, message);
		end);
	end;

	local function leaveHandler(player)
		SB.killScripts(player);
	end;

	for _,plr in pairs(Players:GetPlayers()) do
		joinHandler(plr);
	end;

	Players.PlayerAdded:Connect(joinHandler);
	Players.PlayerRemoving:Connect(leaveHandler);

	ScriptContext.Error:Connect(function(message, trace, scriptInstance)
		local config = indexedScripts[scriptInstance];
		if config then
			local trace = string.split(trace, "\n"); -- split values from the trace of the error
			local stack = {}; -- actual stack trace we will send to client
			table.remove(trace, #trace); -- Removes the last trailing element that is nil

			ClientToServerRemote:FireClient(config.Owner, {
				['Handler'] = "Output",
				['Type'] = "error",
				['Message'] = message
			});

			for _, value in pairs(trace) do
				if value ~= nil and not (value:match(scriptInstance:GetFullName()) or value:match("Workspace.Script") or value:match("MainModule.Essentials.Sandbox")) then
					table.insert(stack, value);
				end;
			end;

			ClientToServerRemote:FireClient(config.Owner, {
				['Handler'] = "Output",
				['Type'] = "error",
				['Message'] = stack
			});

			indexedScripts[scriptInstance] = nil;
			scriptInstance:Destroy();
		end;
	end);
end;

-- Returns the initializer function
return function(settings)
	-- Settings will typically only be set by power users of the project,
	-- default settings also work but the option is still available
	-- for those who don't want to edit the scripts.
	if settings ~= nil then
		-- Assign SB.Settings to settings
		SB.Settings = settings;
	end;

	-- Configure settings internally
	SB.Settings.PLACE_NAME = PLACE_INFO and PLACE_INFO.Name or "Script Builder";

	-- Register server with backend (if not running in Studio)
	if not RunService:IsStudio() then
		local req = HttpService:RequestAsync({
			Url = SB.Settings.API_BASE_URL .. "/api/registerServer",
			Method = "POST",
			Body = HttpService:JSONEncode({
				["jobId"] = game.JobId,
				["GUID"] = ServerGUID
			}),
		});

		if req.StatusCode ~= 200 then
			print(req.Body, req.StatusCode);
		end;
	end;

	-- Initialize the script builder
	init();

	return SB;
end;