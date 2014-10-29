include("misc.lua");

--[[
	Localized variables
		Reason: prevent looking up variables from the global table every call
																		]]

local MsgC = MsgC;
local type = type;

--[[ 
	Make it available Server-side
	
								]]
local function GetTextSize(x)
	if(SERVER) then
		return string.len(x) * 12;
	else
		return surface.GetTextSize(x);
	end
end

--[[
	Do not mess with it unless you know what you are doing!
																]]

local function FixTabs(x, width)
	local curw = GetTextSize(x);
	local ret = "";
	while(curw < width) do
		x 		= x.." ";
		ret 	= ret.." ";
		curw 	= GetTextSize(x)
	end
	return ret
end

--[[
	Font based on default ClientScheme resource file
														]]
														
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

--[[
	Editable Variables:
		typecol: change and/or add types and colors it prints
		DebugFixToString: Add or change how it prints things
		DebugFixToStringColored: Add or change colors/printing styles
																]]

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

local function DebugFixToStringColored(a, iscom)
	local _t = type(a);
	if(_t == "string") then
		return {typecol.string, '"'..a:gsub(".", replacements)..'"'}; -- took from string.lua
	elseif(_t == "Vector") then
		return {typecol.func, "Vector", typecol.etc, "(", typecol.number, tostring(a.x), typecol.etc, ", "
			, typecol.number, tostring(a.y), typecol.etc, ", ", typecol.number, tostring(a.z), typecol.etc, ")"};
	elseif(_t == "Angle") then
		return {typecol.func, "Angle", typecol.etc, "(", typecol.number, tostring(a.p), typecol.etc, ", "
			, typecol.number, tostring(a.y), typecol.etc, ", ", typecol.number, tostring(a.r), typecol.etc, ")"};
	elseif(_t == "table" and IsColor(a)) then
		return {typecol.func, "Color", typecol.etc, "(", typecol.number, tostring(a.r), typecol.etc, ", ", typecol.number,
			tostring(a.g), typecol.etc, ", ", typecol.number, tostring(a.b), typecol.etc, ", ", typecol.number, 
				tostring(a.a), typecol.etc, ")", typecol.etc, "; ", typecol.com, "-- ", a, "� ", typecol.com, string.format("(0x%02X%02X%02X%02X)", a.r, a.g, a.b, a.a)}, true;
	elseif(_t == "Player") then
		return {typecol.func, "Player", typecol.etc, "(", typecol.number, tostring(a:UserID()), typecol.etc,
			")"..(iscom and "; " or ""), typecol.com, (iscom and "-- "..(a:IsValid() and a.Nick and a:Nick() or "missing_nick") or "")}, true;
	elseif(IsEntity(a)) then
		return {typecol.func, "Entity", typecol.etc, "(", typecol.number, tostring(a:EntIndex()), typecol.etc,
			")"..(iscom and "; " or ""), typecol.com, (iscom and "-- "..(a:IsValid() and a.GetClass and a:GetClass() or "unknown_class"))}, true;
	end
	if(not typecol[_t]) then
		return {typecol.unk, "(".._t..") "..tostring(a)};
	else
		return {typecol[_t], tostring(a)};
	end
end

local function DebugFixToString(a, iscom)
	local ret = "";
	local rets, osc = DebugFixToStringColored(a);
	for i = 2, #rets, 2 do
		ret = ret.. rets[i];
	end
	return ret;
end

--[[
	Function: DebugPrintTable
	Usage: DebugPrintTable( _IN_ to_print )
	Returns: nil
													]]

function DebugPrintTable(tbl, ind, done)
	local buffer = {};
	local rbuf = {};
	local mw = 0;
	local ws = {};
	local ind = ind or 0;
	local done = done or {};
	done[tbl] = true;
	if(CLIENT) then
		surface.SetFont("ConsoleText");
	end
	for k,v in pairs(tbl) do
		rbuf[#rbuf + 1]  = k;
		buffer[#buffer + 1] = "["..DebugFixToString(k).."] ";
		ws[#buffer] = GetTextSize(buffer[#buffer]);
		mw = math.max(ws[#buffer], mw);
	end
	local str = string.rep(" ", ind);
	if(ind == 0) then MsgN("\n"); end
	MsgC(typecol.etc, "{\n");
	local rstr = str..string.rep(" ", 4);
	
	for i = 1, #buffer do
		local overridesc = false;
		local v = rbuf[i];
		MsgC(typecol.etc, rstr.."[");
		MsgC(unpack((DebugFixToStringColored(v))));
		MsgC(typecol.etc, "] "..FixTabs(buffer[i], mw), typecol.etc, "= ");
		if(type(tbl[v]) == "table" and not IsColor(tbl[v]) and not done[tbl[v]]) then
			DebugPrintTable(tbl[v], ind + 4, done);
		else
			local args, osc = DebugFixToStringColored(tbl[v], true);
			overridesc = osc;
			MsgC(unpack(args));
		end
		if(not overridesc) then
			MsgC(typecol.etc, ";");
		end
		MsgN("");
	end
	MsgC(typecol.etc, str.."}");
	if(ind == 0) then
		MsgN("");
	end
end
