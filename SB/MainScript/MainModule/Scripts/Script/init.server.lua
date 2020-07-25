local ReplicatedStorage = game:GetService("ReplicatedStorage");

-- Generic function for protecting a Player
local function kickError(...)
	return error("Kicking a player has been disabled.", 3);
end;

-- Get the owner of the script and source.
local config = shared(script);

-- Require the sandbox
local sandbox = shared("Sandbox");

-- Create the sandbox instance
local metatable = sandbox.new(script, getfenv(), {
	Objects = {
		[ReplicatedStorage.SB_Remote] = true,
	},
	Methods = {
		['Player'] = {
			['kick'] = kickError,
			['clearallchildren'] = kickError,
			['destroy'] = kickError,
			['remove'] = kickError,
		},
		['Players'] = {
			['clearallchildren'] = kickError,
		},
		['ReplicatedStorage'] = {
			['clearallchildren'] = (function(self, ...)
				local children = ReplicatedStorage:GetChildren();
				for _, object in pairs(children) do
					if object ~= ReplicatedStorage.SB_Remote then
						pcall(function()
							object:Destroy();
						end);
					end;
				end;
			end),
		}
	},
	Properties = {
		['Player'] = {
			['parent'] = kickError,
		}
	},
}, {
	['print'] = (function(...)
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
			Owner = config.Owner,
			Type = "print",
			Message = printString
		});
	end),

	['warn'] = (function(...)
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
			Owner = config.Owner,
			Type = "warn",
			Message = printString
		});
	end),

	--[[
		TODO: sandbox modules
	]]
	['require'] = (function(...)
		return error("Require has been disabled.", 2);
	end),

	['_G'] = _G.sandboxedG,
	['shared'] = _G.sandboxedShared,
}, {});

-- execute helper function
local function execute(src)
	local success, message = loadstring(src, 'SB-Script');
	if not success then
		-- Code had a syntax error
		return error(message, 0);
	else
		-- Run the code inside the sandbox
		return setfenv(success, metatable)();
	end;
end;

-- Execute with the sourceless string
execute(config.Source);