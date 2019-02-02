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

	-- Internalized functions
	dad_b0x.internalFunctions = {
		['wrap'] = (function(obj, lIndex)
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

						-- Below portion fixes escaped
						-- errors from occuring
						-- outside the sandboxed code
						
						-- If all else checks out, it simply just
						-- returns the function.
						local realArgs = dad_b0x.internalFunctions.getReal({...});
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
								if not s then
									return error(m, 2);
								else
									return m;
								end;
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
								if not s then
									return error(m, 2);
								else
									return m;
								end;
							else
								succ, msg = dad_b0x.mainEnv.pcall(obj, ...);
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
											local index = dad_b0x.Environments.level_1[index];
											local type = typeof(index);
											if type == "Instance" or type == "function" then
												return dad_b0x.internalFunctions.wrap(index);
											else
												if tbl[index] then
													return tbl[index];
												else
													return index;
												end;
											end;
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
											msg[i] = dad_b0x.internalFunctions.wrap(index);
										elseif dad_b0x.Blocked.Instances[index] then
											table.remove(msg, i);
										end;
									end;
									
									return msg;
								end;
							elseif typeof(msg) == "Instance" and (dad_b0x.Blocked.Instances[msg] or dad_b0x.Blocked.Instances[msg.ClassName]) then
								return nil;
							elseif typeof(msg) == "Instance" then
								return dad_b0x.internalFunctions.wrap(msg);
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
							meta.__metatable = getmetatable(game);
							meta.__tostring = (function(self) return tostring(obj) end);
							
							-- __index
							meta.__index = (function(self, index)
								local lIndex = string.lower(index);
								
								local s, m = pcall(function()
									return obj[index];
								end);

								if s then
									local index = obj[index];
									if typeof(index) == "function" or typeof(index) == "Instance" then
										return dad_b0x.internalFunctions.wrap(index, lIndex);
									else
										return index;
									end;
								else
									error(m);
								end;
							end);
							
							-- __newindex
							meta.__newindex = (function(self, index, newindex)
								local Index, newIndex = (typeof(Index) == "userdata" and dad_b0x.internalFunctions.getReal(Index)), 
																				(typeof(newIndex) == "userdata" and dad_b0x.internalFunctions.getReal(newIndex));
								local s,m = pcall(function()
									obj[Index] = newIndex;
								end);

								if not s then
									error(m);
								end;
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
						tbl[i] = dad_b0x.internalFunctions.wrap(v);
					end;
					
					dad_b0x.CachedInstances.fake[obj] = tbl;
					
					return tbl;
				else
					return obj;
				end;
			end;	
		end);

		['getReal'] = (function(obj)
			if typeof(obj) == "table" then
				local tbl = {};
				
				for i=1, #obj do
					local cachedInstance = dad_b0x.CachedInstances.real[obj[i]];
					if cachedInstance then
						table.insert(tbl, cachedInstance);
					else
						table.insert(tbl, obj[i]);
					end;
				end;

				return tbl;
			else
				return dad_b0x.CachedInstances.real[obj] or obj;
			end;
		end);

		-- Our general error handler to return
		-- errors according to class name
		['handleObjectClassErrorString'] = (function(obj, defaultMessage)
			-- It is recognized as a type to specifically apply a message to
			local classError = dad_b0x.Fake.PotentialClassErrors[obj.ClassName];
			if classError then
				return classError;
			else
				-- No index, return the default error that was passed
				return defaultMessage;
			end;
		end);
	};

	-- Environments
	dad_b0x.Environments = {
		['level_1'] = setmetatable({}, {
			__index = (function(self, index)
				if shared(dad_b0x.Script).Disabled == true then
					error("Script disabled.");
				end;

				if index == "owner" then return dad_b0x.Owner; elseif index == "script" then return dad_b0x.Script; end;

				local mainEnvObj = dad_b0x.mainEnv[index];
				if mainEnvObj and typeof(mainEnvObj) == "Instance" and (dad_b0x.Blocked.Instances[index] or dad_b0x.Blocked.Instances[mainEnvObj] 
						or dad_b0x.Blocked.Instances[mainEnvObj.ClassName]) then
					return nil;
				elseif dad_b0x.Blocked.Functions[index] then
					return dad_b0x.Blocked.Functions[index];
				elseif dad_b0x.Fake.Functions[index] then
					return dad_b0x.Fake.Functions[index];
				elseif dad_b0x.Fake.Instances[index] then
					return dad_b0x.Fake.Instances[index];
				else
					if typeof(mainEnvObj) == "Instance" or typeof(mainEnvObj) == "table" or typeof(mainEnvObj) == "function" then
						return dad_b0x.internalFunctions.wrap(mainEnvObj);
					end;

					return mainEnvObj;
				end;
			end);

			__metatable = 'Locked. (level_1)';
		}),
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

-- return sandbox environment
return (function(owner, script)
	dad_b0x.Owner = owner;
	dad_b0x.Script = script;

	return dad_b0x.Environments.level_1;
end);