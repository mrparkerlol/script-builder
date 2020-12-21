--[[
	Written by Jacob (mrparkerlol on Github), with contributions by others.

	This is the client manager source for the Script Builder Project,
	licensed GPL V3 only.

	This is provided free of charge, no warranty or liability
	provided. Use of this project is at your own risk.

	Documentation is also provided on Github, if needed.
]]

wait();
script.Parent = nil;
script:Destroy();
script = nil;

print("Initializing client manager");

local Players = game:GetService("Players");
local ReplicatedStorage = game:GetService("ReplicatedStorage");
local ScriptContext = game:GetService("ScriptContext");
local ContextActionService = game:GetService("ContextActionService");
local StarterGui = game:GetService("StarterGui");
local TweenService = game:GetService("TweenService");
local TextService = game:GetService("TextService");

local PLACE_NAME = ReplicatedStorage:WaitForChild("SB_Config"):InvokeServer("PLACE_NAME");

local LocalPlayer = Players.LocalPlayer;

local MessageFrame = Instance.new("Frame");
MessageFrame.BackgroundTransparency = 1;
MessageFrame.Size = UDim2.new(0,50,0,20);

local TextLabel = Instance.new("TextBox", MessageFrame);
TextLabel.BackgroundTransparency = 1;
TextLabel.Size = UDim2.new(0,50, 0,20);
TextLabel.Font = Enum.Font.SourceSans;
TextLabel.FontSize = 6;
TextLabel.TextXAlignment = Enum.TextXAlignment.Left;
TextLabel.TextEditable = false;
TextLabel.ClearTextOnFocus = false;
TextLabel.Name = "Message";

local TimeLabel = Instance.new("TextLabel");
TimeLabel.BackgroundTransparency = 1;
TimeLabel.Size = UDim2.new(0,50, 0,20);
TimeLabel.Font = Enum.Font.SourceSans;
TimeLabel.FontSize = 6;
TimeLabel.TextXAlignment = Enum.TextXAlignment.Left;
TimeLabel.ClipsDescendants = true
TimeLabel.Name = 'Time'
TimeLabel.TextColor3 = Color3.fromRGB(197, 197, 197)
TimeLabel.TextYAlignment = Enum.TextYAlignment.Top

local ProtectedObjects = {};

local indexedScripts = {};

local ConsoleGui = LocalPlayer.PlayerGui:WaitForChild("Console");
local ConsoleMain = ConsoleGui:WaitForChild("Main");
local CommandLine = ConsoleMain:WaitForChild("Command"):WaitForChild("CommandLine");
local OutputFrame = ConsoleMain:WaitForChild("Output");
local OutputLayout = OutputFrame:WaitForChild("UIListLayout");

local function tween(instance, info, goal)
	local info = TweenInfo.new(info[1], Enum.EasingStyle[info[2]], Enum.EasingDirection[info[3]], info[4], info[5], info[6]);
	local tween = TweenService:Create(instance, info, goal);

	tween:Play();

	return tween;
end;

local function handleOutput(message, color)
	if typeof(message) == "table" then
		for i = 1, #message do
			handleOutput(message[i], color);
		end;
	else
		local message = "" .. (message == "" and "nil" or message);
		local frame = MessageFrame:Clone();
		local PrintText = frame.Message;

		PrintText.TextColor3 = color;
		PrintText.Text = message;
		PrintText.Parent = frame;

		frame.Parent = OutputFrame;

		PrintText.Size = UDim2.new(0,PrintText.TextBounds.X, 0,PrintText.TextBounds.Y);
		PrintText.AnchorPoint = Vector2.new(1,0);
		PrintText.Position = UDim2.new(1,0,0,0);

		frame.Size = UDim2.new(0,PrintText.TextBounds.X+7,0,PrintText.TextBounds.Y);

		local currentTime = os.date('*t', os.time());
		currentTime = string.format('%s:%s:%s', currentTime.hour, currentTime.min, currentTime.sec);

		local originalSize = frame.Size;
		local timeSize = TextService:GetTextSize(currentTime, 18, Enum.Font.SourceSans, Vector2.new(1000, originalSize.Y.Offset));

		local timeLabel = TimeLabel:Clone();
		timeLabel.Size = UDim2.new(0,0,1,0);
		timeLabel.Text = currentTime;
		timeLabel.Parent = frame;

		frame.MouseEnter:Connect(function()
			tween(frame, {0.2, 'Quad', 'InOut', 0, false, 0}, {
				Size = UDim2.new(0,originalSize.X.Offset + timeSize.X, 0,originalSize.Y.Offset)
			});

			tween(timeLabel, {0.2, 'Quad', 'InOut', 0, false, 0}, {
				Size = UDim2.new(0,timeSize.X, 1, 0)
			});
		end);

		frame.MouseLeave:Connect(function()
			tween(frame, {0.4, 'Quad', 'InOut', 0, false, 0}, {
				Size = UDim2.new(0,originalSize.X.Offset, 0, originalSize.Y.Offset)
			});

			tween(timeLabel, {0.4, 'Quad', 'InOut', 0, false, 0}, {
				Size = UDim2.new(0, 0, 1, 0)
			});
		end);

		local AbsoluteContentSize = OutputLayout.AbsoluteContentSize;

		local bottomScrollVisible = OutputFrame.CanvasSize.X.Offset > OutputFrame.AbsoluteSize.X and 5 or 0; -- Offset by 5 to account for bottom scrollbar
		local scrollBottom = OutputFrame.CanvasPosition.Y + 5 >= math.max(0, OutputFrame.CanvasSize.Y.Offset - OutputFrame.AbsoluteSize.Y + bottomScrollVisible);

		OutputFrame.CanvasSize = UDim2.new(0,AbsoluteContentSize.X + 5, 0,AbsoluteContentSize.Y);

		if scrollBottom and OutputFrame.CanvasSize.Y.Offset > OutputFrame.AbsoluteSize.Y then
			OutputFrame.CanvasPosition = Vector2.new(0, OutputLayout.AbsoluteContentSize.Y);
		end;
	end;
