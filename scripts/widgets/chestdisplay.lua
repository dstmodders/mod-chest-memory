local InvSlot = require "widgets/invslot_chestmemory"
local Widget = require "widgets/widget"
local Text = require "widgets/text"
local ImageButton = require "widgets/imagebutton"
local Image = require "widgets/image"
local ItemTile = require "widgets/itemtiledisplayer"
local ContainerData = require("persistentcontainerdata")


--// Mod options
local function GetConfig(name)
    local mod = "Chest Memory"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end

local highlight_onmouseover = GetConfig("highlight_onmouseover")
local highlightpause_button = GetConfig("highlightpause_button")
local widget_displaytype = GetConfig("widget_displaytype")
local widget_scale = GetConfig("widget_scale")/10
local default_show = GetConfig("default_show")
local scale_changer = GetConfig("widget_highlightsize")
--\\ Mod options


local mod_prefix = "MOD_ChestMemory_"
local x_size,y_size

local right_arrow_pos,left_arrow_pos,arrow_scale,historytime_pos,historytime_font,historytime_font_size
right_arrow_pos = {x = 140,y = 0}
left_arrow_pos = {x = -140, y = 0}
arrow_scale = 0.6
historytime_pos = {x = 0, y = 200}
historytime_font = BODYTEXTFONT
historytime_font_size = 48


local function CreateBasicItemInfoForItem(item)
    -- Generate all the needed info for me to display, save and load all the item display necessities.
    local newitem = {}
    if not (item and item.replica and item.replica.inventoryitem) then
        return newitem
    end

    newitem.prefab = item.prefab

    newitem.show_spoiled = item and (item:HasTag("show_spoiled") or item:HasTag("fresh") or item:HasTag("stale") or item:HasTag("spoiled")) or nil
    if not newitem.show_spoiled then
        for k,v in pairs(FOODTYPE) do
            if item:HasTag("edible"..v) then
                newitem.show_spoiled = true
                break
            end
        end
    end
    newitem._isfresh = item:HasTag("fresh") or nil
    newitem._isstale = item:HasTag("stale") or nil
    newitem._isspoiled = item:HasTag("spoiled") or nil

    newitem.inv_image_bg = item and item.inv_image_bg or nil

    newitem.atlas = item.replica.inventoryitem:GetAtlas()
    newitem.image = item.replica.inventoryitem:GetImage()

    newitem._stackable = item and (item.replica.stackable ~= nil) or nil
    newitem.stacksize = item and item.replica.stackable and item.replica.stackable:StackSize() or nil

    newitem._isvalid = item and item:IsValid() or nil

    local classified = item.replica.inventoryitem.classified
    
    if classified then--Classified sometimes doesn't load properly on servers.
        newitem.perishpercent = classified.perish:value() ~= 63 and classified.perish:value()/62 or nil
        newitem.finiteusespercent = classified.percentused:value() ~= 255 and classified.percentused:value()/100 or nil
    end

    newitem.hide_percentage = item and item:HasTag("hide_percentage") or nil
    newitem._iswet = item:GetIsWet() or nil
    
    return newitem
end


