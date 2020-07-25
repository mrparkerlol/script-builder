-- Get the owner of the script and source.
local config = shared(script);

-- Require the sandbox
local sandbox = shared("Sandbox");

spawn(function()
	-- Create the sandbox instance
	-- Print, warn and _G and shared sandboxing
	-- is done for you
	local metatable = sandbox.new(script, getfenv(), {
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

		['_G'] = _G.sandboxedG,
		['shared'] = _G.sandboxedShared,
	});

	local Function, message = loadstring(config.Source, 'SB-Script');
	if not Function then
		-- Code had a syntax error
		return error(message, 0);
	else
		-- Run the code inside the sandbox
		setfenv(0, metatable);
		setfenv(1, metatable);
		setfenv(Function, metatable);

		Function();
	end;
end);