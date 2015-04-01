local should_overwrite = IGNORE_COMPATIBILITY;
IGNORE_COMPATIBILITY = nil;

local lookup = {}
for i = ("a"):byte(), ("z"):byte() do
	table.insert(lookup, string.char(i));
	lookup[string.char(i)] = #lookup;
end
for i = ("A"):byte(), ("Z"):byte() do
	table.insert(lookup, string.char(i));
	lookup[string.char(i)] = #lookup;
end
for i = ("0"):byte(), ("9"):byte() do
	table.insert(lookup, string.char(i));
	lookup[string.char(i)] = #lookup;
end
table.insert(lookup, "_");
lookup["_"] = #lookup;
table.insert(lookup, " ");
lookup[" "] = #lookup;

function net.ReadBool()

	return net.ReadBit() == 1
	
end

net.WriteBool = net.WriteBit

local function isnormalstring(s)
	return s:find("[\x80-\xFF%z]") == nil;
end
local function isbeststring(s)
	return s:find("[^a-zA-Z0-9_%s]") == nil;
end

local function isnan(x)
	return x ~= x;
end
local NAN = {};

local function goodindex(x)
	if(isnan(x)) then return NAN; end
	return x;
end

local reading, writing;

local _type = type;
local function type(x)
	local t = _type(x)
	if(t == "table" and IsColor(x)) then
		return "Color"
	end
	if(TypeID(x) == TYPE_ENTITY) then
		return "Entity"
	end
	-- since we are forced to above 3 bits in MAX_BIT we are going to add 
	-- 7 types that will make it decrease
	-- network load
	if(x == 1 or x == 0) then return "bit" end
	if(t == "number" and x % 1 == 0 and x >= -0x7FFFFFFF and x <= 0xFFFFFFFF) then
		if(x <= 127 and x >= 0) then
			return "uintv"
		end
		if(x <= 0x7FFF and x >= -0x7FFF) then
			return "int16"
		end
		if(x <= 0x7FFFFFFF and x >= -0x7FFFFFFF) then
			return "int32"
		end
		return "uintv";
	end
	if(t == "string" and isbeststring(x)) then return "beststring"; end
	if(t == "string" and isnormalstring(x)) then return "normalstring"; end
	return t;
end

local headers = {
	string   = 0;
	number   = 1;
	table    = 2;
	boolean  = 3;
	endtable = 4;
	Vector   = 5;
	Angle    = 6;
	Color    = 7;
	Entity   = 8;
	bit      = 9;
	beststring=10;
	int16    = 11;
	int32    = 12;
	reference= 13;
	uintv    = 14;
	normalstring = 15;
};
local rheader = {};
for k,v in pairs(headers) do rheader[v] = k; end

