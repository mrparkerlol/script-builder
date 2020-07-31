--[[
    Written by Jacob (@monofur, https://github.com/mrteenageparker)

    Provides sandboxing for the scriptbuilder.
]]

local typeof = typeof;
local newproxy = newproxy;
local assert = assert;
local unpack = unpack;
local setfenv = setfenv;

local function handleTypeError(var, funcName, typeExpected, argNum)
    return string.format("Invalid arg #%d to \"Sandbox.%s\" (%s expected, got %s)", argNum, funcName, typeExpected, typeof(var));
end;

--[[
    Sandbox table for holding public functions
    and public APIs for the sandbox
]]
local Sandbox = {};
Sandbox.SandboxInstances = {}; -- Sandbox Instances table
Sandbox.InstancesCreated = {}; -- Instances created with Instance.new
Sandbox.PreventedList = {}; -- The list of items to prevent indexing (protects SB internals by default)
Sandbox.MethodOverrides = {}; -- Allows overriding of methods
Sandbox.PropertyOverrides = {}; -- Allows overriding of properties
Sandbox.CustomFunctions = {}; -- Allows custom function definitions
Sandbox.CustomOverrides = {}; -- Allows custom stuff that isn't a function
Sandbox.GlobalOverrides = {}; -- Sandboxes specific things, rather than everything

--[[
    Sandbox.getIsObjectProtected()
    Function for getting whether or not a object is protected
    from being indexed
]]
function Sandbox.getIsObjectProtected(object)
    if Sandbox.PreventedList[object] then
        return true;
    end;

    return false;
end;

--[[
    Sandbox.addObjectToProtectedList()
    Adds an object to the protected objects list - prevents
    the object from being indexed
]]
function Sandbox.addObjectToProtectedList(object)
    -- Checks if the passed argument is a Instance
    assert(typeof(object) == "Instance", handleTypeError(object, "addObjectToProtectedList", "Instance", 1));

    if not Sandbox.PreventedList[object] then
        -- Adds it to the index
        Sandbox.PreventedList[object] = true;

        -- Handles the cleanup of the object after
        -- it is deleted
        object.Changed:Connect(function(property)
            if property == "Parent" then -- Is the property "Parent" being modified?
                if object.Parent == nil then -- Is .Parent nil?
                    Sandbox.PreventedList[object] = nil; -- Clear the object from the table
                end;
            end;
        end);
    end;
end;

--[[
    Sandbox.removeObjectFromProtectedList()
    Removes an object from the protected objects list
]]
function Sandbox.removeObjectFromProtectedList(object)
    assert(typeof(object) == "Instance", handleTypeError(object, "removeObjectFromProtectedList", "Instance", 1));

    if Sandbox.PreventedList[object] then
        Sandbox.PreventedList[object] = nil;
    end;
end;

--[[
    Sandbox.getInstance()
    Gets an instance of a sandbox from the instance table.
]]
function Sandbox.getInstance(sandboxInstance)
    if Sandbox.SandboxInstances[sandboxInstance] then
        return Sandbox.SandboxInstances[sandboxInstance];
    end;
end;

--[[
    Sandbox.addInstance()
    Adds an instance of a sandbox to the Instances table.
]]
function Sandbox.addInstance(instTable, mt)
    if not Sandbox.SandboxInstances[instTable] then
        Sandbox.SandboxInstances[instTable] = mt;
    end;
end;

--[[
    Sandbox.addGlobalOverrides()
    Adds a global to the list of items to sandbox
]]
function Sandbox.addGlobalOverride(index, value)
    if not Sandbox.GlobalOverrides[index] then
        Sandbox.GlobalOverrides[index] = value;
    end;
end;

--[[
    Sandbox.destroyInstance()
    Removes an instance of a sandbox from the Instances table.
    Also handles the deconstruction process.
]]
function Sandbox.destroyInstance(scriptObject)
    local instTable = Sandbox.SandboxInstances[scriptObject];
    if instTable then
        instTable.Killed = true; -- Disables the script running

        -- Deletes from memory
        Sandbox.SandboxInstances[instTable] = nil;
        Sandbox.SandboxInstances[scriptObject] = nil;
    end;
end;

--[[
    Sandbox.returnCreatedInstances()
    Simple helper function to return the created instances
]]
function Sandbox.returnCreatedInstances()
    return Sandbox.InstancesCreated;
end;

--[[
    Sandbox.addCustomMethod()
    Adds a method override to sandbox
]]
function Sandbox.addCustomMethod(methodClass, methodName, func)
    assert(typeof(methodClass) == "string", handleTypeError(methodClass, "addMethodOverride", "string", 1));
    assert(typeof(methodName) == "string", handleTypeError(methodClass, "addMethodOverride", "string", 2));
    assert(typeof(func) == "function", handleTypeError(func, "addMethodOverride", "function", 3));

    if not Sandbox.MethodOverrides[methodClass] then
        Sandbox.MethodOverrides[methodClass] = {};
    end;

    if not Sandbox.MethodOverrides[methodClass][methodName:lower()] then
        Sandbox.MethodOverrides[methodClass][methodName:lower()] = func;
    end;
end;

--[[
    Sandbox.getCustomMethod()
    Helper function to get the method overrides for a specific class
]]
function Sandbox.getCustomMethod(object, index)
    if typeof(object) ~= "Instance" then return; end;

    local indexClass = Sandbox.MethodOverrides[object.ClassName];
    if indexClass then
        if indexClass[index:lower():match("[^%z]*")] then
            return indexClass[index:lower():match("[^%z]*")];
        end;
    end;

    return nil;
end;

--[[
    Sandbox.addPropertyOverride()
    Adds a override for a proeprty for the specifc
    object class
]]
function Sandbox.addPropertyOverride(propertyClass, propertyName, func)
    assert(typeof(propertyClass) == "string", handleTypeError(propertyClass, "addPropertyOverride", "string", 1));
    assert(typeof(propertyName) == "string", handleTypeError(propertyClass, "addPropertyOverride", "string", 2));
    assert(typeof(func) == "function", handleTypeError(func, "addPropertyOverride", "function", 3));

    if not Sandbox.PropertyOverrides[propertyClass] then
        Sandbox.PropertyOverrides[propertyClass] = {};
    end;

    if not Sandbox.PropertyOverrides[propertyClass][propertyName] then
        Sandbox.PropertyOverrides[propertyClass][propertyName] = func;
    end;
end;

--[[
    Sandbox.addCustomFunction()
    Adds a custom override function to the sandbox
]]
function Sandbox.addCustomFunction(funcName, func)
    assert(typeof(funcName) == "string", handleTypeError(funcName, "addCustomOverride", "string", 1));
    assert(typeof(func) == "function", handleTypeError(func, "addCustomOverride", "string", 2));

    if not Sandbox.CustomFunctions[funcName] then
        Sandbox.CustomFunctions[funcName] = func;
    end;
end;

--[[
    Sandbox.getCustomFunction()
    Returns the override set for the given index
]]
function Sandbox.getCustomFunction(index)
    if Sandbox.CustomFunctions[index] then
        return Sandbox.CustomFunctions[index];
    end;

    return nil;
end;

--[[
    Sandbox.getPropertyOverride()
    Gets whether or not a property override exists for
    this specific object's class
]]
function Sandbox.getPropertyOverride(object, index)
    if typeof(object) ~= "Instance" then return; end;

    local classIndex = Sandbox.PropertyOverrides[object.ClassName];
    if classIndex then
        if classIndex[index] then
            return classIndex[index];
        end;
    end;

    return nil;
end;

--[[
    Sandbox.setCustomOverride()
    Allows overriding something that isn't a function
]]
function Sandbox.addCustomOverride(index, object)
    assert(typeof(index) == "string", handleTypeError(index, "setCustomOverride", "string", 1));
    assert(object ~= nil, handleTypeError(object, "setCustomOverride", "Variant", 2));

    if not Sandbox.CustomOverrides[index] then
        Sandbox.CustomOverrides[index] = object;
        Sandbox.CustomOverrides[object] = object;
    end;
end;

--[[
    Sandbox.getCustomOverride()
    Gets a custom override by index
]]
function Sandbox.getCustomOverride(index)
    if Sandbox.CustomOverrides[index] then
        return Sandbox.CustomOverrides[index];
    end;

    return nil;
end;

--[[
    Sandbox.wrapMethod()
    Wraps metamethods
]]
function Sandbox.wrapMethod(sandboxInstance, method)
    local sandboxMt = Sandbox.getInstance(sandboxInstance);
    local methodWrapped = setfenv(function(self, ...)
        local real = Sandbox.getReal(sandboxInstance, self);
        local realArgs = Sandbox.getReal(sandboxInstance, ...);
        local ret = Sandbox.wrap(sandboxInstance, method(real, realArgs));
        return ret;
    end, sandboxMt);

    Sandbox.addToWrappedCache(sandboxInstance, methodWrapped, method);

    return methodWrapped;
end;

--[[
    Sandbox.wrapInstance();
    Wraps a instance
]]
function Sandbox.wrapInstance(sandboxInstance, object)
    if typeof(object) == "Instance" then
         -- Create a userdata
         local proxy = newproxy(true);

         -- Get the metatable of the userdata
         local mt = getmetatable(proxy);

         -- Setup the indexing for the object
         mt.__index = (function(_, index)
            local preventedIndex = Sandbox.getIsObjectProtected(object);
            local customMethod = Sandbox.getCustomMethod(object, index);
            if customMethod then -- Return a custom method
                return Sandbox.wrapMethod(sandboxInstance, customMethod);
            end;

            local success, indexed = pcall(function() return object[index]; end);
            if success then -- Method/property is found inside the object
                local type = typeof(indexed);
                if preventedIndex then
                    return nil;
                elseif type == "Instance" then
                    return Sandbox.wrapInstance(sandboxInstance, indexed);
                elseif type == "function" then
                    return Sandbox.wrapMethod(sandboxInstance, indexed);
                else
                    return indexed;
                end;
            else
                return error(indexed, 2);
            end;
         end);

         -- Setup newindex to allow properties to be set
         mt.__newindex = (function(_, index, value)
             local protected = Sandbox.getPropertyOverride(object, index);
             if protected then
                 return protected();
             else
                 local newValue = Sandbox.getReal(sandboxInstance, value);
                 local success, message = pcall(function()
                     object[index] = newValue;
                 end);

                 if not success then
                     return error(message, 2);
                 end;
             end;
         end);

         -- Return the value of tostring for the object
         mt.__tostring = (function(_)
             return tostring(object);
         end);

         -- Set metatable to the object's metatable
         mt.__metatable = getmetatable(object);

         -- Add to cache
         Sandbox.addToWrappedCache(sandboxInstance, proxy, object);

         -- Finally, return the wrapped object
         return proxy;
    end;
end;

--[[
    Sandbox.wrapTable();
    Wraps tables in the sandbox
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
    Sandbox.wrap()
    Catches all instances accessed by the code
    running inside the sandbox.

    This function is paramount in preventing
    breakouts. Do not modify unless you really
    know what you are doing.
]]
function Sandbox.wrap(instance, ...)
    local tbl = {...};
    for key, value in pairs(tbl) do
        local keyCache = Sandbox.getWrappedObject(instance, key);
        local valueCache = Sandbox.getWrappedObject(instance, value);
        local keyType = typeof(key);
        local valueType = typeof(value);
        local wrappedKey, wrappedValue;
        if keyCache then
            wrappedKey = keyCache;
        end;

        if valueCache then
            wrappedValue = valueCache;
        end;

        if not wrappedKey then
            if keyType == "Instance" then
                wrappedKey = Sandbox.wrapInstance(instance, key);
            elseif keyType == "table" then
                wrappedKey = Sandbox.wrapTable(instance, key);
            end;
        end;

        if not wrappedValue then
            if valueType == "Instance" then
                wrappedValue = Sandbox.wrapInstance(instance, value);
            elseif valueType == "table" then
                wrappedValue = Sandbox.wrapTable(instance, value);
            end;
        end;

        tbl[key] = nil;
        tbl[wrappedKey or key] = wrappedValue or value;
    end;

    return unpack(tbl);
end;

--[[
    Sandbox.getReal()
    Returns the real object when the sandbox requests it.
]]
function Sandbox.getReal(instance, ...)
    local tbl = {};
    for key, value in pairs({...}) do
        local keyCache = instance.RealCache[key] or key;
        local valueCache = instance.RealCache[value] or value;
        tbl[keyCache] = valueCache;
    end;

    return unpack(tbl);
end;

--[[
    Sandbox.getWrappedObject()
    Returns from the cache a wrapped version of the object.
]]
function Sandbox.getWrappedObject(instance, object)
    if instance.WrappedCache[object] then
        return instance.WrappedCache[object];
    end;

    return nil;
end;

--[[
    Sandbox.addToWrappedCache()
    Helper function to add a wrapped object to the cache.
]]
function Sandbox.addToWrappedCache(instance, fakeObject, realObject)
    if not instance.WrappedCache[realObject] then
        instance.WrappedCache[realObject] = fakeObject;
        instance.RealCache[fakeObject] = realObject;
    end;
end;

--[[
    Sandbox.new()
    Creates a new instance of a sandbox.

    This is primarily setup for the user, however
    if further customization is needed - it can be done
    using the various helper functions
]]
function Sandbox.new(scriptObject, environment, customItems)
    assert(typeof(scriptObject) == "Instance", handleTypeError(scriptObject, "new", "Instance", 1));
    assert(scriptObject.ClassName == "Script", handleTypeError(scriptObject.ClassName, "new", "Script", 1));
    assert(typeof(environment) == "table", handleTypeError(environment, "new", "table", 2));
    assert(typeof(customItems) == "table", handleTypeError(customItems, "new", "table", 4));

    -- Create a new instance
    local instance = {
        Killed = false,
        environment = environment,
        RealCache = {},
        WrappedCache = {},
    };

    local environment = setmetatable({}, {
        __index = (function(_, index)
            if instance.Killed then
                return error("Script disabled.", 0);
            end;

            if customItems[index] then -- custom item (such as custom print, _G, etc)
                return Sandbox.wrap(instance, customItems[index]);
            elseif Sandbox.getCustomFunction(index) then
                return Sandbox.wrap(instance, Sandbox.getCustomFunction(index));
            elseif Sandbox.getCustomOverride(index) then
                local override = Sandbox.getCustomOverride(index);
                if typeof(override) == "function" then
                    return Sandbox.wrap(instance, override);
                end;

                return override;
            else
                local ind = environment[index];
                if typeof(ind) == "Instance" or typeof(ind) == "table" then
                    return Sandbox.wrap(instance, ind);
                end;

                return environment[index];
            end;
        end),

        __metatable = "The metatable is locked"
    });

    -- Add the instance of the sandbox to the instances table
    Sandbox.SandboxInstances[scriptObject] = instance;
    Sandbox.SandboxInstances[instance] = environment;

    return environment;
end;

--[[
    Sandbox.kill()
    Allows stopping the current execution of
    code inside the sandbox.
]]
function Sandbox.kill(scriptObject)
    assert(typeof(scriptObject) == "Instance", "Invalid arg #1 to Sandbox.kill (not a Instance)");
    assert(scriptObject.ClassName == "Script", "Invalid arg #1 to Sandbox.kill (not a Script)");

    -- Remove this instance from the Sandbox table to prevent
    -- memory leaks - this also deconstructs it.
    Sandbox.destroyInstance(scriptObject);
end;

return Sandbox;