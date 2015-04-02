local fs = file.Find("gmodutil/*.lua", "LUA");
if(SERVER) then
	for k,v in pairs(fs) do
		print(v);
		if(v:sub(1,3) == "sh_" or v:sub(1,3) == "sv_") then
			include("gmodutil/"..v);
		end
		if(v:sub(1,3) == "sh_" or v:sub(1,3) == "cl_") then
			AddCSLuaFile("gmodutil/"..v);
		end
	end
else
	for k,v in pairs(fs) do
		include("gmodutil/"..v);
	end
end