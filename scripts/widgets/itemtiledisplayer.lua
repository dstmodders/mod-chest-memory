--widgets/itemtile.lua, but reworked to use data based on saved item in chestdisplay.lua
local Text = require "widgets/text"
local Image = require "widgets/image"
local Widget = require "widgets/widget"
local UIAnim = require "widgets/uianim"

--sauktux:
--I don't think I can really change anything here to improve performance.
--UIAnims shouldn't be too laggy, everything here is mostly "optimized" by Klei.
local ItemTile = Class(Widget, function(self, invitem)
    Widget._ctor(self, "ItemTile")
    self.item = invitem

    if self.item.show_spoiled then
        self.bg = self:AddChild(Image(HUD_ATLAS, "inv_slot_spoiled.tex"))
        self.bg:SetClickable(false)
    end

    if self.item.show_spoiled then
        self.spoilage = self:AddChild(UIAnim())
        self.spoilage:GetAnimState():SetBank("spoiled_meter")
        self.spoilage:GetAnimState():SetBuild("spoiled_meter")
        self.spoilage:SetClickable(false)
    end

    self.wetness = self:AddChild(UIAnim())
    self.wetness:GetAnimState():SetBank("wet_meter")
    self.wetness:GetAnimState():SetBuild("wet_meter")
    self.wetness:GetAnimState():PlayAnimation("idle")
    self.wetness:Hide()
    self.wetness:SetClickable(false)

    self.image = self:AddChild(Image(invitem.atlas, invitem.image, "default.tex"))

    self:Refresh()
end)

function ItemTile:Refresh()

    if self.item._stackable ~= nil then
        self:SetQuantity(self.item.stacksize)
    end

    if self.item.finiteusespercent then
        self:SetPercent(self.item.finiteusespercent)
    end
    if self.item.show_spoiled and self.item.perishpercent then
        self:SetPerishPercent(self.item.perishpercent)
    elseif (self.item._isfresh or self.item_isstale or self.item._isspoiled) and self.item.perishpercent then
        self:SetPercent(self.item.perishpercent)
    end

    if self.item._iswet then
        self.wetness:Show()
    else
        self.wetness:Hide()
    end
end

function ItemTile:SetQuantity(quantity)
    if not self.quantity then
        self.quantity = self:AddChild(Text(NUMBERFONT, 42))
        self.quantity:SetPosition(2, 16, 0)
    end
    self.quantity:SetString(tostring(quantity ~= nil and quantity or ""))
end

function ItemTile:SetPerishPercent(percent)
    --percent is approximated over the network, so check tags to
    --determine the correct color at the 50% and 20% boundaries.
    if percent < .51 and percent > .49 and self.item._isfresh then
        self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_green")
        self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_green")
    elseif percent < .21 and percent > .19 and self.item._isstale then
        self.spoilage:GetAnimState():OverrideSymbol("meter", "spoiled_meter", "meter_yellow")
        self.spoilage:GetAnimState():OverrideSymbol("frame", "spoiled_meter", "frame_yellow")
    else
        self.spoilage:GetAnimState():ClearAllOverrideSymbols()
    end
    --don't use 100% frame, since it should be replace by something like "spoiled_food" then
    self.spoilage:GetAnimState():SetPercent("anim", math.clamp(1 - percent, 0, .99))
end

function ItemTile:SetPercent(percent)
	if not self.item.hide_percentage then
		if not self.percent then
			self.percent = self:AddChild(Text(NUMBERFONT, 42))
			self.percent:SetPosition(5,-32+15,0)
		end
		local val_to_show = percent*100
		if val_to_show > 0 and val_to_show < 1 then
			val_to_show = 1
		end
		self.percent:SetString(string.format("%2.0f%%", val_to_show))
    end
end


return ItemTile