local ChestDisplay = Class(Widget, function(self,owner)
        Widget._ctor(self,"ChestDisplay")
        
        x_size,y_size = TheSim:GetScreenSize() 
        --// self variables
        self.owner = owner
        local x,y,z = self.owner.Transform:GetWorldPosition()
        self.pos = {x = x, y = y, z = z}
        self.ishidden = false
        self.displaytype = ThePlayer.components.chestmemorymanager:GetDisplayType() or (default_show and widget_displaytype)
        self._alreadyopenedonce = false --Chest History: So item history doesn't update while player is in chest
        self.time_since_closed = 0 -- Chest History: Saving and resetting _alreadyopenedonce variable
        self.last_updated = 0
        self.history_index = 0
        self.inv = {} -- These are the InvSlot widgets. Only important for refreshing
        self.chestmemorymanager = ThePlayer.components.chestmemorymanager
        self.boat = TheWorld.Map:GetPlatformAtPoint(self.pos.x,self.pos.z)
        self.chest_type = self.boat and "boat" or "static"
        self.world = TheWorld:HasTag("cave") and "caves" or "surface"
        
        self.CS_contents = {}
        self.CS_history = {}
        self.CS_historytime = {}
        
        --\\ self variables
        
        --// Widgets
        local container = owner.replica.container
        local widget = container:GetWidget()
        if highlightpause_button and highlightpause_button ~= 0 then --If ya' don't have a special key, then ya' don' need any history.
            
            self.scroll_left_fn = function() self:MoveTowardsThePast() end
            self.scroll_right_fn = function() self:MoveTowardsThePresent() end
            
            
            self.scroll_right = self:AddChild(ImageButton("images/ui.xml","arrow2_right_down.tex","arrow2_right_down.tex","arrow2_right_down.tex"))
            self.scroll_right:SetPosition(right_arrow_pos.x,right_arrow_pos.y)
            self.scroll_right:SetScale(arrow_scale)
            self.scroll_right:SetOnClick(self.scroll_right_fn)
            
            
            self.scroll_left = self:AddChild(ImageButton("images/ui.xml","arrow2_left_down.tex","arrow2_left_down.tex","arrow2_left_down.tex"))
            self.scroll_left:SetPosition(left_arrow_pos.x,left_arrow_pos.y)
            self.scroll_left:SetScale(arrow_scale)
            self.scroll_left:SetOnClick(self.scroll_left_fn)
            
            
            self.historytime = self:AddChild(Text(historytime_font,historytime_font_size))
            self.historytime:SetString("")
            self.historytime:SetPosition(historytime_pos.x,historytime_pos.y)
            
        end
        
        for i, v in ipairs(widget.slotpos or {}) do
            local bgoverride = widget.slotbg ~= nil and widget.slotbg[i] or nil
            local slot = InvSlot(i,
                                 bgoverride ~= nil and bgoverride.atlas or "images/hud.xml",
                                 bgoverride ~= nil and bgoverride.image or "inv_slot.tex",
                                 self.owner,
                                 container)
            self.inv[i] = self:AddChild(slot)
            self.inv[i]:SetClickable(false)
            slot:MoveToBack()
            slot:SetPosition(v)
        end
        
        --\\ Widgets
        
        --// Event Listener(s)
        self.onrefreshfn = function() self:UpdateItemMemory() self._alreadyopenedonce = true end
        self.onmouseoverfn = function() self.chestmemorymanager:SetHighlightedChest(owner) end
        self.onmouseoutfn = function() self.chestmemorymanager:RemoveHighlightedChest(owner) end
        owner:ListenForEvent("refresh", self.onrefreshfn)
        owner:ListenForEvent("mouseover",self.onmouseoverfn)
        owner:ListenForEvent("mouseout",self.onmouseoutfn)
        --\\ Event Listeners
        
        self:Hide()
        self:LoadChestData()
        self:StartUpdating()
    end)

function ChestDisplay:UpdateDisplayType()
    self.displaytype = self.chestmemorymanager:GetDisplayType()
    self:DoDisplay(self.displaytype)
end

function ChestDisplay:RefreshItems()--Mostly the same as widgets/containerwidget.lua
    local items = self.CS_contents or {}
    for k, v in pairs(self.inv) do
        local item = items[k]
        if item == nil then
            if v.tile ~= nil then
                v:SetTile(nil)
            end
        elseif v.tile == nil or v.tile.item ~= item then
            v:SetTile(ItemTile(item)) -- Creating a new tile for each different item? I don't think that's efficient
        else
            v.tile:Refresh()
        end
    end
end

