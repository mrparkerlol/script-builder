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
	dad_b0x.mainEnv = getfenv(); -- global env
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
		['wrap'] = (function(obj)
			if dad_b0x.CachedInstances[obj] then
				-- Object was previously sandboxed, return the already sanboxed version instead
				return dad_b0x.CachedInstances[obj];
			else
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

							if dad_b0x.Fake.Methods[lIndex] and (dad_b0x.Fake.ProtectedInstances[obj.ClassName]
								or dad_b0x.Fake.ProtectedInstances[obj]) then
								return (function(...)
									return dad_b0x.Fake.Methods[lIndex](dad_b0x.internalFunctions.getReal({...}));
								end);
							else
								if typeof(m) == "function" then
									if dad_b0x.Fake.ProtectedFunctions[m] then
										local fake = (function(...)
											return dad_b0x.Fake.Methods[lIndex](dad_b0x.internalFunctions.getReal({...}));
										end);
										
										dad_b0x.CachedInstances.funcCache[lIndex] = fake;

										return fake;
									else
										if dad_b0x.CachedInstances.funcCache[m] then
											return dad_b0x.CachedInstances.funcCache[m];
										else
											local func = (function(...)
												local succ, msg;
												
												-- Below portion fixes escaped
												-- errors from occuring
												-- outside the sandboxed code
												
												-- If all else checks out, it simply just
												-- returns the function.
												local realArgs = dad_b0x.internalFunctions.getReal({...});
												if realArgs ~= nil then
													succ, msg = dad_b0x.mainEnv.pcall(m, unpack(realArgs));
												--[[else
													succ, msg = dad_b0x.mainEnv.pcall(m, obj, ...);]]
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
														for i=0, #msg do
															if dad_b0x.Fake.ProtectedInstances[msg[i]] then
																msg[i] = dad_b0x.internalFunctions.wrap(m[i]);
															elseif dad_b0x.Blocked.Instances[msg[i]] then
																table.remove(msg, i);
															end;
														end;
														
														return msg;
													elseif typeof(msg) == "Instance" and
														(dad_b0x.Fake.ProtectedInstances[msg] or dad_b0x.Fake.ProtectedInstances[msg.ClassName]) or
														(dad_b0x.Blocked.Instances[msg] or dad_b0x.Blocked.Instances[msg.ClassName]) then
														if dad_b0x.Fake.ProtectedInstances[msg] or dad_b0x.Fake.ProtectedInstances[msg.ClassName] then
															return dad_b0x.internalFunctions.wrap(msg);
														elseif dad_b0x.Blocked.Instances[msg] or dad_b0x.Blocked.Instances[msg.ClassName] then
															return nil;
														end;
													else
														return msg;
													end;
												end;
											end);
		
											dad_b0x.CachedInstances.funcCache[m] = func;
		
											return func;
										end;
									end;
								else
									-- Wrap the index to prevent unsandboxed access
									return dad_b0x.internalFunctions.wrap(m);
								end;
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
					if typeof(dad_b0x.mainEnv[index]) == "Instance" then
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
			--[workspace.Baseplate] = true;
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
			['xpcall'] = (function (luaFunc, handler)
				if type(handler) ~= type(function() end) then
					return error('Bad argument to #1, \'value\' expected', 2);
				else
					local success_func = {pcall(luaFunc)};

					if not success_func[1] then
						local e,r = pcall(handler, success_func[2]);

						if not e then
							return false, 'error in handling';
						end
					end

					return unpack(success_func);
				end
			end);

			-- getfenv is sandboxed to prevent
			-- breakouts by using the function
			-- on a function to return
			-- the real environment

			-- see commit below for more info
			-- on specific breakouts:
			-- https://github.com/mrteenageparker/sb-in-a-require/commit/ccf19a82b1d5c95864b8993da5e6e05cdcf52c39
			['getfenv'] = (function(flevel)
				local s,m = pcall(getfenv, flevel) do
					if not s then
						return error(m, 2);
					else
						if m == dad_b0x.mainEnv then
							return getfenv(0);
						else
							return m;
						end
					end
				end
			end);

			-- setfenv is sandboxed to prevent
			-- overwriting the main environment
			-- with poteitnal malicious code
			-- see commit
			-- https://github.com/mrteenageparker/sb-in-a-require/commit/ccf19a82b1d5c95864b8993da5e6e05cdcf52c39
			['setfenv'] = (function(f, env)
				local s,m = pcall(getfenv, f);
				if s and m then
					if m == dad_b0x.mainEnv then
						if typeof(f) == "function" then
							return error ("'setfenv' cannot change environment of given object", 2);
						elseif typeof(f) == "number" then
							return error("bad argument #1 to 'setfenv' (invalid level)", 2);
						end;
					end;
				end;

				local success, message = pcall(setfenv, f, env);
				if not success then
					return error(message, 2);
				end;

				return message;
			end);

			['print'] = (function(...)
				-- TODO: hook the print object
				return print(...);
			end);
		};

		['Instances'] = {
			['shared'] = _G.sandboxedShared;
			['_G'] = _G.sandboxedG;
		};

		['Methods'] = {
			['destroy'] = (function(...)
				local args = ...;
				return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Destroy() on object has been disabled."), 3);
			end);

			['remove'] = (function(...)
				local args = ...;
				return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Remove() on this object has been disabled."), 3);
			end);

			['kick'] = (function(...)
				local args = ...;
				local s,m = pcall(function()
					return args[1]['Kick'];
				end);

				if not s then
					return error(m, 0);
				else
					return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":Kick() on this object has been disabled."), 3);
				end;
			end);

			['clearallchildren'] = (function(...)
				local args = ...;
				return error(dad_b0x.internalFunctions.handleObjectClassErrorString(args[1], ":ClearAllChildren() on object has been blocked."), 3);
			end);
		};

		['ProtectedInstances'] = {
			-- TODO: add the ability to make custom
			-- protected objects, however the default
			-- should be all the SB components.
			[workspace.Baseplate] = true;
			["Player"] = true;
			[game:GetService("Players")] = true;
		};

		['ProtectedFunctions'] = {
			[game.Destroy] = true;
			[game.Remove] = true;
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