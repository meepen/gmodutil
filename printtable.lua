--[[-----------------------------------------------------------------------------
	Localized variables
		Reason: prevent looking up variables from the global table every call
-----------------------------------------------------------------------------]]--

local MsgC = MsgC;
local type = type;

--[[---------------------------------
	Make it available Server-side
---------------------------------]]--
local function GetTextSize(x)
	if(SERVER) then
		return x:len(), 1;
	else
		return surface.GetTextSize(x);
	end
end

--[[-----------------------------------------------------------
	Do not mess with it unless you know what you are doing!
-----------------------------------------------------------]]--

local function FixTabs(x, width)
	local curw = GetTextSize(x);
	local ret = "";
	while(curw < width) do -- not using string.rep since linux
		x 		= x.." ";
		ret 	= ret.." ";
		curw 	= GetTextSize(x);
	end
	return ret;
end

--[[----------------------------------------------------
	Font based on default ClientScheme resource file
----------------------------------------------------]]--
														
local linux = system.IsLinux();
local mac	= system.IsOSX();
local win	= system.IsWindows();


if(CLIENT) then
	surface.CreateFont("ConsoleText", {
		font	= ((linux or mac) and "Verdana" or "Lucida Console");
		size	= (mac and 11 or linux and 14 or 10);
		weight	= 500;
	});
end

--[[---------------------------------------------------------------------
	Editable Variables:
		typecol: change and/or add types and colors it prints
		DebugFixToString: Add or change how it prints things
		DebugFixToStringColored: Add or change colors/printing styles
---------------------------------------------------------------------]]--

local typecol = {
	["function"]	= Color(000, 150, 192);
	["number"] 		= Color(244, 146, 102);
	["string"] 		= Color(128, 128, 128);
	["table"]		= Color(040, 175, 140);
	["func"]		= Color(000, 150, 192);
	["etc"]			= Color(189, 195, 199);
	["unk"]			= Color(255, 255, 255);
	["com"]			= Color(000, 128, 000);
};

local replacements = {
	["\n"]	= "\\n";
	["\r"]	= "\\r";
	["\v"]	= "\\v";
	["\f"]	= "\\f";
	["\x00"]= "\\x00";
	["\\"]	= "\\\\";
	["\""]	= "\\\"";
}

local function DebugFixToStringColored(obj, iscom)
	local type = type(obj);
	if(type == "string") then
		return {typecol.string, '"'..obj:gsub(".", replacements)..'"'}; -- took from string.lua
	elseif(type == "Vector") then
		return {typecol.func, "Vector", typecol.etc, "(", typecol.number, tostring(obj.x), typecol.etc, ", "
			, typecol.number, tostring(obj.y), typecol.etc, ", ", typecol.number, tostring(obj.z), typecol.etc, ")"};
	elseif(type == "Angle") then
		return {typecol.func, "Angle", typecol.etc, "(", typecol.number, tostring(obj.p), typecol.etc, ", "
			, typecol.number, tostring(obj.y), typecol.etc, ", ", typecol.number, tostring(obj.r), typecol.etc, ")"};
	elseif(type == "table" and IsColor(obj)) then
		return {typecol.func, "Color", typecol.etc, "(", typecol.number, tostring(obj.r), typecol.etc, ", ", typecol.number,
			tostring(obj.g), typecol.etc, ", ", typecol.number, tostring(obj.b), typecol.etc, ", ", typecol.number, 
				tostring(obj.a), typecol.etc, ")", typecol.etc, "; ", typecol.com, "-- ", obj, "� ", typecol.com, string.format("(0x%02X%02X%02X%02X)", obj.r, obj.g, obj.b, obj.a)}, true;
	elseif(type == "Player") then
		return {typecol.func, "Player", typecol.etc, "(", typecol.number, tostring(obj:UserID()), typecol.etc,
			")"..(iscom and "; " or ""), typecol.com, (iscom and "-- "..(obj:IsValid() and obj.Nick and obj:Nick() or "missing_nick") or "")}, true;
	elseif(IsEntity(obj)) then
		return {typecol.func, "Entity", typecol.etc, "(", typecol.number, tostring(obj:EntIndex()), typecol.etc,
			")"..(iscom and "; " or ""), typecol.com, (iscom and "-- "..(obj:IsValid() and obj.GetClass and obj:GetClass() or "unknown_class"))}, true;
	end
	if(not typecol[type]) then
		return {typecol.unk, "("..type..") "..tostring(obj)};
	else
		return {typecol[type], tostring(obj)};
	end
end

local function DebugFixToString(obj, iscom)
	local ret = "";
	local rets, osc = DebugFixToStringColored(obj, iscom);
	for i = 2, #rets, 2 do
		ret = ret.. rets[i];
	end
	return ret;
end

--[[------------------------------------------------------------------------------
	Function: DebugPrintTable
	Usage: DebugPrintTable( _IN_ to_print, _RESERVED_ spaces, _RESERVED_ done)
	Returns: nil
------------------------------------------------------------------------------]]--

function DebugPrintTable(tbl, spaces, done)
	local buffer = {};
	local rbuf = {};
	local maxwidth = 0;
	local spaces = spaces or 0;
	local done = done or {};
	done[tbl] = true;
	if(CLIENT) then
		surface.SetFont("ConsoleText");
	end
	for key,val in pairs(tbl) do
		rbuf[#rbuf + 1]  = key;
		buffer[#buffer + 1] = "["..DebugFixToString(key).."] ";
		maxwidth = math.max(GetTextSize(buffer[#buffer]), maxwidth);
	end
	local str = string.rep(" ", spaces);
	if(spaces == 0) then MsgN("\n"); end
	MsgC(typecol.etc, "{\n");
	local tabbed = str..string.rep(" ", 4);
	
	for i = 1, #buffer do
		local overridesc = false;
		local key = rbuf[i];
		local value = tbl[key];
		MsgC(typecol.etc, tabbed.."[");
		MsgC(unpack((DebugFixToStringColored(key))));
		MsgC(typecol.etc, "] "..FixTabs(buffer[i], maxwidth), typecol.etc, "= ");
		if(type(value) == "table" and not IsColor(value) and not done[value]) then
			DebugPrintTable(tbl[key], spaces + 4, done);
		else
			local args, osc = DebugFixToStringColored(value, true);
			overridesc = osc;
			MsgC(unpack(args));
		end
		if(not overridesc) then
			MsgC(typecol.etc, ";");
		end
		MsgN("");
	end
	MsgC(typecol.etc, str.."}");
	if(spaces == 0) then
		MsgN("");
	end
end
