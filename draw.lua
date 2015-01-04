local fontdata = {
	blursize = 2;
	italic = false;
	strikeout = false;
	additive = false;
	outline = false;
	underline = false;
	antialias = true;
};
local header = "glow_text_";
surface.madefonts = surface.madefonts or {};
local made = surface.madefonts;
local wtable = {};

function draw.GlowingText(text, font, x, y, col, colglow, colglow2)
	local bfont1 = header..font;
	local bfont2 = header..font.."2";
	fontdata.font = font;
	surface.SetFont(font);
	wtable[1] = 0;
	for i = 1, #text do
		wtable[i + 1] = surface.GetTextSize(text[i]) + wtable[i];
	end
	wtable[1] = -1; -- fixes glitch
	if(not made[font]) then
		local _, h = surface.GetTextSize("A");
		fontdata.blursize = 2;
		fontdata.size = h + 2;
		surface.CreateFont(bfont1, fontdata);
		made[font] = true;
		fontdata.blursize = 4;
		fontdata.size = h + 4;
		surface.CreateFont(bfont2, fontdata);
	end
	surface.SetTextPos(x,y);
	surface.SetTextColor(col);
	surface.DrawText(text);
	for i = 1, #text do
		local cw = table.remove(wtable, 1);
		surface.SetFont(bfont1);
		surface.SetTextColor(colglow or ColorAlpha(col,150));
		surface.SetTextPos(x + cw, y);
		surface.DrawText(text[i]);
		surface.SetFont(bfont2);
		surface.SetTextColor(colglow2 or colglow and ColorAlpha(colglow,50) or ColorAlpha(col, 50));
		surface.SetTextPos(x + cw, y - 1);
		surface.DrawText(text[i]);
	end
	table.remove(wtable,1);
end

--[[-----------
	Example
-----------]]--
--[[
local col = Color(255,255,0,255);
local colglow = Color(255,255,0,100);

hook.Add("DrawOverlay", "", function()
	draw.GlowingText("Gey!", "DermaDefault", 5, 5, col);
end);
]]