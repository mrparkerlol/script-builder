--[[
    Written by Jacob (@monofur, https://github.com/mrteenageparker)

    Provides sandboxing for the scriptbuilder.
]]

local typeof = typeof;
local newproxy = newproxy;
local assert = assert;
local unpack = unpack;

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
function Sandbox.getInstance(instTable)
    if Sandbox.SandboxInstances[instTable] then
        return Sandbox.SandboxInstances[instTable];
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
    Sandbox.addMethodOverride()
    Adds a method override to sandbox
]]
function Sandbox.addMethodOverride(methodClass, methodName, func)
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
    Sandbox.getMethodOverride()
    Helper function to get the method overrides for a specific class
]]
function Sandbox.getMethodOverride(object, index)
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
    Sandbox.addCustomOverride()
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
    Sandbox.getCustomOverride()
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
    Sandbox.wrap()
    Catches all instances accessed by the code
    running inside the sandbox.

    This function is paramount in preventing
    breakouts. Do not modify unless you really
    know what you are doing.
]]
function Sandbox.wrap(instance, index, object)
    local type = typeof(object);
    local cache = Sandbox.getWrappedObject(instance, object, index);
    if cache then -- return object that has already been cached
        return cache;
    elseif Sandbox.getIsObjectProtected(object) then -- prevented object from being indexed
        return nil;
    end;

    -- Custom function handler
    local customFunction = Sandbox.getCustomFunction(index);
    if customFunction then
        object = customFunction;
    end;

    if type == "Instance" then
        -- Create a userdata
        local proxy = newproxy(true);

        -- Get the metatable of the userdata
        local mt = getmetatable(proxy);

        -- Setup the indexing for the object
        mt.__index = (function(_, index)
            local preventedIndex = Sandbox.getIsObjectProtected(object);
            local preventedMethod = Sandbox.getMethodOverride(object, index);
            if preventedIndex then -- prevents indexing objects inside preventList.Objects
                return nil;
            elseif preventedMethod then -- prevents indexing things like :Kick() and other destructive methods
                local cache = Sandbox.getWrappedObject(instance, object, index);
                if cache then -- Return from cache if it exists
                    return cache;
                else
                    local func = function(...)
                        return preventedMethod(...);
                    end;

                    -- Cache the prevented method to speed up performance
                    Sandbox.addToWrappedCache(instance, func, object, index);

                    return func;
                end;
            else
                -- Wrap the index anyways, otherwise the sandbox will allow
                -- the code to escape potentially
                local success, indexed = pcall(function() return object[index]; end);
                if success then
                    return Sandbox.wrap(instance, nil, indexed);
                else
                    return error(indexed, 2);
                end;
            end;
        end);

        -- Setup newindex to allow properties to be set
        mt.__newindex = (function(_, index, value)
            local protected = Sandbox.getPropertyOverride(object, index);
            if protected then
                return protected();
            else
                local newValue = Sandbox.getReal(instance, value);
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
        Sandbox.addToWrappedCache(instance, proxy, object);

        -- Finally, return the wrapped object
        return proxy;
    elseif type == "table" then
        local tbl = {};
        local canWrite = true;
        for key, value in pairs(object) do
            local newKey = Sandbox.wrap(instance, nil, key);
            local newValue = Sandbox.wrap(instance, nil, value);
            tbl[newKey] = newValue;

            local success = pcall(function()
                object[key] = nil;
                object[newKey] = newValue;
            end);

            if not success then
                canWrite = false;
            end;
        end;

        if not canWrite then -- Object is not writable, add it to cache and return new table
            Sandbox.addToWrappedCache(instance, tbl, object, index);
            return tbl;
        else -- Object is writable, shouldn't be cached
            return object;
        end;
    elseif type == "function" then
        -- Create the function
        local func = function(...)
            -- Make the arguments a table
            local args = {...};

            -- Get the real arguments
            local realArgs = Sandbox.getReal(instance, args);

            -- Attempt to call the function
            local results;
            if #realArgs >= 1 then
                results = {pcall(object, unpack(realArgs))};
            else
                results = {pcall(object, nil)};
            end;

            -- Was it successful?
            if results[1] then
                table.remove(results, 1); -- removes the success variable - the rest is the tuple

                for index, result in pairs(results) do
                    if Sandbox.getIsObjectProtected(result) then
                        table.remove(results, index);
                    elseif typeof(result) == "Instance" or typeof(result) == "function" then
                        results[index] = Sandbox.wrap(instance, nil, result);
                    elseif typeof(result) == "table" then
                        local canWrite = true;

                        local tbl = {};
                        for key, value in pairs(result) do
                            local newKey = Sandbox.wrap(instance, nil, key);
                            local newValue = Sandbox.wrap(instance, nil, value);

                            tbl[newKey] = newValue;

                            if canWrite then
                                local success = pcall(function()
                                    result[key] = nil;
                                    result[newKey] = newValue;
                                end);

                                if not success then
                                    canWrite = false;
                                end;
                            end;
                        end;

                        results[index] = not canWrite and tbl or result;
                    end;
                end;

                return unpack(results);
            else
                -- Function was unsuccessful - return the error to the caller
                return error(results[2], 2);
            end;
        end;

        -- Add function to the cache
        Sandbox.addToWrappedCache(instance, func, object, index);

        -- Return the function
        return func;
    else
        -- Nothing to sandbox, just return the value here instead
        return object;
    end;
end;

--[[
    Sandbox.getReal()
    Returns the real object when the sandbox requests it.
]]
function Sandbox.getReal(instance, objects)
    local tbl = {};
    if typeof(objects) == "table" then
        for _, object in pairs(objects) do
            if instance.RealCache[object] then
                table.insert(tbl, instance.RealCache[object]);
            else
                table.insert(tbl, object);
            end;
        end;

        return tbl;
    else
        if instance.RealCache[objects] then
            return instance.RealCache[objects];
        end;

        return objects;
    end;
end;

--[[
    Sandbox.getWrappedObject()
    Returns from the cache a wrapped version of the object.
]]
function Sandbox.getWrappedObject(instance, object, index)
    local success, indexed = pcall(function()
        return object[index];
    end);

    if success and instance.WrappedCache[indexed] then
        return instance.WrappedCache[indexed];
    else
        local override = index and Sandbox.getMethodOverride(object, index);
        if override then
            return override;
        elseif instance.WrappedCache[index] then
            return instance.WrappedCache[index];
        elseif instance.WrappedCache[object] then
            return instance.WrappedCache[object];
        end;
    end;

    return nil;
end;

--[[
    Sandbox.addToWrappedCache()
    Helper function to add a wrapped object to the cache.
]]
function Sandbox.addToWrappedCache(instance, fakeObject, realObject, index)
    if index then
        if not instance.WrappedCache[index] then
            instance.WrappedCache[index] = fakeObject;
            instance.RealCache[fakeObject] = realObject;
        end;
    else
        if not instance.WrappedCache[realObject] then
            instance.WrappedCache[realObject] = fakeObject;
            instance.RealCache[fakeObject] = realObject;
        end;
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
                return error("Script disabled.", 2);
            end;

            if customItems[index] then -- custom item (such as custom print, _G, etc)
                return Sandbox.wrap(instance, nil, customItems[index]);
            elseif Sandbox.getCustomOverride(index) then
                return Sandbox.getCustomOverride(index);
            else
                -- Return a wrapped version of the object if needed
                return Sandbox.wrap(instance, index, environment[index]);
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