end;

local function ConfigureGui()
	-- Events
	CommandLine.FocusLost:connect(function(enterPressed, key)
		if enterPressed then
			local msg = CommandLine.Text;
			CommandLine.Text = "";

			ReplicatedStorage:WaitForChild("SB_Remote"):FireServer(msg);
		end;
	end);

	handleOutput("Welcome to " .. PLACE_NAME .. "! Enjoy your stay here!", Color3.fromRGB(0, 255, 0));
end;

ConfigureGui();

-- Listen for ' key press
ContextActionService:BindAction("CommandBarListener", function(actionName, userInputState, inputObject)
	if userInputState == Enum.UserInputState.End then
		CommandLine:CaptureFocus();
	end;
end, false, Enum.KeyCode.Quote);

ConsoleGui.Changed:Connect(function(property)
	if property == "Parent" then
		if ConsoleGui.Parent == nil then
			-- Request the server to give us a new gui
			ReplicatedStorage:WaitForChild("SB_Remote"):FireServer("NewGui");

			-- Wait for it to insert
			ConsoleGui = LocalPlayer:FindFirstChild("PlayerGui") and LocalPlayer.PlayerGui:WaitForChild("Console");
			ConsoleMain = ConsoleGui and ConsoleGui:WaitForChild("Main");
			CommandLine = ConsoleMain and ConsoleMain:WaitForChild("Command"):WaitForChild("CommandLine");
			OutputFrame = ConsoleMain and ConsoleMain:WaitForChild("Output");

			if ConsoleGui then
				ConfigureGui();
			end;
		end;
	end;
end);

local function handleRemote()
	ReplicatedStorage:WaitForChild("SB_Remote").OnClientEvent:Connect(function(tbl)
		if tbl.Handler == "nl/all" then
			for index, tbl in pairs(indexedScripts) do
				tbl.Disabled = true;
				indexedScripts[index] = nil;
			end;

			handleOutput("Got nl/all from Player: " .. tbl.Player.Name, Color3.fromRGB(0, 250, 0));
		elseif tbl.Handler == "nl" then
			for index, tbl in pairs(indexedScripts) do
				tbl.Disabled = true;
				indexedScripts[index] = nil;
			end;
		elseif tbl.Handler == "Output" then
			if tbl.Type == "print" then
				handleOutput(tbl.Message, Color3.fromRGB(255, 255, 255));
			elseif tbl.Type == "warn" then
				handleOutput(tbl.Message, Color3.fromRGB(251, 255, 0));
			elseif tbl.Type == "error" then
				handleOutput(tbl.Message, Color3.fromRGB(255, 0, 0));
			elseif tbl.Type == "general" then
				handleOutput(tbl.Message, Color3.fromRGB(0, 255, 0));
			end;
		elseif tbl.Handler == "PromptLocal" then
			pcall(function()
				local SetCoreBindable = Instance.new("BindableFunction");
				function SetCoreBindable.OnInvoke(arg)
					if arg == "Yes" then
						ReplicatedStorage:WaitForChild("SB_Remote"):FireServer("yesLocal", tbl.GUID);
					end;
				end;

				StarterGui:SetCore("SendNotification", {
					Title = "LocalScript wants to run",
					Text = "Player " .. tbl.Player.Name .. " wants to run a local script on you!\nSelect yes to run, no to not run.",
					Button1 = "Yes",
					Button2 = "No",
					Callback = SetCoreBindable
				});
			end);
		end;
	end);

	local ClientConfigRemote = ReplicatedStorage:WaitForChild("SB_Config");
	function ClientConfigRemote.OnClientInvoke(tbl)
		if tbl.Handler == "LocalScript" then
			indexedScripts[tbl.LocalScript] = {
				owner = LocalPlayer,
				Disabled = false,
			};
		end;
	end;