function ChestDisplay:UpdateItemMemory()
    local chest = self.owner
        self.history_index = 0--Chest is open, the items get reset, might aswell reset history index.
        self.historytime:SetString("")
    if not self._olditemtrigger then
        self._olditems = self.CS_contents
        self._olditemtrigger = true
    end
    local chestitems = chest.replica.container:GetItems()
    self.time_since_closed = 0
    self.CS_contents = {}
    for i = 1,chest.replica.container:GetNumSlots() do
        self.CS_contents[i] = CreateBasicItemInfoForItem(chestitems[i])
    end
    self:RefreshItems()
end

function ChestDisplay:MoveTowardsThePresent()-- +1 spot
    local contents = self.CS_contents
    local history = self.CS_history
    local historytime = self.CS_historytime
    if type(#history) == "number" and #history == 0 then else
        if self.history_index >= #history then
            self.history_index = 0
            self.CS_contents = self._olditems
            self._olditems = nil
            self:RefreshItems()
        
        elseif self.history_index == 0 and #history >= 1 then
            self._olditems = contents
            self.history_index = (self.history_index + 1)
            if history[self.history_index] ~= nil then
                self.CS_contents = history[self.history_index]
                self:RefreshItems()
            end
        elseif self.history_index == #history and #history > 1 then
            self.history_index = 0
            self.CS_contents = self._olditems
            self._olditems = nil
            self:RefreshItems()
            
        elseif self.history_index < #history then
            self.history_index = self.history_index + 1
            if history[self.history_index] ~= nil then
                self.CS_contents = history[self.history_index]
                self:RefreshItems()
            end
        end
    end
    if self.history_index == 0 then
        self.historytime:SetString("")
    else
        self.historytime:SetString(tostring(historytime[self.history_index] ~= nil and "Day "..historytime[self.history_index] or "Unknown day"))
    end
    --print(self.history_index)
end


local function CompareSameTables(t1,t2)
    local ans = true
    local t1_isempty = true
    local t2_isempty = true
    if not t1 or not t2 then return false end
    for _,v in pairs(t1) do
        t1_isempty = false
        break
    end
    for _,v in pairs(t2) do
        t2_isempty = false
        break
    end
    if t1_isempty and t2_isempty then return true end
    if t1_isempty or t2_isempty then return false end 
    --Previous condition will return true if both were empty, return false if only one of them is empty.
    for k,v in pairs(t1) do
        local matching_prefabs = t2[k].prefab == t1[k].prefab
        local matching_stacksize = t2[k].stacksize == t1[k].stacksize
        local matching_uses = t2[k].finiteusespercent == t1[k].finiteusespercent
        if not (matching_prefabs and matching_stacksize and matching_uses) then
            ans = false --Something didn't match, tables are different.
            break
        end
    end
    return ans
end


local function SaveChestData(self,chest)
    local pos = chest:GetPosition()
    local x = pos and tonumber(string.format("%.1f",pos.x))
    local z = pos and tonumber(string.format("%.1f",pos.z))
    
    local chest_info = {
        x = x,
        z = z,
        contents = self.CS_contents,
        history = self.CS_history,
        historytime = self.CS_historytime,
        prefab = chest.prefab,
        chest_type = self.chest_type,
        world = self.world, -- Caves or Surface, would be even better if we could refer to shard id.
    }
    
    self.chestmemorymanager:ModifyOrAddData(chest_info)
end


function ChestDisplay:DoHistoryAndContentMiniSave()
    if true then
        self._olditemtrigger = false
        --print("Mini-save")
        
        if #self.CS_history == 0 then 
            self._olditems = self.CS_contents 
            self.CS_history[#self.CS_history+1] = self._olditems 
            self.CS_historytime[#self.CS_history] = tonumber(string.format("%.2f",TheWorld.state.cycles+TheWorld.state.time+1)) 
        end --There is no old input for the first input!
        
        
        if self._olditems then-- This sometimes won't be applied now that history is in a seperate function
            --print("CS_history and _olditems")
            --print(CompareSameTables(chest.CS_history[#chest.CS_history],chest._olditems))
            --print("CS_contents and _olditems")
            --print(CompareSameTables(chest.CS_contents,chest._olditems))
            
            if (not (CompareSameTables(self.CS_history[#self.CS_history],self._olditems))) and (not (CompareSameTables(self.CS_contents,self._olditems))) then
                self.CS_history[#self.CS_history+1] = self._olditems 
                self.CS_historytime[#self.CS_history] = tonumber(string.format("%.2f",TheWorld.state.cycles+TheWorld.state.time+1))
            end
        end
    SaveChestData(self,self.owner)
    end
end


function ChestDisplay:MoveTowardsThePast()-- -1 spot
    local contents = self.CS_contents
    local history = self.CS_history
    local historytime = self.CS_historytime
    if type(#history) == "number" and #history == 0 then else
        if self.history_index == 0 and #history >= 1 then
            self._olditems = contents
            self.history_index = #history
            if history[self.history_index] ~= nil then
                self.CS_contents = history[self.history_index]
                self:RefreshItems()
            end
        elseif self.history_index == 1 then
            self.history_index = 0
            self.CS_contents = self._olditems
            self._olditems = nil
            self:RefreshItems()
        elseif self.history_index <= #history and self.history_index-1 >= 0 then
            self.history_index = self.history_index - 1
            if history[self.history_index] ~= nil then
                self.CS_contents = history[self.history_index]
                self:RefreshItems()
            end
        end
    end
    if self.history_index == 0 then
        self.historytime:SetString("")
    else
        self.historytime:SetString(tostring(historytime[self.history_index] ~= nil and "Day "..historytime[self.history_index] or "Unknown day"))
    end
    --print(self.history_index)
end

local function SetChestDataFromMemory(self,chest)
    local pos = chest:GetPosition()
    local x,z
    if self.boat then
        local boat_pos = self.boat:GetPosition()
        x = pos and tonumber(string.format("%.2f",boat_pos.x-pos.x))
        z = pos and tonumber(string.format("%.2f",boat_pos.z-pos.z))
    else
        x = pos and tonumber(string.format("%.1f",pos.x))
        z = pos and tonumber(string.format("%.1f",pos.z))
    end
    local prefab = chest.prefab
    local data = self.chestmemorymanager:GetData(prefab,x,z,self.chest_type)
    self.CS_contents = data.contents or {}
    self.CS_history = data.history or {}
    self.CS_historytime = data.historytime or {}
    self.chest_type = data.chest_type or self.chest_type
end

function ChestDisplay:LoadChestData()
    SetChestDataFromMemory(self,self.owner)
    self:RefreshItems()
end

function ChestDisplay:OnIsHoveredOver(ishovered,hover_exists) --Also a scale updater.
    local dist = TheCamera and TheCamera.distance or 30
    local base_scale = (10/dist)*widget_scale
    local scale = (not highlight_onmouseover) and base_scale or 
                      ishovered and base_scale*scale_changer or
                   hover_exists and base_scale/scale_changer or
                                    base_scale
   if ishovered then
      self:MoveToFront()
  else
      self:MoveToBack()
   end
   self:SetScale(scale,scale,scale)
end

function ChestDisplay:DoDisplay(display,pause)
    if pause then return "PAUSED" end
    local highlighted_chest = self.chestmemorymanager:GetHighlightedChest()
    local is_highlighted = highlighted_chest == self.owner
    local displays = {
        All = function()
            self:Show() 
            self.ishidden = false 
        end,
        Single = function() 
            if is_highlighted then 
                self:Show()
                self.ishidden = false
            else 
                self:Hide()
                self.ishidden = true
            end 
        end,
        Hidden = function()
            self:Hide()
            self.ishidden = true
        end,
    }
    if displays[display] then
        displays[display]()
        self:OnIsHoveredOver(is_highlighted,highlighted_chest)
    end
end

function ChestDisplay:HandleWidgetDisplay()
    if not self.boat then
       self.boat = TheWorld.Map:GetPlatformAtPoint(self.owner.Transform:GetWorldPosition())
       self.chest_type = self.boat and "boat" or "static" 
    end
    
    if not (self.chest_type == "static") then
        local x,y,z = self.owner.Transform:GetWorldPosition()
        self.pos = {x = x, y = y, z = z}
    end
    
    
    local screen_x,screen_y,screen_z = TheSim:GetScreenPos(self.pos.x,self.pos.y,self.pos.z)
    local is_outsidescreenborders = screen_x < 0 or screen_y < 0 or screen_x>x_size or screen_y>y_size
    local specialkey_down = highlightpause_button ~= 0 and TheInput:IsKeyDown(highlightpause_button) or false
    self:DoDisplay(self.displaytype,specialkey_down)
    if is_outsidescreenborders then
       self:Hide()
       self.ishidden = true -- Don't update anything other than checking if it's outside the borders when it's hidden.
    else
       self.ishidden = false
    end
    
    if self.scroll_left and self.scroll_right then
       local is_clickable = false
       if specialkey_down then
           is_clickable = true
       end
       self.scroll_left:SetClickable(is_clickable)
       self.scroll_right:SetClickable(is_clickable)
    end
    
    
    self:SetPosition(screen_x,screen_y+screen_y*(1/TheCamera.distance),0)
end

function ChestDisplay:HasItem(item_prefab)
    if not item_prefab then return false end
    for _,item in pairs(self.CS_contents) do 
       if item.prefab == item_prefab then
           return true
       end
    end
    return false
end

function ChestDisplay:HighlightWithItem(bool,item_prefab)
    if self:HasItem(item_prefab) then
       if bool then
           self.owner.AnimState:SetAddColour(0,0.5,0,1)
       else
           self.owner.AnimState:SetAddColour(0,0,0,1)
       end
    else
       self.owner.AnimState:SetAddColour(0,0,0,1)
    end
end

function ChestDisplay:GetItems()
    return self.CS_contents
end


function ChestDisplay:GetOwner()
    return self.owner
end

function ChestDisplay:UpdateSavedData()
    local pos = self.owner:GetPosition()
    local prefab = self.owner.prefab
    local x,z
    if self.boat then
        local boat_pos = self.boat:GetPosition()
        x = pos and tonumber(string.format("%.2f",boat_pos.x-pos.x))
        z = pos and tonumber(string.format("%.2f",boat_pos.z-pos.z))
    else
        x = pos and tonumber(string.format("%.1f",pos.x))
        z = pos and tonumber(string.format("%.1f",pos.z))
    end
    self.chestmemorymanager:ModifyOrAddData(
        {
        x = x, z = z, 
        contents = self.CS_contents, 
        history = self.CS_history, 
        historytime = self.CS_historytime,
        prefab = prefab,
        chest_type = self.chest_type,
        --world = self.world -- Decided to keep the seeds seperated by the persistent string. 
        }
    )
end

function ChestDisplay:DoRemove(callcomponent) -- Remove it, but before that, save the data.
    self:UpdateSavedData()
    self.owner:RemoveEventCallback("refresh",self.onrefreshfn)
    self.owner:RemoveEventCallback("onmouseover",self.onmouseoverfn)
    self.owner:RemoveEventCallback("onmouseout",self.onmouseoutfn)
    if callcomponent then -- Don't cause a stack overflow!!!
        self.chestmemorymanager:RemoveWidget(self,true)
    end
--  print("Triggered removal for chest",self.owner)
    self:Kill()
    self:StopUpdating()
end

function ChestDisplay:OnUpdate(dt)
    if not self.owner:IsValid() then
--      print("Entity not valid anymore",self.owner)
        self:DoRemove(true)
        return
    end
    self:HandleWidgetDisplay()
    if not self.owner.replica.container then return "NO CONTAINER" end
    
    if self._alreadyopenedonce and self.chestmemorymanager:GetOpenedContainer() ~= self.owner then
        self:DoHistoryAndContentMiniSave()
        self._alreadyopenedonce = false
    elseif TheWorld.ismastersim and self.chestmemorymanager:GetOpenedContainer() == self.owner then
        self:UpdateItemMemory()
    end
end


return ChestDisplay