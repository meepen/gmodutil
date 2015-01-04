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

function draw.GlowingText(text, font, x, y, col, colglow, colglow2)
	local bfont1 = header..font;
	local bfont2 = header..font.."2";
	fontdata.font = font;
	surface.SetFont(font);
	if(not made[font]) then
		local _, h = surface.GetTextSize("A");
		fontdata.blursize = 2;
		fontdata.size = h;
		surface.CreateFont(bfont1, fontdata);
		made[font] = true;
		fontdata.blursize = 4;
		fontdata.size = h;
		surface.CreateFont(bfont2, fontdata);
	end
	surface.SetTextPos(x,y);
	surface.SetTextColor(col);
	surface.DrawText(text);
		surface.SetFont(bfont1);
		surface.SetTextColor(colglow or ColorAlpha(col,150));
		surface.SetTextPos(x, y);
		surface.DrawText(text);
		surface.SetFont(bfont2);
		surface.SetTextColor(colglow2 or colglow and ColorAlpha(colglow,50) or ColorAlpha(col, 50));
		surface.SetTextPos(x, y);
		surface.DrawText(text);
end

--[[-----------
	Example
-----------]]--
--[[
local col = Color(255,0, 255,255);
local colglow = ColorAlpha(col,0);
local colglow2 = ColorAlpha(col,0);
local intensity, intensity2 = 120, 60;
local min, min2 = 40, 20
local speed = 3;

hook.Add("DrawOverlay", "", function()
	local offx = ScrW() / 2;
	local offy = ScrH() / 2;
	colglow.a = (math.sin(SysTime() * speed) / 2 + 0.5) * intensity + min;
	colglow2.a = (math.sin(SysTime() * speed) / 2 + 0.5) * intensity2 + min2;
	surface.SetDrawColor(0,0,0,255);
	surface.DrawRect(offx,offy,300, 30);
	draw.GlowingText("This is glowoowowow", "DermaDefault", 5+offx, 5+offy, col, colglow, colglow2);
end);
]]