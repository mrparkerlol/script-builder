repeat wait() until getmetatable(shared);

local sandbox = shared('Sandbox');
local config = shared(script);

setfenv(0, sandbox);
setfenv(1, sandbox);

local function exec(src)
	local s,m = loadstring(src, 'SB-Script');
	if not s then
		return error(m, 0);
	else
		return setfenv(s, sandbox)();
	end;
end;

exec(config.src);