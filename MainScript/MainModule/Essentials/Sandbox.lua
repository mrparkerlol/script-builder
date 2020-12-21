--[[
	Written by Jacob (mrparkerlol on Github), with contributions by others.

	This is the sandbox source for the Script Builder Project,
	licensed GPL V3 only.

	This is provided free of charge, no warranty or liability
	provided. Use of this project is at your own risk.

	Documentation is also provided on Github, if needed.
]]

local typeof = typeof;
local unpack = unpack;
local newproxy = newproxy;
local setfenv = setfenv;

local Sandbox = {};
Sandbox.SandboxInstances = {}; -- Created instances of the sandbox

Sandbox.PreventAccess = {}; -- Prevents access to everything in here
Sandbox.CustomMethods = {}; -- Custom methods on objects - also used for preventing destructive methods
Sandbox.CustomProperties = {}; -- Custom properties for Instances
Sandbox.CreatedInstances = {}; -- Created instances with Instance.new()
Sandbox.GlobalOverrides = {}; -- Global variables that would otherwise be unsandboxed in the environment - are wrapped
Sandbox.UnWrappedGlobalOverrides = {}; -- Global overrides that don't need to be wrapped - such as tables, or functions
Sandbox.ProtectedProperties = {}; -- Allows overriding properties that result in errors if they are set
Sandbox.ProtectedServices = {}; -- Allows protecting specific services gotten from :GetService()
Sandbox.ProtectedClasses = {}; -- Protects the classes in here from being destroyed, or kicked
Sandbox.DestructiveMethods = { -- A list of destructive methods which can destroy stuff inside ProtectedClasses
	["destroy"] = true,
	["remove"] = true,
	["clearallchildren"] = true,
	["kick"] = true,
	["parent"] = true,
};

--[[
	Sandbox.new()
	Creates a new sandbox instance
]]
function Sandbox.new(scriptObject, environment)
	local sandboxInstance = {
		Killed = false, -- Handles killing scripts in this specific instance of the sandbox
		RealCache = {}, -- Handles mapping real values to the faked values in this instance of the sandbox
		WrappedCache = {}, -- Handles wrapped objects for this specific instance of the sandbox
		LocalOverrides = {}, -- Handles sandboxing Instances/functions/tables for this specific instance of the sandbox
	};

	function sandboxInstance.setLocalOverride(index, value)
		assert(typeof(index) == "string", "Expected string as first argument to sandboxInstance.setLocalOverride");
		sandboxInstance.LocalOverrides[index] = value;
	end;

	sandboxInstance.environment = setmetatable({}, {
		__index = (function(_, index)
			if sandboxInstance.Killed then
				return error("Script disabled.", 0);
			end;

			index = index:match("[^%z]*");
			local environmentItem = Sandbox.UnWrappedGlobalOverrides[index]
									or sandboxInstance.LocalOverrides[index]
									or environment[index]
									or nil;
			if Sandbox.PreventAccess[index] or Sandbox.PreventAccess[environmentItem] then
				return nil;
			elseif Sandbox.GlobalOverrides[index] then
				return Sandbox.wrap(sandboxInstance, Sandbox.GlobalOverrides[index]);
			elseif environmentItem then
				return environmentItem;
			else
				return nil;
			end;
		end),

		__metatable = "The metatable is locked"
	});

	Sandbox.SandboxInstances[scriptObject] = sandboxInstance;
	Sandbox.SandboxInstances[sandboxInstance] = sandboxInstance;

	return sandboxInstance;
end;

--[[
	Sandbox.kill()
	Disables a script running inside sandbox
]]
function Sandbox.kill(scriptInstance)
	assert(typeof(scriptInstance) == "Instance", "Expected arg #1 to Sandbox.kill to be a Script, not" .. typeof(scriptInstance));

	local sandboxInstance = Sandbox.SandboxInstances[scriptInstance];
	if Sandbox.SandboxInstances[scriptInstance] then
		Sandbox.SandboxInstances[scriptInstance].Killed = true;
		Sandbox.SandboxInstances[sandboxInstance] = nil;
		Sandbox.SandboxInstances[scriptInstance] = nil;

		delay(1, function()
			scriptInstance:Destroy();
		end);
	end;
end;

--[[
	Sandbox.wrap()
	Wraps a object to prevent breakouts.
	This function is very important - do not modify unless you know what
	you are doing. This function is paramount in preventing breakouts/bypasses.
]]
function Sandbox.wrap(sandboxInstance, ...)
	local args = {...};
	for i = 1, #args do
		local selected = args[i];
		local wrapped = Sandbox.getWrapped(sandboxInstance, selected);

		if wrapped then
			return wrapped;
		elseif Sandbox.PreventAccess[selected] then
			selected = nil;
		else
			local type = typeof(selected);
			if type == "Instance" then
				selected = Sandbox.wrapInstance(sandboxInstance, selected);
			elseif type == "table" then
				selected = Sandbox.wrapTable(sandboxInstance, selected);
			end;
		end;

		args[i] = selected;
	end;

	return unpack(args);
