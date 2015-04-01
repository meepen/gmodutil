local should_overwrite = IGNORE_COMPATIBILITY;
IGNORE_COMPATIBILITY = nil;

local reading, writing;


local _type = type;
local function type(x)
	local t = _type(x);
	if(t == "table" and IsColor(x)) then
		return "Color";
	end
	if(TypeID(x) == TYPE_ENTITY) then
		return "Entity";
	end
	-- since we are forced to above 3 bits in MAX_BIT we are going to add 
	-- 7 types that will make it decrease
	-- network load
	if(x == 1 or x == 0) then return "bit"; end
	if(t == "number" and x % 1 == 0) then
		if(x <= 127 and x >= -127) then
			return "int8";
		end
		if(x <= 0x7FFF and x >= -0x7FFF) then
			return "int16";
		end
		if(x <= 0x7FFFFFFF and x >= -0x7FFFFFFF) then
			return "int32";
		end
	end
	return t;
end

local headers = {
	string 	= 0;
	number 	= 1;
	table 	= 2;
	boolean	= 3;
	endtable= 4;
	Vector	= 5;
	Angle	= 6;
	Color	= 7;
	Entity	= 8;
	bit		= 9;
	int8	= 10;
	int16 	= 11;
	int32	= 12;
	reference=13;
};
local rheader = {};
for k,v in pairs(headers) do rheader[v] = k; end

local MAX_BIT = 4; -- max = 15;
local REFERENCE_BIT = 12;

reading = {
	Color 		= net.ReadColor,
	boolean 	= net.ReadBool,
	number 		= net.ReadDouble,
	Entity 		= net.ReadEntity,
	bit 		= net.ReadBit,
	reference = function(rs)
		return rs[net.ReadUInt(REFERENCE_BIT)];
	end,
	int8 = function()
		return net.ReadInt(8);
	end,
	int16 = function()
		return net.ReadInt(16);
	end,
	int32 = function()
		return net.ReadInt(32);
	end,
	string = function()
		if(net.ReadBool()) then -- compressed or not
			return util.Decompress(net.ReadData(net.ReadUInt(16)));
		else
			return net.ReadData(net.ReadUInt(16));
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
		local references = references or {};
		references[#references + 1] = ret;
		local num = #references + 1;
		if(net.ReadBool()) then -- indices start at 1 and
			local max = net.ReadUInt(16); -- go to max
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
	bit = net.WriteBit,
	Color = net.WriteColor,
	boolean = net.WriteBool,
	number = net.WriteDouble,
	int8  = function(b)
		net.WriteInt(b, 8);
	end,
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
		if(#compressed < #x) then
			net.WriteBool(true);
			local len = bit.band(#compressed, 0x7FFF);
			net.WriteUInt(len, 16);
			net.WriteData(compressed, len);
		else -- we are doing this for zero embedded strings
			net.WriteBool(false);
			local len = bit.band(#x, 0x7FFF);
			net.WriteUInt(len, 16);
			net.WriteData(x, len);
		end
	end,
	table = function(tbl, indices, num)
		local done = {};
		num = num or 1;
		local indices = indices or {};
		indices[tbl] = num;
		num = num + 1;
		if(#tbl ~= 0) then
			net.WriteBool(true);
			net.WriteUInt(#tbl, 16);
			for i = 1, #tbl do
				done[i] = true;
				local v = tbl[i];
				if(indices[v]) then
					net.WriteUInt(headers.reference, MAX_BIT);
					net.WriteUInt(indices[v], REFERENCE_BIT);
				else
					local t = type(v);
					net.WriteUInt(headers[t], MAX_BIT);
					local _num = writing[t](v, rs, num);
					if(t ~= "table") then
						indices[v] = num;
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
				net.WriteUInt(indices[k], REFERENCE_BIT);
			else
				local t = type(k);
				net.WriteUInt(headers[t], MAX_BIT);
				local _num = writing[t](k, rs, num);
				if(t ~= "table") then
					indices[k] = num;
					num = num + 1;
				else
					num = _num;
				end
			end
			
			if(indices[v]) then
				net.WriteUInt(headers.reference, MAX_BIT);
				net.WriteUInt(indices[v], REFERENCE_BIT);
			else
				local t = type(v);
				net.WriteUInt(headers[t], MAX_BIT);
				local _num = writing[t](v,rs, num);
				if(t ~= "table") then
					indices[v] = num;
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
	net.WriteTable = writing.table;
	net.ReadTable = reading.table;
end