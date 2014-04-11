
--[[
	Function: IsColor
	Usage: IsColor( _IN_ any_object )
	Returns: boolean bIsColor
											]]

function IsColor(col)
	if(not col) then return false; end
	if(not type(col) == "table") then return false; end
	if(not col.r or not col.g or not col.b or not col.a) then
		return false;
	end
	for k,v in pairs(col) do
		if(k == 'r' or k == 'g' or k == 'b' or k == 'a') then continue; end
		print("not");
		return false;
	end
	return true;
end