local MAX_BIT = 4; -- max = 15;
local UINTV_SIZE = 6;
reading = {
	uintv = function()
		local i = 0;
		local ret = 0;
		while true do
			local t = net.ReadUInt(UINTV_SIZE);
			ret = ret + bit.lshift(t, i * UINTV_SIZE);
			if(not net.ReadBool()) then break; end
			i = i + 1;
		end
		return ret;
	end,
	
	normalstring = function()
		if(net.ReadBool()) then
			return util.Decompress(net.ReadData(reader.uintv()));
		else
			local ret = "";
			while true do 
				local chr = net.ReadUInt(7)
				if(chr == 0) then return ret; end
				ret = ret..string.char(chr);
			end
		end
	end,

	Color 		= net.ReadColor,
	boolean 	= net.ReadBool,
	number 		= net.ReadDouble,
	Entity 		= function()
		if(net.ReadBool()) then -- non null
			-- max networked entity index is 4095 in gmod
			return Entity(net.ReadUInt(12))
		end
		
		return NULL
	end,
	
	beststring  = function()
		if(net.ReadBool()) then
			return util.Decompress(net.ReadData(reading.uintv()));
		else
			local ret = "";
			while true do 
				local chr = net.ReadUInt(6)
				if(chr == 0) then return ret; end
				ret = ret..lookup[chr + 1];
			end
		end
	end,
	
	bit 		= net.ReadBit,
	reference = function(rs)
		return rs[reading.uintv()];
	end,
	int16 = function()
		return net.ReadInt(16);
	end,
	int32 = function()
		return net.ReadInt(32);
	end,
	string = function()
		if(net.ReadBool()) then -- compressed or not
			return util.Decompress(net.ReadData(reading.uintv()));
		else
			return net.ReadData(reading.uintv());
		end
	end,
	Vector = function()
		return Vector(net.ReadFloat(), net.ReadFloat(), net.ReadFloat());
	end,
	Angle = function()
		return Angle(net.ReadFloat(), net.ReadFloat(), net.ReadFloat());
	end,
	table = function(references)
		local ret = {};
		local references = references or {
			"__index",
			"__newindex",
			"self",
			"MetaName",
			"MetaType",
			"type",
		};
		references[#references + 1] = ret;
		local num = #references + 1;
		if(net.ReadBool()) then -- indices start at 1 and
			local max = reading.uintv(); -- go to max
			for i = 1, max do
				local type = net.ReadUInt(MAX_BIT);
				local v = reading[rheader[type]](references);
				if(type ~= headers.reference) then
					if(type == headers.table) then
						num = #references + 1;
					else
						references[num] = v;
						num = num + 1;
					end
				end
				ret[i] = v;
			end
		end
		while(true) do
			local type = net.ReadUInt(MAX_BIT);
			if(rheader[type] == "endtable") then break; end
			local k = reading[rheader[type]](references);
			if(type ~= headers.reference) then
				if(type == headers.table) then
					num = #references + 1;
				else
					references[num] = k;
					num = num + 1;
				end
			end
			type = net.ReadUInt(MAX_BIT);
			local v = reading[rheader[type]](references);
			if(type ~= headers.reference) then
				if(type == headers.table) then
					num = #references + 1;
				else
					references[num] = v;
					num = num + 1;
				end
			end
			ret[k] = v;
		end
		return ret;
	end
};


writing = {
	uintv = function(n)
		while(n > 0) do
			net.WriteUInt(n, UINTV_SIZE);
			n = bit.rshift(n, UINTV_SIZE);
			net.WriteBool(n > 0);
		end
	end,
	
	normalstring = function(s)
		local compressed = util.Compress(s);
		local c_len = compressed == nil and 0xFFFFFFFF or #compressed;
		if(c_len < #s / 8 * 7) then
			net.WriteBool(true);
			writing.uintv(c_len);
			net.WriteData(compressed, c_len);
		else
			net.WriteBool(false);
			for i = 1, s:len() do
				net.WriteUInt(s[i]:byte(), 7);
			end
			net.WriteUInt(0, 7);
		end
	end,
	
	beststring = function(s)
		local compressed = util.Compress(s);
		local c_len = compressed == nil and 0xFFFFFFFF or #compressed;
		if(c_len < #s / 8 * 6) then
			net.WriteBool(true);
			writing.uintv(c_len);
			net.WriteData(compressed, c_len);
		else
			net.WriteBool(false);
			for i = 1, s:len() do
				net.WriteUInt(lookup[s[i]] - 1, 6);
			end
			net.WriteUInt(0, 6);
		end
	end,

	bit = net.WriteBit,
	Color = net.WriteColor,
	boolean = net.WriteBool,
	number = net.WriteDouble,
	int16 = function(w)
		net.WriteInt(w, 16);
	end,
	int32 = function(d)
		net.WriteInt(d, 32);
	end,
	Entity = function(e)
		if(IsValid(e) or game.GetWorld() == e and e:EntIndex() < 2048) then
			net.WriteBool(true);
			net.WriteUInt(e:EntIndex(), 12);
			return;
		end
		net.WriteBool(false);
	end,
	Vector = function(v)
		net.WriteFloat(v.x);
		net.WriteFloat(v.y);
		net.WriteFloat(v.z);
	end,
	Angle = function(a)
		net.WriteFloat(a.p);
		net.WriteFloat(a.y);
		net.WriteFloat(a.r);
	end,
	string = function(x)
		local compressed = util.Compress(x);
		local c_len = compressed == nil and 0xFFFFFFFF or #compressed;
		local x_len = #x;
		if(c_len < x_len) then
			net.WriteBool(true);
			writing.uintv(c_len);
			net.WriteData(compressed, c_len);
		else -- we are doing this for zero embedded strings
			net.WriteBool(false);
			writing.uintv(x_len);
			net.WriteData(x, x_len);
		end
	end,
	table = function(tbl, indices, num)
		local done = {};
		num = num or 1;
		local indices = indices or {
			__index = 1;
			__newindex = 2;
			self = 3,
			MetaName = 4,
			MetaType = 5,
			type = 6,
		};
		indices[tbl] = num;
		num = num + 1;
		local t_len = #tbl;
		if(t_len ~= 0) then
			net.WriteBool(true);
			writing.uintv(t_len);
			for i = 1, t_len do
				done[i] = true;
				local v = tbl[i];
				if(indices[v]) then
					net.WriteUInt(headers.reference, MAX_BIT);
					writing.uintv(indices[v]);
				else
					local t = type(v);
					net.WriteUInt(headers[t], MAX_BIT);
					local _num = writing[t](v, rs, num);
					if(t ~= "table") then
						indices[goodindex(v)] = num;
						num = num + 1;
					else
						num = _num;
					end
				end
			end
		else
			net.WriteBool(false);
		end
		for k,v in next, tbl, nil do
			if(done[k]) then continue; end
			if(indices[k]) then
				net.WriteUInt(headers.reference, MAX_BIT);
				writing.uintv(indices[k]);
			else
				local t = type(k);
				net.WriteUInt(headers[t], MAX_BIT);
				local _num = writing[t](k, rs, num);
				if(t ~= "table") then
					indices[goodindex(k)] = num;
					num = num + 1;
				else
					num = _num;
				end
			end
			
			if(indices[v]) then
				net.WriteUInt(headers.reference, MAX_BIT);
				writing.uintv(indices[v]);
			else
				local t = type(v);
				net.WriteUInt(headers[t], MAX_BIT);
				local _num = writing[t](v,rs, num);
				if(t ~= "table") then
					indices[goodindex(v)] = num;
					num = num + 1;
				else
					num = _num;
				end
			end
		end
		net.WriteUInt(headers.endtable, MAX_BIT);
		return num;
	end
};

net.NWriteTable = writing.table;
net.NReadTable = reading.table;
if(should_overwrite) then
	net.WriteTable = net.NWriteTable;
	net.ReadTable = net.NReadTable;
end