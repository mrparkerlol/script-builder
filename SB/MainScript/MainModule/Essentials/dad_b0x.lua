--[[
	Written by Jacob (@monofur, https://github.com/mrteenageparker)

	Originally modified from my sandbox
	for my discord bot:
	https://github.com/mrteenageparker/sandboxxy

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

local dad_b0x = {} do
	-- Environement
	dad_b0x.mainEnv = getfenv(0); -- global env
	dad_b0x.Owner = nil; -- utimately will be set to the Player object of the script's owner
	dad_b0x.Script = nil;

	-- Pre-defined tables
	dad_b0x.Fake = {
		['Functions'] = {};
		['Methods'] = {};

		['Instances'] = {};
		['ProtectedInstances'] = {};
		['ProtectedFunctions'] = {};
		['PotentialClassErrors'] = {};
	};

	-- Optimization for returning already wrapped objects
	dad_b0x.CachedInstances = {
		['real'] = setmetatable({}, {__mode = "k"});
		['fake'] = setmetatable({}, {__mode = "k"});
		['funcCache'] = {};
	};

	-- Blocked functions
	dad_b0x.Blocked = {
		['Instances'] = _G.protectedObjects;
		
		['Functions'] = {
			['require'] = (function(...)
					-- TODO: allow the user to whitelist specific modules
					-- or to straight up disable require()
					error('Attempt to call require() (action has been blocked)')
			end);

			['collectgarbage'] = (function(...)
				error('Attempt to call collectgarbage() (action has been blocked)');
			end);
		};
	};

	dad_b0x.Fake = {
		['Functions'] = {
			['print'] = (function(...)
				local args = {...};
				local printString = "";

				if #args == 1 then
					printString = tostring(args[1]);
				else
					for i=1, #args do
						printString = printString .. ' ' .. tostring(args[i]);
					end;
				end;

				-- TODO: hook the print object
				dad_b0x.mainEnv.shared("Output", {
					['Owner'] = dad_b0x.Owner,
					['Type'] = "print",
					['Message'] = printString
				});
			end);

			['warn'] = (function(...)
				local args = {...};
				local printString = "";

				if #args == 1 then
					printString = tostring(args[1]);
				else
					for i=1, #args do
						printString = printString .. ' ' .. tostring(args[i]);
					end;
				end;

				-- TODO: hook the print object
				dad_b0x.mainEnv.shared("Output", {
					['Owner'] = dad_b0x.Owner,
					['Type'] = "warn",
					['Message'] = printString
				});
			end)
		};

		['Instances'] = {
			['shared'] = shared;
			['_G'] = _G;
		};

		['Methods'] = {
			['destroy'] = (function(...)
				local args = {...};
				
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Destroy() on object has been disabled."));
				else
					local s,m = pcall(function()
						return (#args == 1 and args[1]:Destroy()) or game.Destroy(unpack(args));
					end);

					if not s then
						error(m);
					else
						return m;
					end;
				end;
			end);

			['remove'] = (function(...)
				local args = {...};
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Remove() on this object has been disabled."));
				else
					local s,m = pcall(function()
						return (#args == 1 and args[1]:Remove()) or game.Remove(unpack(args));
					end);

					if not s then
						error(m);
					else
						return m;
					end;
				end;
			end);

			['kick'] = (function(...)
				local args = {...};
				local s,m = pcall(function()
					return args[1]['Kick'];
				end);

				if not s then
					error(m);
				else
					error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Kick() on this object has been disabled."));
				end;
			end);

			['clearallchildren'] = (function(...)
				local args = {...};
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":ClearAllChildren() on object has been blocked."));
				else
					local s,m = pcall(function()
						return game.ClearAllChildren(unpack(args));
					end);

					if not s then
						error(m);
					else
						return m;
					end;
				end;
			end);
		};

		['ProtectedInstances'] = {
			-- TODO: add the ability to make custom
			-- protected objects, however the default
			-- should be all the SB components.
			--[workspace.Baseplate] = true;
			["Player"] = true;
			[game:GetService("Players")] = true;
		};

		['ProtectedFunctions'] = {
			[game.Destroy] = dad_b0x.Fake.Methods.destroy;
			[game.destroy] = dad_b0x.Fake.Methods.destroy;

			[game.Remove] = dad_b0x.Fake.Methods.remove;
			[game.remove] = dad_b0x.Fake.Methods.remove;

			[game.ClearAllChildren] = dad_b0x.Fake.Methods.clearallchildren;
		};

		['PotentialClassErrors'] = {
			['Players'] = 'Players is protected.';
			['Player'] = "Kicking a player has been disabled.";
			['BasePart'] = "This object is locked.";
			['Script'] = "This object is locked.";
			['LocalScript'] = "This object is locked.";
			['RemoteEvent'] = "This object is locked.";
			['RemoteFunction'] = "This object is locked.";
			['ScreenGui'] = "This object is locked.";
		};
	};
end;

local function getMember(object, index)
	return object[index];
end

local function setMember(Table, Index, Value)
	Table[Index] = Value;
end;

local function handleObjectClassErrorString(obj, defaultMessage)
	return dad_b0x.Fake.PotentialClassErrors[obj.ClassName] or defaultMessage;
end;

local function getReal(obj)
	if typeof(obj) == "table" then
		local tbl = {};
		for i=1, #obj do
			tbl[#tbl + 1] = dad_b0x.CachedInstances.real[obj[i]] or obj[i];
		end;

		return tbl;
	else
		return dad_b0x.CachedInstances.real[obj] or obj;
	end;
end

local function wrap(...)
	local env = getfenv(0); -- prevents ppl from grabbing module env
	local args = {...};

	for i = 1, #args do
		local selected = args[i];
		local cachedInstanceFake, cachedInstanceFuncCache = dad_b0x.CachedInstances.fake[selected], dad_b0x.CachedInstances.funcCache[selected];
		if cachedInstanceFake then
			-- Object was previously sandboxed, return the already sanboxed version instead
			selected = cachedInstanceFake;
		elseif cachedInstanceFuncCache then
			-- Function was in the function cache
			selected = cachedInstanceFuncCache;
		else
			local info = type(selected);
			if info == "userdata" then
				local info2 = typeof(selected);
				if info2 == "Instance" then
					local proxy = newproxy(true);
					local meta = getmetatable(proxy);

					if dad_b0x.Blocked.Instances[selected] then
						-- below replaces the instance with a blocked version, this is just better use it ok
						meta.__index = {
							ClassName = "BoolValue",
							Name = "Blocked",
							Value = true,
						};
						
						function meta:__newindex(index, value)
							return error(index .. " is not a valid member of Blocked", 0);
						end;
						
						function meta:__tostring()
							return "Blocked";
						end;
						
						meta.__metatable = "This metatable is locked";

						selected = Proxy;
					else
						local class = selected.ClassName;

						meta.__metatable = getmetatable(selected);

						function meta:__tostring()
							return tostring(selected);
						end;

						function meta:__index(index)
							local status, result = pcall(getMember, selected, index);
							if not status then
								return error(index .. " is not a valid member of " .. class);
							end;

							local result_info = type(result);
							local lower_index = index:lower();
							if result_info == "function" then
								local status_, result_;
								if dad_b0x.Fake.Methods[lower_index] then
									status_, result_ = true, setfenv(dad_b0x.Fake.Methods[lower_index], env);
								else
									status_, result_ = true, result;
								end;

								local indexed_info = type(result_);
								if indexed_info == "function" then
									return wrapMethod(selected, lower_index, result_);
								else
									return wrap(result_);
								end;
							else
								return wrap(result);
							end;
						end;

						function meta:__newindex(index, value)
							local Success, Result = pcall(setMember, obj, index, getReal(value));
							return Success or error(Result, 2);
						end;
					end;
				elseif info2 == "RBXScriptSignal" then

				elseif info2 == "RBXScriptConnection" then

				end
			elseif info == "function" then
				if dad_b0x.CachedInstances.funcCache[selected] then
					local found = dad_b0x.CachedInstances.funcCache[selected];
					if getfenv(found) ~= env then
						found = setfenv(found, env);
					end;
					selected = found;
				end;
			elseif info == "table" then
				local tbl = {};
				for i,v in next, selected do
					tbl[i] = wrap(selected[i]);
				end;
				
				dad_b0x.CachedInstances.fake[selected] = tbl;
				
				selected = tbl;
			end;
		end;
		args[i] = selected;
	end;

	return unpack(args);
end;

local function wrapMethod(object, index, method)
	local env = getfenv(0);

	local cached = dad_b0x.CachedInstances.funcCache[obj];
	if cached then
		return setfenv(cached, env);
	end;

	local function newMethod(self, ...)
		local real = getReal(self);
		local real_info = typeof(real);
		if Type ~= "Instance" then
			return error(select(2, pcall(Method, ...)), 0);
		end;

		if real then
			if dad_b0x.Fake.Methods[index] then
				local override = dad_b0x.Fake.Methods[index];
				if real == game then
					return override(real, wrap(...));
				else
					return wrap(override(real, wrap(...)));
				end;
			end;
		end;

		return wrap(method(real or object, getReal(...)));
	end;

	dad_b0x.CachedInstances.funcCache[method] = newMethod;
	dad_b0x.CachedInstances.real[newMethod] = method;
	return setfenv(newMethod, env);
end;

local _env = setmetatable({}, {
	__index = (function(self, index)
		if shared(dad_b0x.Script).Disabled == true then
			error("Script disabled.");
		end;

		if index == "owner" then return dad_b0x.Owner; elseif index == "script" then return dad_b0x.Script; end;

		local mainEnvObj = dad_b0x.mainEnv[index];
		local type = typeof(mainEnvObj);
		if mainEnvObj and type == "Instance" and (dad_b0x.Blocked.Instances[index] or dad_b0x.Blocked.Instances[mainEnvObj] 
				or dad_b0x.Blocked.Instances[mainEnvObj.ClassName]) then
			return nil;
		elseif dad_b0x.Blocked.Functions[index] or dad_b0x.Fake.Functions[index] or dad_b0x.Fake.Instances[index] then
			return dad_b0x.Blocked.Functions[index] or dad_b0x.Fake.Functions[index] or dad_b0x.Fake.Instances[index];
		else
			if type == "Instance" or type == "table" or type == "function" then
				return wrap(mainEnvObj);
			end;

			return mainEnvObj;
		end;
	end);

	__metatable = 'Locked. (level_1)';
});

-- return sandbox environment
return (function(owner, script)
	dad_b0x.Owner = owner;
	dad_b0x.Script = script;

	return _env;
end);