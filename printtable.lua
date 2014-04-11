include("misc.lua");

--[[
	Localized variables
		Reason: prevent looking up variables from the global table every call
																		]]

local MsgC = MsgC;
local type = type;

--[[
	Do not mess with it unless you know what you are doing!
																]]

local function FixTabs(x, width)
	local curw = surface.GetTextSize(x);
	local ret = "";
	while(curw < width) do
		x 		= x.." ";
		ret 	= ret.." ";
		curw 	= surface.GetTextSize(x);
	end
	return ret
end

--[[
	Font based on default ClientScheme resource file
														]]
														
local linux = system.IsLinux();
local mac	= system.IsOSX();
local win	= system.IsWindows();


surface.CreateFont("ConsoleText", {
	font	= ((linux or mac) and "Verdana" or "Lucida Console");
	size	= (mac and 11 or linux and 14 or 10);
	weight	= 500;
});

--[[
	Editable Variables:
		typecol: change and/or add types and colors it prints
		DebugFixToString: Add or change how it prints things
		DebugFixToStringColored: Add or change colors/printing styles
																]]

local typecol = {
	["function"]	= Color(0,	 150, 192);
	["number"] 		= Color(244, 146, 102);
	["string"] 		= Color(128, 128, 128);
	["table"]		= Color(40,  175, 140);
	["func"]		= Color(0,	 150, 192);
	["etc"]			= Color(189, 195, 199);
	["unk"]			= Color(255, 255, 255);
};

local function DebugFixToString(a)
	local _t = type(a);
	if(_t == "string") then
		return '"'..string.Replace(string.Replace(a, '"', '\\"'), '\\', '\\\\')..'"';
	elseif(_t == "Vector") then
		return "Vector("..tostring(a.x)..", "..tostring(a.y)..", "..tostirng(a.z)..")";
	elseif(_t == "Angle") then
		return "Angle("..tostring(a.p)..", "..tostring(a.y)..", "..tostirng(a.r)..")";
	elseif(_t == "table" and IsColor(a)) then
		return "Color("..tostring(a.r)..", "..tostring(a.g)..", "..tostring(a.b)..", "..tostring(a.a)..")¦";
	elseif(_t == "Player") then
		return "player.GetByID("..a:EntIndex()..") ["..(a.Nick and a:Nick() or "missing_nick").."]";
	elseif(_t == "Entity" or regs and regs[_t] and regs[_t].MetaBaseClass and regs[_t].MetaBaseClass.MetaName == "Entity") then
		return "Entity("..tostring(a:EntIndex())..") ["..(a.GetClass and a:GetClass() or "unknown_class").."]";
	end
	if(not typecol[_t]) then
		return "(".._t..") "..tostring(a);
	else
		return tostring(a);
	end
end

local function DebugFixToStringColored(a)
	local _t = type(a);
	if(_t == "string") then
		return typecol.string, '"'..string.Replace(string.Replace(a, '"', '\\"'), '\\', '\\\\')..'"';
	elseif(_t == "Vector") then
		return typecol.func, "Vector", typecol.etc, "(", typecol.number, tostring(a.x), typecol.etc, ", "
			, typecol.number, tostring(a.y), typecol.etc, ", ", typecol.number, tostring(a.z), typecol.etc, ")";
	elseif(_t == "Angle") then
		return typecol.func, "Angle", typecol.etc, "(", typecol.number, tostring(a.p), typecol.etc, ", "
			, typecol.number, tostring(a.y), typecol.etc, ", ", typecol.number, tostring(a.r), typecol.etc, ")";
	elseif(_t == "table" and IsColor(a)) then
		return typecol.func, "Color", typecol.etc, "(", typecol.number, tostring(a.r), typecol.etc, ", ", typecol.number,
			tostring(a.g), typecol.etc, ", ", typecol.number, tostring(a.b), typecol.etc, ", ", typecol.number, 
				tostring(a.a), typecol.etc, ")", a, "¦";
	elseif(_t == "Player") then
		return typecol.func, "player.GetByID", typecol.etc, "(", typecol.number, tostring(a:EntIndex()), typecol.etc,
			")", typecol.unk, "["..(a.Nick and a:Nick() or "missing_nick").."]";
	elseif(_t == "Entity" or regs and regs[_t] and regs[_t].MetaBaseClass and regs[_t].MetaBaseClass.MetaName == "Entity") then
		return typecol.func, "Entity", typecol.etc, "(", typecol.number, tostring(a:EntIndex()), typecol.etc,
			") ", typecol.unk, "["..(a.GetClass and a:GetClass() or "unknown_class").."]";
	end
	if(not typecol[_t]) then
		return typecol.unk, "(".._t..") "..tostring(a);
	else
		return typecol[_t], tostring(a);
	end
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
	local done = done or {[tbl] = true};
	surface.SetFont("ConsoleText");
	for k,v in pairs(tbl) do
		rbuf[#rbuf + 1]  = k;
		buffer[#buffer + 1] = "["..DebugFixToString(k).."] ";
		ws[#buffer] = surface.GetTextSize(buffer[#buffer]);
		mw = math.max(ws[#buffer], mw);
	end
	local str = "";
	for i = 1, ind do
		str = str.." ";
	end
	if(ind == 0) then MsgN("\n"); end
	MsgC(typecol.etc, "{\n");
	local rstr = str;
	for i = 1, 4 do
		rstr = rstr.." ";
	end
	for i = 1, #buffer do
		MsgC(typecol.etc, rstr.."[");
		MsgC(DebugFixToStringColored(rbuf[i]));
		MsgC(typecol.etc, "] ");
		Msg(FixTabs(buffer[i], mw));
		MsgC(typecol.etc, "= ");
		if(type(tbl[rbuf[i]]) == "table" and not IsColor(tbl[rbuf[i]]) and not done[tbl[rbuf[i]]]) then
			done[tbl[rbuf[i]]] = true;
			DebugPrintTable(tbl[rbuf[i]], ind + 4, done);
		else
			local args = {DebugFixToStringColored(tbl[rbuf[i]])};
			for i = 1, #args, 2 do
				MsgC(args[i], args[i+1]);
			end
		end
		MsgC(typecol.etc, ";");
		MsgN("");
	end
	MsgC(typecol.etc, str.."}");
	if(ind == 0) then
		MsgN("");
	end
end