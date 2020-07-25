--[[
    Written by Jacob (@monofur, https://github.com/mrteenageparker)

    Provides sandboxing for the scriptbuilder.
]]

local typeof = typeof;
local newproxy = newproxy;
local assert = assert;

local function handleTypeError(var, typeExpected, argNum)
    return string.format("Invalid arg #%d to \"Sandbox:new\" (%s expected, got %s)", argNum, typeExpected, typeof(var));
end;

--[[
    Sandbox table for holding public functions
    and external APIs for the sandbox
]]
local Sandbox = {};
Sandbox.SandboxInstances = {}; -- Sandbox Instances table
Sandbox.InstancesCreated = {}; -- Instances created with Instance.new

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
        Sandbox.SandboxInstances[scriptObject] = nil; -- Deletes from memory
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
    Internal functions used by the sandbox itself - specifically for it.
]]
local InternalSandboxFunctions = {};

--[[
    InternalSandboxFunctions.wrap()
    Catches all instances accessed by the code
    running inside the sandbox.

    This function is paramount in preventing
    breakouts. Do not modify unless you really
    know what you are doing.
]]
function InternalSandboxFunctions.wrap(instance, index, object)
    local type = typeof(object);
    local cache = InternalSandboxFunctions.getWrappedObject(instance, object);
    if cache then -- return object that has already been created
        return cache;
    elseif instance.preventList.getObject(object, index) then -- prevented object from being indexed
        return nil;
    end;

    if type == "Instance" then
        -- Create a userdata
        local proxy = newproxy(true);

        -- Get the metatable of the userdata
        local mt = getmetatable(proxy);

        -- Setup the indexing for the object
        mt.__index = (function(self, index)
            local preventedIndex = instance.preventList.getObject(object, index);
            local preventedMethod = instance.preventList.getMethod(object, index);
            if preventedIndex then -- prevents indexing objects inside preventList.Objects
                return nil;
            elseif preventedMethod then -- prevents indexing things like :Kick() and other destructive methods
                local cache = InternalSandboxFunctions.getWrappedObject(instance, object[index]);
                if cache then -- Return from cache if it exists
                    return cache;
                else
                    local func = function(...)
                        return preventedMethod(...);
                    end;

                    InternalSandboxFunctions.addToWrappedCache(instance, func, object[index]);

                    return func;
                end;
            else
                -- Wrap the index anyways, otherwise the sandbox will allow
                -- the code to escape
                return InternalSandboxFunctions.wrap(instance, index, object[index]);
            end;
        end);

        -- Setup newindex to allow properties to be set
        mt.__newindex = (function(self, index, newvalue)
            local protected = instance.preventList.getProperty(object, index);
            if protected then
                return protected();
            else
                local success, message = pcall(function()
                    object[index] = newvalue;
                end);

                if not success then
                    return error(message, 2);
                end;
            end;
        end);

        -- Return the value of tostring for the object
        mt.__tostring = (function(self)
            return tostring(object);
        end);

        -- Set metatable to the object's metatable
        mt.__metatable = getmetatable(object);

        -- Add to cache
        InternalSandboxFunctions.addToWrappedCache(instance, proxy, object);

        -- Finally, return the wrapped object
        return proxy;
    elseif type == "function" then
        -- Create the function
        local func = (function(...)
            -- Make the arguments a table
            local args = {...};

            -- Get the real arguments
            local realArgs = InternalSandboxFunctions.getReal(instance, args);
            
            -- Attempt to call the function
            local success, message;
            if #realArgs >= 1 then
                success, message = instance.environment.pcall(object, unpack(realArgs));
            else
                success, message = instance.environment.pcall(object, nil);
            end;

            -- Was it successful?
            if success then
                -- Check the returned data
                if typeof(message) == "table" then -- Message is a table
                    -- If the index is attempting to get the environment or is the environment,
                    -- then just return the sandbox instance itself to prevent breaking out.
                    if index == "getfenv" or message.game and message.game == instance.environment.game then
                        return Sandbox.getInstance(instance);
                    end;

                    -- Iterates through the table, removes stuff from it
                    -- that shouldn't be in there - like results from
                    -- Instance:GetChildren()
                    for i=1, #message do
                        if instance.preventList.Objects[message[i]] then
                            table.remove(message, i);
                        end;
                    end;

                    -- Ultimately, return the message
                    return message;
                elseif typeof(message) == "Instance" then -- Message is an instance - return a wrapped version of it
                    return InternalSandboxFunctions.wrap(instance, index, message);
                elseif instance.preventList.Objects[message] then -- Message is a prevented object - return nil.
                    return nil;
                else
                    -- Just return the message - could just be a string.
                    return message;
                end;
            else
                -- Function was unsuccessful - return the error to the caller
                return error(message, 2);
            end;
        end);

        -- Add function to the cache
        InternalSandboxFunctions.addToWrappedCache(instance, func, object);

        -- Return the function
        return func;
    else
        -- Nothing to sandbox, just return the value here instead
        return object;
    end;
