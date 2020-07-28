local Players = game:GetService("Players");
local HttpService = game:GetService("HttpService");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ScriptContext = game:GetService("ScriptContext");
local RunService = game:GetService("RunService");
local MarketplaceService = game:GetService("MarketplaceService");

local PLACE_INFO = MarketplaceService:GetProductInfo(game.PlaceId);

local ClientHandler = script.ClientScripts.ClientHandler:Clone();
local ConsoleGui = script.ClientEssentials.Gui.Console:Clone();

local SB = {};
SB.Settings = {}; -- Stores settings (such as API url, etc)
SB.Sandbox = require(script.Essentials.Sandbox); -- Allows indexing of the public members of the sandbox

-- these will be returned in sandboxed
-- scripts to prevent potential for
-- people to overwrite the script
-- builder tables in _G
_G.sandboxedShared = {};
_G.sandboxedG = {};

local indexedScripts = {};

-- Our default baseplate to restore to
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

local ClientToServerRemote, ClientToServerRemoteFunction;

local function getConfig(_, arg)
    if arg == "PLACE_NAME" then
        return SB.Settings.PLACE_NAME;
    end;
end;

local function recreateRemote()
    if not ReplicatedStorage:FindFirstChild("SB_Config") then
        ClientToServerRemoteFunction = Instance.new("RemoteFunction");
        ClientToServerRemoteFunction.Name = "SB_Config";
        ClientToServerRemoteFunction.Parent = ReplicatedStorage;

        SB.Sandbox.addObjectToProtectedList(ClientToServerRemoteFunction);

        ClientToServerRemoteFunction.OnServerInvoke = getConfig;
    end;

    if not ReplicatedStorage:FindFirstChild("SB_Remote") then
        ClientToServerRemote = Instance.new("RemoteEvent");
        ClientToServerRemote.Name = "SB_Remote";
        ClientToServerRemote.Parent = ReplicatedStorage;

        SB.Sandbox.addObjectToProtectedList(ClientToServerRemote);

        ClientToServerRemote.OnServerEvent:connect(function(player, command)
            if command == "NewGui" then
                -- Create a fresh Console gui
                local guiClone = ConsoleGui:Clone();
                guiClone.Parent = player.PlayerGui;

                -- Add it to the sandbox to prevent indexing
                SB.Sandbox.addObjectToProtectedList(guiClone);
            else
                SB.handleCommand(player, command);
            end;
        end);
    end;
end;

-- Prevent destroying the remote
RunService.Heartbeat:Connect(function()
    if not ReplicatedStorage:FindFirstChild("SB_Remote") or not ReplicatedStorage:FindFirstChild("SB_Config") then
        recreateRemote();
    end;
end);

function SB.runCode(player, type, source, parent)
    if type == "HttpServer" or type == "HttpLocal" then
        local success, code = pcall(function()
            return HttpService:GetAsync(source, false);
        end);

        if success then
            if type == "HttpServer" then
                return SB.runCode(player, "Server", code);
            end;
            return SB.runCode(player, "Local", code);
        else
            shared("Output", {
                Owner = player,
                Type = "error",
                Message = "Failed to get script. If you are a place owner, check output."
            });

            warn("HTTPService:GetAsync() failed with reason:", code);
        end;
    elseif type == "Server" then
        local Script = script.Scripts.Script:Clone();
        indexedScripts[Script] = {
            Source = source,
            Owner = player,
            Script = Script,
            SandboxInstance = {},
        };

        Script.Parent = parent or workspace;
        Script.Disabled = false;

        return Script;
    elseif type == "Local" then
        -- TODO: implement locals
    end;
end;

-- Initialize script builder internals
setmetatable(shared, {
    __call = (function(_, arg, ...)
        local args = {...};
        if arg == "Sandbox" then
            -- Return the sandbox
            return SB.Sandbox;
        elseif arg == "runScript" then
            assert(typeof(args[1]) == "string", "Expected a string when calling shared(\"runScript\") arg #1");
            assert(typeof(args[2]) == "Instance", "Expected a Instance when calling shared(\"runScript\") arg #2");
            assert(typeof(args[3]) == "Instance", "Expected a Instance when calling shared(\"runScript\") arg #3");

            local code, parent, player = args[1], args[2], args[3];
            return SB.runCode(player, "Server", code, parent);
        elseif arg == "Output" and args[1] then
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
        elseif typeof(arg) == "Instance" and arg.ClassName == "Script" then
            if indexedScripts[arg] then
                return indexedScripts[arg];
            end;
        end;
    end),

    __metatable = "The metatable is locked"
});

