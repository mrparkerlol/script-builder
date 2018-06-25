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
		['real'] = {};
		['fake'] = {};
		['funcCache'] = {};
	};

	-- Internalized functions
	dad_b0x.internalFunctions = {
		['wrap'] = (function(obj, lIndex)
			if dad_b0x.CachedInstances.fake[obj] then
				-- Object was previously sandboxed, return the already sanboxed version instead
				return dad_b0x.CachedInstances.fake[obj];
			elseif dad_b0x.CachedInstances.funcCache[obj] then
				-- Function was in the function cache
				return dad_b0x.CachedInstances.funcCache[obj];
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
						if realArgs ~= nil then
							if dad_b0x.Fake.ProtectedFunctions[obj] then
								return dad_b0x.Fake.ProtectedFunctions[m];
							elseif lIndex ~= nil and dad_b0x.Fake.Methods[lIndex] then
								local fake = (function(...)
									return dad_b0x.Fake.Methods[lIndex](realArgs);
								end);
								
								dad_b0x.CachedInstances.funcCache[obj] = fake;
								
								local s,m = dad_b0x.mainEnv.pcall(fake, realArgs);

								if not s then
									return error(m, 2);
								else
									return m;
								end;
							else
								succ, msg = dad_b0x.mainEnv.pcall(obj, unpack(realArgs));
							end;
						else
							succ, msg = dad_b0x.mainEnv.pcall(obj, ...);
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
											if typeof(dad_b0x.mainEnv[index]) == "Instance" or typeof(dad_b0x.mainEnv[index]) == "function" then
												return dad_b0x.internalFunctions.wrap(dad_b0x.mainEnv[index]);
											else
												if tbl[index] then
													return tbl[index];
												else
													return dad_b0x.mainEnv[index];
												end;
											end;
										end);

										__newindex = (function(self, index, newindex)
											local s,m = pcall(function()
												tbl[index] = newindex;
											end);

											if not s then
												return error(m, 2);
											end;
										end);

										__metatable = getmetatable(game);
									});
								else
									for i=0, #msg do
										if dad_b0x.Fake.ProtectedInstances[msg[i]] then
											msg[i] = dad_b0x.internalFunctions.wrap(m[i]);
										elseif dad_b0x.Blocked.Instances[msg[i]] then
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
				end;

				if typeof(obj) == "Instance" then
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
									if typeof(obj[index]) == "function" or typeof(obj[index]) == "Instance" then
										return dad_b0x.internalFunctions.wrap(obj[index], lIndex);
									else
										return obj[index];
									end;
								else
									return error(m, 2);
								end;
							end);
							
							-- __newindex
							meta.__newindex = (function(self, index, newindex)
								local s,m = pcall(function()
									obj[index] = newindex;
								end);

								if not s then
									return error(m, 2);
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
					end
				end;
			end;
		end);

		['getReal'] = (function(obj)
			if typeof(obj) == "table" then
				local tbl = {};
				for i=1, #obj do
					if dad_b0x.CachedInstances.real[obj[i]] then
						table.insert(tbl, dad_b0x.CachedInstances.real[obj[i]]);
					else
						table.insert(tbl, obj[i]);
					end;
				end;

				return tbl;
			else
				return dad_b0x.CachedInstances.real[obj];
			end;
		end);

		-- Our general error handler to return
		-- errors according to class name
		['handleObjectClassErrorString'] = (function(obj, defaultMessage)
			-- It is recognized as a type to specifically apply a message to
			if dad_b0x.Fake.PotentialClassErrors[obj.ClassName] then
				return dad_b0x.Fake.PotentialClassErrors[obj.ClassName];
			else
				-- No index, return the default error that was passed
				return defaultMessage;
			end;
		end);
	};

	-- Environments
	dad_b0x.Environments = {
		['level_1'] = setmetatable({},{
			__index = (function(self,index)
				if dad_b0x.Blocked.Instances[index] then
					return nil;
				elseif dad_b0x.Blocked.Functions[index] then
					return dad_b0x.Blocked.Functions[index];
				elseif dad_b0x.Fake.Functions[index] then
					return dad_b0x.Fake.Functions[index];
				elseif dad_b0x.Fake.Instances[index] then
					return dad_b0x.Fake.Instances[index];
				else
					if typeof(dad_b0x.mainEnv[index]) == "Instance" or typeof(dad_b0x.mainEnv[index]) == "function" then
						return dad_b0x.internalFunctions.wrap(dad_b0x.mainEnv[index]);
					end;

					return dad_b0x.mainEnv[index];
				end;
			end);

			__metatable = 'Locked. (level_1)';
		}),
	};

	-- Blocked functions
	dad_b0x.Blocked = {
		['Instances'] = {
			[workspace.Baseplate] = true;
		};

		['Functions'] = {
			['require'] = (function(...)
					-- TODO: allow the user to whitelist specific modules
					-- or to straight up disable require()
					return require(...);
				--return error('Attempt to call require() (action has been blocked)', 2)
			end);

			['collectgarbage'] = (function(...)
				return error('Attempt to call collectgarbage() (action has been blocked)', 2);
			end);
		};
	};

	dad_b0x.Fake = {
		['Functions'] = {
			['print'] = (function(...)
				-- TODO: hook the print object
				return dad_b0x.mainEnv.print(...);
			end);
		};

		['Instances'] = {
			['shared'] = _G.sandboxedShared;
			['_G'] = _G.sandboxedG;
		};

		['Methods'] = {
			['destroy'] = (function(...)
				local args = ...;
				
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Destroy() on object has been disabled."), 4);
				else
					local s,m = pcall(function()
						return game.Destroy(unpack(args));
					end);

					if not s then
						return error(m, 4);
					else
						return m;
					end;
				end;
			end);

			['remove'] = (function(...)
				local args = ...;
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Remove() on this object has been disabled."), 4);
				else
					local s,m = pcall(function()
						return game.Remove(unpack(args));
					end);

					if not s then
						return error(m, 3);
					else
						return m;
					end;
				end;
			end);

			['kick'] = (function(...)
				local args = ...;
				local s,m = pcall(function()
					return args[1]['Kick'];
				end);

				if not s then
					return error(m, 4);
				else
					return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Kick() on this object has been disabled."), 4);
				end;
			end);

			['clearallchildren'] = (function(...)
				local args = ...;
				if dad_b0x.Fake.ProtectedInstances[args[1]] or dad_b0x.Fake.ProtectedInstances[args[1].ClassName] then
					return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":ClearAllChildren() on object has been blocked."), 4);
				else
					local s,m = pcall(function()
						return game.ClearAllChildren(unpack(args));
					end);

					if not s then
						return error(m, 4);
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
return (function(owner)
	dad_b0x.Owner = owner;

	return dad_b0x.Environments.level_1;
end);