end;

--[[
    InternalSandboxFunctions.getReal()
    Returns the real object when the sandbox requests it.
]]
function InternalSandboxFunctions.getReal(instance, objects)
    local tbl = {};
    if #objects == 1 then
        if instance.RealCache[objects[1]] then
            return {instance.RealCache[objects[1]]};
        else
            return objects;
        end;
    else
        for _, object in pairs(objects) do
            if instance.RealCache[object] then
                table.insert(tbl, instance.RealCache[object]);
            else
                table.insert(tbl, object);
            end;
        end;
    end;

    return tbl;
end;

--[[
    InternalSandboxFunctions.getWrappedObject()
    Returns from the cache a wrapped version of the object.
]]
function InternalSandboxFunctions.getWrappedObject(instance, object)
    if instance.WrappedCache[object] then
        return instance.WrappedCache[object];
    end;

    return nil;
end;

--[[
    InternalSandboxFunctions.addToWrappedCache()
    Helper function to add a wrapped object to the
    cache.
]]
function InternalSandboxFunctions.addToWrappedCache(instance, fakeObject, realObject)
    if not instance.WrappedCache[realObject] then
        instance.WrappedCache[realObject] = fakeObject;
        instance.RealCache[fakeObject] = realObject;
    end;
end;

--[[
    Sandbox.new()
    Creates a new instance of a sandbox.
]]
function Sandbox.new(scriptObject, environment, preventList, customItems, customMethods)
    if not preventList then
        preventList = {
            Objects = {},
            Methods = {},
            Properties = {},
        };
    end;

    if not customItems then
        customItems = {};
    end;

    if not customMethods then
        customMethods = {};
    end;

    assert(typeof(scriptObject) == "Instance", handleTypeError(scriptObject, "Instance", 1));
    assert(scriptObject.ClassName == "Script", handleTypeError(scriptObject.ClassName, "Script", 1));
    assert(typeof(environment) == "table", handleTypeError(environment, "table", 2));
    assert(typeof(preventList) == "table", handleTypeError(preventList, "table", 3));
    assert(typeof(preventList.Objects) == "table", ("Bad argument #2 \"Sandbox:new\" (needs to have Objects table, got value %s)"):format(typeof(preventList.Objects)));
    assert(typeof(preventList.Methods) == "table", ("Bad argument #2 \"Sandbox:new\" (needs to have Methods table, got value %s)"):format(typeof(preventList.Methods)));
    assert(typeof(customItems) == "table", handleTypeError(customItems, "table", 4));
    assert(typeof(customMethods) == "table", handleTypeError(customMethods, "table", 5));

    -- Setup preventList for internal use
    --[[
        preventList.getMethod()
        Returns whether or not the method is apart of
        the object being indexed, and the method is also in
        the preventList.Methods table
    ]]
    function preventList.getMethod(object, index)
        local indexClass = rawget(preventList, 'Methods')[object.ClassName];
        if indexClass and indexClass[index:lower()] then
            return indexClass[index:lower()];
        end;

        return nil;
    end;

    --[[
        preventList.getProperty()
        Returns whether or not the property
        is protected or not
    ]]
    function preventList.getProperty(object, index)
        local indexClass = rawget(preventList, 'Properties')[object.ClassName];
        if indexClass and indexClass[index:lower()] then
            return indexClass[index:lower()];
        end;
        return false;
    end;

    --[[
        preventList.getObject()
        Gets whether or not the object is part of
        objects that are not supposed to be indexed,
        also checks if the object is part of the object
        being indexed.
    ]]
    function preventList.getObject(object, index)
        if rawget(preventList, 'Objects')[object] then
            -- Object found inside the table
            return true;
        end;
        return false;
    end;

    -- Create a new instance
    local instance = {
        Killed = false,
        environment = environment,
        RealCache = {},
        WrappedCache = {},
        preventList = preventList,
        customMethods = customMethods,
    };

    Sandbox.SandboxInstances[scriptObject] = instance;

    return setmetatable({}, {
        __index = (function(self, index)
            if instance.Killed then
                return error("Script disabled.", 0);
            end;

            if customItems[index] then -- custom item (such as custom print, _G, etc)
                return customItems[index];
            else
                -- Return a wrapped version of the object if needed
                return InternalSandboxFunctions.wrap(instance, index, environment[index]);
            end;
        end),

        __metatable = "The metatable is locked"
    });
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