end;

ReplicatedStorage.ChildAdded:Connect(function(child)
	-- TODO: potentially protect from malicious
	-- remotes from being created by receiving
	-- instance from server
	if child.Name == "SB_Remote" then
		handleRemote();
	end;
end);

handleRemote();

local function lightWrapper(wrappedObjects, object, index)
	if wrappedObjects[index] or wrappedObjects[object] then
		return wrappedObjects[index] or wrappedObjects[object];
	end;

	if ProtectedObjects[object] then
		return nil;
	elseif object == ReplicatedStorage or object == LocalPlayer then
		local proxy = newproxy(true);
		local mt = getmetatable(proxy);
		function mt.__index(_, index)
			local success, indexed = pcall(function()
				return object[index];
			end);

			if success then
				if typeof(indexed) == "Instance" then
					return lightWrapper(wrappedObjects, object);
				end;

				return indexed;
			else
				return error(indexed, 3);
			end;
		end;

		function mt.__newindex(_, index, value)
			local success, message = pcall(function()
				object[index] = wrappedObjects[value] or value;
			end);

			if not success then
				return error(message, 3);
			end;
		end;

		function mt.__tostring()
			return tostring(object);
		end;

		mt.__metatable = getmetatable(object);

		wrappedObjects[object] = proxy;
		wrappedObjects[proxy] = object;

		return proxy;
	elseif index == "print" or index == "warn" then
		local func = function(...)
			-- Make the args a table
			local args = {...};

			-- Iterate through the arguments, convert them to a string
			for i=1, #args do
				args[i] = tostring(args[i]);
			end;

			-- Concatenate the strings together,
			-- using a space as a delimiter
			local printString = table.concat(args, " ");

			-- Send the string to the output
			shared("Output", {
				Type = index,
				Message = printString
			});
		end;

		wrappedObjects[index] = func;
		return func;
	end;

	return object;
end;

local function getEnvironment(config, environment)
	local wrappedObjects = {};

	return setmetatable({}, {
		__index = (function(_, index)
			if config.Disabled then
				wrappedObjects = nil;
				return error("Script disabled", 2);
			end;

			local indexed = environment[index];
			return lightWrapper(wrappedObjects, indexed, index);
		end),

		__metatable = "The metatable is locked"
	});
end;

ScriptContext.Error:Connect(function(message, trace, Script)
	if OutputFrame then
		if indexedScripts[Script] then
			handleOutput(message:gsub(".LSource", ""), Color3.new(255, 0, 0));

			local newTrace = string.split(trace, "\n");
			table.remove(newTrace, #newTrace) -- removes the trailing nil value
			for i = 1, #newTrace do
				if not newTrace[i]:match("LSource") then
					table.remove(newTrace, i);
				else
					newTrace[i] = newTrace[i]:gsub(".LSource", "");
				end;
			end;

			handleOutput(newTrace, Color3.new(255, 0, 0));

			delay(1, function()
				Script:Destroy()
			end);

			indexedScripts[Script] = nil;
		end;
	end;
end);

setmetatable(shared, {
	__call = (function(_, arg, options)
		if arg == "Output" then
			if typeof(options) == "table" and options.Type and options.Message then
				if options.Type == "print" then
					handleOutput(options.Message, Color3.fromRGB(255, 255, 255));
				elseif options.Type == "warn" then
					handleOutput(options.Message, Color3.fromRGB(251, 255, 0));
				elseif options.Type == "general" then
					handleOutput(options.Message, Color3.fromRGB(0, 255, 0));
				end;
			end;
		elseif typeof(arg) == "Instance" and typeof(options) == "table" then
			if arg.ClassName == "LocalScript" then
				if indexedScripts[arg] then
					indexedScripts[arg].environment = getEnvironment(indexedScripts[arg], options);
					return indexedScripts[arg];
				end;
			end;
		end;
	end),

	__metatable = "The metatable is locked"
});

print("Initialized client handler");