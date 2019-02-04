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

script = nil;

-- Globals
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
			['shared'] = _G.sandboxedShared;
			['_G'] = _G.sandboxedG;
		};

		['Methods'] = {
			['destroy'] = (function(...)
				local args = {...};
				
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					error(handleObjectClassErrorString(args[1], ":Destroy() on object has been disabled."));
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
					error(handleObjectClassErrorString(args[1], ":Remove() on this object has been disabled."));
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
					error(handleObjectClassErrorString(args[1], ":Kick() on this object has been disabled."));
				end;
			end);

			['clearallchildren'] = (function(...)
				local args = {...};
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					error(handleObjectClassErrorString(args[1], ":ClearAllChildren() on object has been blocked."));
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
end;

local function wrap(obj, lIndex)
	local cachedInstanceFake, cachedInstanceFuncCache = dad_b0x.CachedInstances.fake[obj], dad_b0x.CachedInstances.funcCache[obj];
	if cachedInstanceFake then
		-- Object was previously sandboxed, return the already sanboxed version instead
		return cachedInstanceFake;
	elseif cachedInstanceFuncCache then
		-- Function was in the function cache
		return cachedInstanceFuncCache;
	else
		if typeof(obj) == "function" then
			local func = (function(...)
				local succ, msg;
				
				-- If all else checks out, it simply just
				-- returns the function.
				local realArgs = getReal({...});
				local protectedFunctions = dad_b0x.Fake.ProtectedFunctions[obj];
				if protectedFunctions then
					return protectedFunctions;
				end;
				
				if realArgs ~= nil and (typeof(realArgs) == "table" and #realArgs > 0) then
					if lIndex ~= nil and dad_b0x.Fake.Methods[lIndex] then
						local fake = (function(...)
							return dad_b0x.Fake.Methods[lIndex](...);
						end);
						
						dad_b0x.CachedInstances.funcCache[obj] = fake;
						
						local s,m = dad_b0x.mainEnv.pcall(fake, unpack(realArgs));
						return (s and m) or error(m, 2);
					else
						succ, msg = dad_b0x.mainEnv.pcall(obj, unpack(realArgs));
					end;
				else
					if lIndex ~= nil and dad_b0x.Fake.Methods[lIndex] then
						local fake = (function(...)
							return dad_b0x.Fake.Methods[lIndex](...);
						end);
						
						dad_b0x.CachedInstances.funcCache[obj] = fake;

						local s,m = dad_b0x.mainEnv.pcall(fake, ...);
						return (s and m) or error(m, 2);
					else
						if ... == nil or #{...} == 0 then
							succ, msg = dad_b0x.mainEnv.pcall(obj);
						else
							succ, msg = dad_b0x.mainEnv.pcall(obj, ...);
						end;
					end;
				end;
				
				if not succ then
					-- Error occured when calling method,
					-- handle it accordingly
					return error(msg, 2);
				else
					-- Successful execution - return the
					-- output (if any), or sandbox
					-- the return data
					if typeof(msg) == "table" then
						if getmetatable(msg) == "The metatable is locked" and msg['game'] == dad_b0x.mainEnv['game'] then
							local tbl = {};
							return setmetatable({}, {
								__index = (function(self, index)
									local index = _env[index];
									local type = typeof(index);
									return (type == "Instance" or type == "function") and wrap(index) or (tbl[index] or index);
								end);

								__newindex = (function(self, index, newindex)
									local s,m = pcall(function()
										tbl[index] = newindex;
									end);

									if not s then
										error(m);
									end;
								end);

								__metatable = getmetatable(game);
							});
						else
							for i=0, #msg do
								local index = msg[i];
								if dad_b0x.Fake.ProtectedInstances[index] then
									msg[i] = wrap(index);
								elseif dad_b0x.Blocked.Instances[index] then
									table.remove(msg, i);
								end;
							end;
							
							return msg;
						end;
					elseif typeof(msg) == "Instance" and (dad_b0x.Blocked.Instances[msg] or dad_b0x.Blocked.Instances[msg.ClassName]) then
						return nil;
					elseif typeof(msg) == "Instance" then
						return wrap(msg);
					else
						return msg;
					end;
				end;
			end);
			
			dad_b0x.CachedInstances.funcCache[obj] = func;

			return func;
		elseif typeof(obj) == "Instance" then
			if dad_b0x.Blocked.Instances[obj] then
				-- Object is supposed to be hidden, return nil
				-- to hide its existence
				return nil;
			else
				-- Get a empty userdata
				local proxy = newproxy(true);
				local meta = getmetatable(proxy) do
					meta.__metatable = getmetatable(obj);
					meta.__tostring = (function(self) return tostring(obj); end);
					
					-- __index
					meta.__index = (function(self, index)
						local lIndex = index:lower();
						
						local s, m = pcall(function()
							return obj[index];
						end);

						if s then
							local index= obj[index];
							local type = typeof(index);
							return (type == "function" or type == "Instance") and wrap(index, lIndex) or index;
						else
							error(m);
						end;
					end);
					
					-- __newindex
					-- with some help from MasterKelvinVIP based on some
					-- code from his sandbox.
					-- (includes SetMember function)
					meta.__newindex = (function(self, index, newindex)
						local Success, Result = pcall(setMember, obj, index, getReal(newindex))
						return Success or error(Result, 2);
					end);

					-- Optimize future returns by
					-- returning a cached result
					-- rather than re-creating
					-- the newproxy every single time
					dad_b0x.CachedInstances.fake[obj]		= proxy;
					dad_b0x.CachedInstances.real[proxy] = obj;

					-- return the userdata rather than the metatable
					-- see commit
					-- https://github.com/mrteenageparker/sb-in-a-require/commit/ccf19a82b1d5c95864b8993da5e6e05cdcf52c39
					return proxy;
				end;
			end;
		elseif typeof(obj) == "table" then
			local tbl = {};
			for i,v in pairs(obj) do
				tbl[i] = wrap(obj[i]);
			end;
			
			dad_b0x.CachedInstances.fake[obj] = tbl;
			
			return tbl;
		else
			return obj;
		end;
	end;	
end;

local _env = setmetatable({}, {
	__index = (function(self, index)
		if shared(dad_b0x.Script).Disabled == true then
			error("Script disabled.");
		end;

		if index == "owner" then return wrap(dad_b0x.Owner); elseif index == "script" then return wrap(dad_b0x.Script); end;

		local mainEnvObj = dad_b0x.mainEnv[index];
		local type = typeof(mainEnvObj);
		if mainEnvObj and type == "Instance" and (dad_b0x.Blocked.Instances[index] or dad_b0x.Blocked.Instances[mainEnvObj] 
				or dad_b0x.Blocked.Instances[mainEnvObj.ClassName]) then
			return nil;
		elseif dad_b0x.Blocked.Functions[index] or dad_b0x.Fake.Functions[index] or dad_b0x.Fake.Instances[index] then
			return dad_b0x.Blocked.Functions[index] or dad_b0x.Fake.Functions[index] or dad_b0x.Fake.Instances[index]
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