end;

--[[
	Sandbox.getWrapped()
	Returns a wrapped version of the object from the sandboxInstance
]]
function Sandbox.getWrapped(sandboxInstance, object)
	if sandboxInstance.WrappedCache[object] then
		return sandboxInstance.WrappedCache[object];
	end;

	return nil;
end;

--[[
	Sandbox.wrapInstance()
	Wraps a instance - such as game or a Player object
]]
function Sandbox.wrapInstance(sandboxInstance, object)
	-- Create a userdata
	local proxy = newproxy(true);

	-- Get the metatable of the userdata
	local mt = getmetatable(proxy);

	-- Setup the indexing for the object
	function mt.__index(_, index)
		local index = index:match("[^%z]*");
		local customMethod = Sandbox.getCustomMethod(object, index);
		local customProperty = Sandbox.getCustomProperty(object, index);
		if customMethod then -- Return a custom method
			return Sandbox.wrapMethod(sandboxInstance, index, customMethod);
		elseif customProperty then
			return Sandbox.wrap(sandboxInstance, customProperty);
		end;

		local success, indexed = pcall(function() return object[index]; end);
		if success then -- Method/property is found inside the object
			local type = typeof(indexed);
			if Sandbox.PreventAccess[indexed] then
				return nil;
			elseif type == "Instance" then
				return Sandbox.wrapInstance(sandboxInstance, indexed);
			elseif type == "function" then
				return Sandbox.wrapMethod(sandboxInstance, index, indexed);
			else
				return indexed;
			end;
		else
			return error(indexed, 2);
		end;
	end;

	-- Setup newindex to allow properties to be set
	function mt.__newindex(_, index, value)
		local index = index:match("[^%z]*");
		local protected = Sandbox.ProtectedClasses[object.ClassName];
		if protected and Sandbox.DestructiveMethods[index:lower()] then
			return error(object.ClassName .. " is protected.", 2);
		else
			local newValue = Sandbox.getReal(sandboxInstance, value);
			local success, message = pcall(function()
				object[index] = newValue;
			end);

			if not success then
				return error(message, 2);
			end;
		end;
	end;

	-- Return the value of tostring for the object
	function mt.__tostring()
		return tostring(object);
	end;

	-- Set metatable to the object's metatable
	mt.__metatable = getmetatable(object);

	-- Add to cache
	sandboxInstance.WrappedCache[object] = proxy;
	sandboxInstance.RealCache[proxy] = object;

	-- Finally, return the wrapped object
	return proxy;
end;

--[[
	Sandbox.wrapTable()
	Wraps a table - such as shared or _G
]]
function Sandbox.wrapTable(sandboxInstance, tbl)
	if pcall(rawset, tbl, "TestKey", 1) then
		rawset(tbl, "TestKey", nil);

		for key, value in next, tbl do
			local newKey = Sandbox.wrap(sandboxInstance, key);
			local newValue = Sandbox.wrap(sandboxInstance, value);

			rawset(tbl, key, nil);
			rawset(tbl, newKey, newValue);
		end;

		return tbl;
	end;
end;

--[[
	Sandbox.wrapMethod()
	Wraps metamethods
]]
function Sandbox.wrapMethod(sandboxInstance, index, methodFunction)
	local sandboxMt = Sandbox.SandboxInstances[sandboxInstance].environment;
	local methodWrapped = setfenv(function(self, ...)
		local realSelf = Sandbox.getReal(sandboxInstance, self);
		local realArgs = {Sandbox.getReal(sandboxInstance, ...)};
		local destructive = Sandbox.DestructiveMethods[index:lower()] or nil;
		if destructive then
			for key, value in pairs(realArgs) do
				local valueClass = typeof(value) == "Instance" and value.ClassName;
				local keyClass = typeof(key) == "Instance" and key.ClassName;

				if valueClass and Sandbox.ProtectedClasses[valueClass]
				or keyClass and Sandbox.ProtectedClasses[keyClass] then
					return error(valueClass or keyClass .. " is protected.", 2);
				end;
			end;

			if Sandbox.ProtectedClasses[realSelf.ClassName] then
				return error(realSelf.ClassName .. " is protected.", 2);
			end;
		end;

		local ret = {Sandbox.wrap(sandboxInstance, methodFunction(realSelf, unpack(realArgs)))};
		return unpack(ret);
	end, sandboxMt);

	sandboxInstance.RealCache[methodFunction] = methodWrapped;
	sandboxInstance.WrappedCache[methodWrapped] = methodFunction;

	return methodWrapped;
end;

