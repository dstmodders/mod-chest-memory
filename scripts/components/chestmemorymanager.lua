local mod_prefix = "MOD_ChestMemory_"
local ChestDisplay = require ("widgets/chestdisplay")
local ContainerData = require("persistentcontainerdata")
local mod_suffix = KnownModIndex:GetModActualName("Chest Memory").."-"
--Will keep track of the chest display type to not force every widget to listen when it changes.
--Will keep track of highlighted chest
--Will keep track of item highlighting
--Will help with data saving: All chests will be responsible for submitting their: Position, type, data to save;
--This component will save everything all in one-go as to prevent several accesses of the data point.
--Might also have some variables for removing the chests :)
--Also has all the added widgets.

local function GetConfig(name)
    local mod = "Chest Memory"
    return GetModConfigData(name,mod) or GetModConfigData(name,KnownModIndex:GetModActualName(mod))
end

local highlight_activeitem = GetConfig("highlight_activeitem")
local highlight_ingredient = GetConfig("highlight_ingredient")

local ChestMemoryManager = Class(function(self,inst)
        self.owner = inst
        self.chestwidgets = {}
        self.chest = {}
        self.data = {}
        self.openedchest = nil
        --Data format: 
        --[[
            {x = x,
             z = z, 
             contents = chest.CS_contents, 
             history = chest.CS_history, 
             historytime = chest.CS_historytime, 
             prefab = chest.prefab, 
             chest_type = chest_type, 
             world = world}
        --]]
        --Would be nice if there's a way to get shard ID.
        self.seed = self:GetWorldSeed()
        
        self.highlightedchest = nil
        self.highlightitem = nil
        self.displaytype = nil -- Add a default please
        self.doremove = false

        --Component will stay on the player. If the player disappears so will the event listeners,
        --thus there is no chance for the event listeners to "stack".
        self.onactivehighlightitemfn = function(src,data) self:ChangeHighlighting(true,data.item and data.item.prefab or "") end
        self.onhighlightingredientfn = function(src,data) self:ChangeHighlighting(true,data or "") end
        self.onunhighlightingredientfn = function(src,data) self:ChangeHighlighting(false,data or "") end
        --Need to add some extra conditions for when you have an active item and ingredient, when onlosefocus triggers before ongainfocus.
        if highlight_activeitem then
            self.owner:ListenForEvent("newactiveitem",self.onactivehighlightitemfn)
        end
        if highlight_ingredient then
            self.owner:ListenForEvent(mod_prefix.."highlight_ingredient",self.onhighlightingredientfn)
            self.owner:ListenForEvent(mod_prefix.."unhighlight_ingredient",self.onunhighlightingredientfn)
        end
        self:LoadData()
    end)

function ChestMemoryManager:GetWorldSeed()
    return TheWorld:HasTag("cave") and TheWorld.meta.seed.."_caves" or TheWorld.meta.seed
end

function ChestMemoryManager:LoadData()
    if not self.seed then
        self.seed = self:GetWorldSeed()
    end
    if self.seed then
       self:SetData(ContainerData(mod_suffix..self.seed):Load())
    end
end

function ChestMemoryManager:SaveData()
    for k,widget in pairs(self.chestwidgets) do
        widget:UpdateSavedData()
    end
    if not self.seed then
        self.seed = self:GetWorldSeed()
    end
    if self.seed then
       local data_id = ContainerData(mod_suffix..self.seed)
       data_id:ChangePersistData(self.data)
       data_id:Save()
    end
end

function ChestMemoryManager:ChangeHighlighting(bool,item_prefab)
    for k,widget in pairs(self.chestwidgets) do
        widget:HighlightWithItem(bool,item_prefab)
    end
end

function ChestMemoryManager:HighlightItem()
   for k,widget in pairs(self.chestwidgets) do
      widget:HighlightWithItem(self.highlightitem)
   end
end

