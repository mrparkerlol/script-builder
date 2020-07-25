wait();
script.Parent = nil;
script:Destroy();
script = nil;

print("Initializing client manager");

local Players              = game:GetService("Players");
local ReplicatedStorage    = game:GetService("ReplicatedStorage");
local ScriptContext        = game:GetService("ScriptContext");
local ContextActionService = game:GetService("ContextActionService");

local LocalPlayer = Players.LocalPlayer;

local TextLabel = Instance.new("TextLabel");
TextLabel.BackgroundTransparency = 1;
TextLabel.Size = UDim2.new(0,531, 0,20);
TextLabel.Font = Enum.Font.SourceSans;
TextLabel.FontSize = 6;
TextLabel.TextXAlignment = Enum.TextXAlignment.Left;

_G.fakeGTable = {};
_G.fakeSharedTable = {};
local hiddenItems = {};

local indexedScripts = {};

local ConsoleGui = LocalPlayer.PlayerGui:WaitForChild("Console");
local ConsoleMain = ConsoleGui:WaitForChild("Main");
local CommandLine = ConsoleMain:WaitForChild("CommandLine");
local OutputFrame = ConsoleMain:WaitForChild("Output");

local function handleOutput(message, color)
  local PrintText = TextLabel:Clone();
  PrintText.TextColor3 = color;
  PrintText.Text = (message == "" and "nil") or message;
  PrintText.Parent = OutputFrame;
  PrintText.Size = UDim2.new(0,PrintText.TextBounds.X, 0,PrintText.TextBounds.Y);
end;

local function ConfigureGui()
  local currentChildren = 0;
  local currentHeight, currentWidth = 0, 0;

  -- Events
  CommandLine.FocusLost:connect(function(enterPressed, key)
    if enterPressed then
      local msg = CommandLine.Text;
      CommandLine.Text = "";

      ReplicatedStorage:WaitForChild("SB_Remote"):FireServer(msg);
    end;
  end);

  OutputFrame.ChildAdded:connect(function(child)
    if child.ClassName == "TextLabel" then
      child.Position = UDim2.new(0,0, 0,currentHeight + 10);
      
      currentHeight = currentHeight + child.TextBounds.Y;
      if child.TextBounds.X > currentWidth then
        currentWidth = child.TextBounds.X
      end;

      OutputFrame.CanvasSize = UDim2.new(0, currentWidth, 0,currentHeight);

      if currentChildren > 13 then
        OutputFrame.CanvasPosition = Vector2.new(0, currentHeight);
      end;

      currentChildren = currentChildren + 1;
    end;
  end);

  handleOutput("Welcome to script builder! Enjoy your stay here!", Color3.fromRGB(0, 255, 0));
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
      CommandLine = ConsoleMain and ConsoleMain:WaitForChild("CommandLine");
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
    end;
  end);
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

ScriptContext.Error:connect(function(message, trace, sc)
  if OutputFrame then
    local ErrorText = TextLabel:Clone();
    ErrorText.TextColor3 = Color3.new(255, 0, 0);
    ErrorText.Text = message:gsub(".LSource", "");
    ErrorText.Size = UDim2.new(0,ErrorText.TextBounds.X, 0,ErrorText.TextBounds.Y);
    ErrorText.Parent = OutputFrame;
  end;
end);

setmetatable(shared, {
  __call = (function(self, sc, owner)
    if sc and owner and typeof(sc) == "string" and typeof(owner) == "string" and OutputFrame then
      -- It's output
      if owner == "print" then
        handleOutput(sc, Color3.fromRGB(255, 255, 255));
      elseif owner == "warn" then
        handleOutput(sc, Color3.fromRGB(251, 255, 0));
      end;
    else
      if indexedScripts[sc] then
        return indexedScripts[sc];
      else
        if sc and owner then
          indexedScripts[sc] = {
            ['owner'] = owner;
            ['Disabled'] = false;
          };
        else
          if typeof(sc) == "Instance" and sc.ClassName ~= "LocalScript" then
            if owner and owner == true then
              hiddenItems[sc] = true;
            else
              return hiddenItems[sc];
            end;
          else
            return false;
          end;
        end;
      end;
    end;
  end),

  __metatable = "This metatable is locked."
});

print("Initialized client handler");