--[[
	Sandbox.getReal();
	Returns unwrapped objects passed to it
]]
function Sandbox.getReal(sandboxInstance, ...)
	local tbl = {...};
	for i = 1, #tbl do
		local value = sandboxInstance.RealCache[tbl[i]] or tbl[i];
		tbl[i] = value;

		if typeof(value) == "table" then
			local valueTbl = {};
			for index, val in pairs(value) do
				local newIndex = Sandbox.getReal(sandboxInstance, index);
				local newVal = Sandbox.getReal(sandboxInstance, val);
				valueTbl[index] = nil;
				valueTbl[newIndex] = newVal;
			end;

			tbl[i] = valueTbl;
		end;
	end;

	return unpack(tbl);
end;

--[[
	Sandbox.getCustomMethod()
	Returns a custom method defined by Sandbox.setMethodOverride()
]]
function Sandbox.getCustomMethod(object, index)
	local objectClass = Sandbox.CustomMethods[object.ClassName];
	if objectClass then
		return objectClass[index:match("[^%z]*")];
	end;

	return nil;
end;

--[[
	Sandbox.getCustomProperty()
	Returns the custom property defined by Sandbox.setCustomProperty()
]]
function Sandbox.getCustomProperty(object, index)
	local objectClass = Sandbox.CustomProperties[object.ClassName];
	if objectClass then
		return objectClass[index:match("[^%z]*")];
	end;
end;

--[[
	Sandbox.setCustomProperty()
	Sets the custom property for the object class
]]
function Sandbox.setCustomProperty(class, index, value)
	assert(typeof(class) == "string", "Expected first argument to be a string when calling Sandbox.setCustomProperty");
	if not Sandbox.CustomProperties[class] then
		Sandbox.CustomProperties[class] = {};
	end;

	Sandbox.CustomProperties[class][index] = value;
end;

--[[
	Sandbox.setGlobalOverride()
	Sets a global override in which will replace
	the global in the environment
]]
function Sandbox.setGlobalOverride(index, value)
	assert(typeof(index) == "string", "Expected string as first argument to Sandbox.addGlobalOverride");
	Sandbox.GlobalOverrides[index] = value;
end;

--[[
	Sandbox.setUnWrappedGlobalOverride()
	Sets a global override that doesn't get wrapped
	This is useful for things like tables, or some functions
]]
function Sandbox.setUnWrappedGlobalOverride(index, value)
	assert(typeof(index) == "string", "Expected string as first argument to Sandbox.setUnWrappedGlobalOverride");
	Sandbox.UnWrappedGlobalOverrides[index] = value;
end;

--[[
	Sandbox.setMethodOverride()
	Sets a method override for the specific class
]]
function Sandbox.setMethodOverride(index, methodName, method)
	assert(typeof(index) == "string", "Expected string as first argument to Sandbox.setMethodOverride");
	assert(typeof(methodName) == "string", "Expected string as second argument to Sandbox.setMethodOverride");

	if not Sandbox.CustomMethods[index] then
		Sandbox.CustomMethods[index] = {};
	end;

	Sandbox.CustomMethods[index][methodName] = method;
end;

--[[
	Sandbox.addProtectedObject()
	Adds a object to the protected list - prevents them from being indexed
	Also handles the cleanup for when the object is destroyed
]]
function Sandbox.addProtectedObject(object)
	assert(typeof(object) == "Instance", "Expected instance in first argument to Sandbox.addProtectedObject");
	if not Sandbox.PreventAccess[object] then
		Sandbox.PreventAccess[object] = true;
		object.Changed:Connect(function(property)
			if property == "Parent" and object.Parent == nil then
				Sandbox.PreventAccess[object] = nil;
			end;
		end);
	end;
end;

--[[
	Sandbox.addProtectedClass()
	Adds a class that should never be destroyed, kicked, or cleared
]]
function Sandbox.addProtectedClass(index)
	assert(typeof(index) == "string", "Expected string as first argument to Sandbox.addProtectedClass");
	Sandbox.ProtectedClasses[index] = true;
end;

--[[
	Sandbox.setProtectedProperty()
	Sets a property to return a function if set
	Function should return an error to the caller and
	be a message about the property being protected
]]
function Sandbox.setProtectedProperty(index, propertyIndex, value)
	assert(typeof(index) == "string", "Expected string as first argument when calling Sandbox.setProtectedProperty");
	assert(typeof(propertyIndex) == "string", "Expected string as second argument when calling Sandbox.setProtectedProperty");
	assert(typeof(value) == "function", "Expected function as third argument when calling Sandbox.setProtectedProperty");
	if not Sandbox.ProtectedProperties[index] then
		Sandbox.ProtectedProperties[index] = {};
	end;

	Sandbox.ProtectedProperties[index][propertyIndex] = value;
end;

return Sandbox;