function SB.killScripts(player, command)
    if player and command then
        shared("Output", {
            Type = "general",
            Message = "g/ns/all from " .. player.Name
        });
    end;

    for index, tbl in pairs(indexedScripts) do
        if tbl.Owner == player and command ~= "all" then
            SB.Sandbox.kill(tbl.Script);
        else
            SB.Sandbox.kill(tbl.Script);
        end

        -- Destroy the script object
        tbl.Script:Destroy();
        indexedScripts[index] = nil;
    end;
end;

function SB.handleCommand(player, commandString)
    local commonSub = commandString:sub(1, 2); -- Most commands rely on this specific sub - so cache it temporarily
    if commonSub == "c/" then
        SB.runCode(player, "Server", commandString:sub(3));
    elseif commonSub == "l/" then
        SB.runCode(player, "Local", commandString:sub(3));
    elseif commonSub == "h/" then
        SB.runCode(player, "HttpServer", commandString:sub(3));
    elseif commandString:sub(1, 3) == "hl/" then
        SB.runCode(player, "HttpLocal", commandString:sub(4));
    elseif commonSub == "g/" then
        local commands = commandString:sub(3):split(" "); -- split the command into pieces
        for _, command in pairs(commands) do
            if command == "ns" then
                SB.killScripts(player);
            end;

            if command == "ns/all" then
                SB.killScripts(player, "all");
            end;

            if command == "nl/all" then
                ClientToServerRemote:FireAllClients({
                    ['Handler'] = "nl/all",
                    ['Player'] = player,
                });
            end;

            if command == "nl" then
                ClientToServerRemote:FireClient(player, {
                    ['Handler'] = "nl",
                });
            end;

            if command == "c" then
                for _, player in pairs(Players:GetPlayers()) do
                    player:LoadCharacter();
                end;

                local Instances = SB.Sandbox.returnCreatedInstances();
                for i, instance in pairs(Instances) do
                    -- The instance might already be destroyed
                    -- so we have to pcall it
                    pcall(function()
                        instance:Destroy();
                    end);

                    -- Remove the instance from the table to
                    -- free up memory
                    table.remove(Instances, i);
                end;
            end;

            if command == "r" then
                player:LoadCharacter();
            end;

            if command == "sr" then
                local cframe = player.Character and 
                                player.Character:FindFirstChild("HumanoidRootPart") and
                                player.Character.HumanoidRootPart.CFrame or BaseplateTemplate.CFrame + Vector3.new(0, 5, 0);
                player:LoadCharacter();
                player.Character:WaitForChild("HumanoidRootPart").CFrame = cframe;
            end;

            if command:match("ws/%w+") then
                if player.Character and player.Character:FindFirstChild("Humanoid") then
                    player.Character.Humanoid.WalkSpeed = tonumber(command:sub(4));
                end;
            end;

            if command == "b" then
                if workspace:FindFirstChild("Base") then
                    workspace.Base:Destroy();
                end;

                BaseplateTemplate:Clone().Parent = workspace;
            end;
        end;
    end;
end;

function SB.joinHandler(player)
    -- Create the Console
    local guiClone = ConsoleGui:Clone();
    guiClone.Parent = player.PlayerGui;

    -- Create the client handler
    local clone = ClientHandler:Clone();
    clone.Parent = player.PlayerGui;
    clone.Disabled = false;

    -- Protect the objects
    SB.Sandbox.addObjectToProtectedList(clone);
    SB.Sandbox.addObjectToProtectedList(guiClone);

    player.Chatted:Connect(function(message)
        SB.handleCommand(player, message);
    end);
end;

function SB.leaveHandler(player)
    SB.killScripts(player);
end;

for _,plr in pairs(Players:GetPlayers()) do
    SB.joinHandler(plr);
end;

Players.PlayerAdded:Connect(SB.joinHandler);
Players.PlayerRemoving:Connect(SB.leaveHandler);

ScriptContext.Error:Connect(function(message, trace, scriptInstance)
    local message = message:gsub("Workspace.Script:%w+: ", "");
    local config = indexedScripts[scriptInstance];
    if config then
        ClientToServerRemote:FireClient(config.Owner, {
            ['Handler'] = "Output",
            ['Type'] = "error",
            ['Message'] = message,
        });

        indexedScripts[scriptInstance] = nil;
    end;
end);

return function(settings)
    assert(typeof(settings) == "table", "Expected table when instantiating script builder.");
    assert(settings.API_URL, "Expected API_URL to be a string when instantiating script builder with given settings.");
    
    SB.Settings = settings;

    -- Configure settings internally
    SB.Settings.PLACE_NAME = PLACE_INFO.Name or "Script Builder";

    return SB;
end;