function ChestMemoryManager:GetDisplayType()
    return self.displaytype
end

function ChestMemoryManager:SetAndPushDisplayType(display_type)
    self.displaytype = display_type
    for k,widget in pairs(self.chestwidgets) do
       widget:UpdateDisplayType() 
    end
end

function ChestMemoryManager:GetHighlightedItem()
    return self.highlightitem
end

function ChestMemoryManager:SetHighlightedItem(item_prefab)
    self.highlightitem = item_prefab
end

function ChestMemoryManager:GetHighlightedChest()
    return self.highlightedchest
end

function ChestMemoryManager:SetHighlightedChest(chest) -- Let's go for the chest, we can easily check this.
    self.highlightedchest = chest
end

function ChestMemoryManager:RemoveHighlightedChest(chest) -- event 'mouseout' may trigger before the 'mouseover' event in some cases.
    if self.highlightedchest == chest then
       self.highlightedchest = nil
    end
end

function ChestMemoryManager:ModifyOrAddData(data) -- Would prefer to "change" data in case of something changing.
    local is_newdata = true
    local data_count = 1
    for k, info in pairs(self.data) do
        data_count = data_count + 1
        if data.x == info.x and data.z == info.z and data.prefab == info.prefab then
            self.data[k] = data
            is_newdata = false
            break
        end
    end
    if is_newdata then
       self.data[tostring(data_count)] = data 
    end
end

function ChestMemoryManager:GetData(prefab,x,z,chest_type)
    local data = {}
    for k, info in pairs(self.data) do
       if info.prefab == prefab and info.x == x and info.z == z and ((info.chest_type == nil) or info.chest_type == chest_type) then
           data = info
           break
       end
    end
    return data
end


function ChestMemoryManager:SetData(data) -- Risky function, should be used with care.
    self.data = data
end

function ChestMemoryManager:AddWidget(owner)
    --// Additional conditions for if I should/can add the widget
    if not owner or self.chest[owner] or self.doremove or (owner and not owner.replica.container) then return end
    if not self.owner.HUD then print("Error: no HUD, did something go wrong?") return nil end
    --\\ Additional conditions for if I should/can add the widget
    local widget = ChestDisplay(owner)
    self.owner.HUD:AddChild(widget)
    self.chest[owner] = widget
    table.insert(self.chestwidgets,widget)
end

function ChestMemoryManager:SetRemoveWidgets(bool)
    self.doremove = bool
end

function ChestMemoryManager:RemoveAllWidgets()
--  print("Call to remove all widgets")
    for k,widget in pairs(self.chestwidgets) do
--      print("Trigger for",widget)
       widget:DoRemove() 
    end
    self.chest = {}
    self.chestwidgets = {}
end

function ChestMemoryManager:RemoveWidget(_widget,chest_trigger)
    local owner,widget_num
--  print("Call to remove widget",widget,chest_trigger)
    for k,widget in pairs(self.chestwidgets) do
        if widget == _widget then
            owner = widget:GetOwner()
            widget_num = k
            break
        end
    end
    if not chest_trigger then
       self.chestwidgets[widget_num]:DoRemove() 
    end
    table.remove(self.chestwidgets,widget_num)
    self.chest[owner] = nil
end

function ChestMemoryManager:SetOpenedContainer(chest)
   self.openedchest = chest 
end

function ChestMemoryManager:GetOpenedContainer()
    self:OnUpdate()
    return self.openedchest
end

function ChestMemoryManager:GetChestContents(chest)
    local chest_widget = self.chest[chest]
   return chest_widget and chest_widget:GetItems()
end

function ChestMemoryManager:OnUpdate(dt)
    local open_chest
    for k, _ in pairs(self.owner.replica.inventory and self.owner.replica.inventory:GetOpenContainers() or {}) do
        if self.chest[k] then
            open_chest = k
        end
    end
    self:SetOpenedContainer(open_chest)
end

return ChestMemoryManager
