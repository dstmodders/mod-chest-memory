
--// Defining global variables as non-global ones for cleaner usage
local _G = GLOBAL
local require = _G.require
local TheSim = _G.TheSim
local TheNet = _G.TheNet
local SendRPCToServer = _G.SendRPCToServer
local ACTIONS = _G.ACTIONS
local EQUIPSLOTS = _G.EQUIPSLOTS
local TheInput = _G.TheInput
local KnownModIndex = _G.KnownModIndex
--\\ Defining global variables as non-global ones for cleaner usage

--// Loading needed libraries
local ContainerSearcher = require ("containersearcher")
local UnmarkAllChests = ContainerSearcher[1]
--\\ Loading needed libraries

--// Grabbing mod settings 
local default_show = GetModConfigData("default_show")
local widget_toggle = GetModConfigData("widget_toggle")
local widget_cycle = GetModConfigData("widget_cycle")
local widget_displaytype = GetModConfigData("widget_displaytype")
local highlightpause_button = GetModConfigData("highlightpause_button")
local highlight_activeitem = GetModConfigData("hightlight_activeitem")
local include_icebox = GetModConfigData("include_icebox") --"fridge"
local include_saltbox = GetModConfigData("include_saltbox")--"saltbox
--\\ Grabbing mod settings

--// Tags respecting mod settings for finding containers
local MUST_HAVE_TAGS = {"_container"}
local CANT_HAVE_TAGS = {"INLIMBO","_equippable","backpack","burnt","chester"}
local MUST_ONEOF_TAGS = ((include_icebox and include_saltbox) and {"chest","fridge","saltbox"}) or (include_icebox and {"chest","fridge"}) or (include_saltbox and {"chest","saltbox"}) or {"chest"}
--\\ Tags respecting mod settings for finding containers

--// Custom variables
local mod_prefix = "MOD_ChestMemory_"
local loaded_ents_radius = 80
local chests = {}
local event_player_leaving = mod_prefix.."player_restarting"
local is_chestsenabled = true
--\\ Custom variables

local function InGame()
    return _G.ThePlayer and _G.ThePlayer.HUD and not _G.ThePlayer.HUD:HasInputFocus()
end

local function AddChestDisplayToNearbyChests()
    local pos = _G.ThePlayer:GetPosition()
    local chests = TheSim:FindEntities(pos.x,pos.y,pos.z,loaded_ents_radius,MUST_HAVE_TAGS,CANT_HAVE_TAGS,MUST_ONEOF_TAGS)
    for _,chest in pairs(chests) do
    if chest.replica.container then
        _G.ThePlayer.components.chestmemorymanager:AddWidget(chest)
    end
   end
end


local function SavePersistentChestData()
    if not _G.ThePlayer then return "No Player" end
    _G.ThePlayer.components.chestmemorymanager:SaveData()
end

local function OnLoad()
    _G.ThePlayer:AddComponent("chestmemorymanager")
    local event_listeners = {"seasontick","playerdeactivated",event_player_leaving}
    --[[
    seasontick - Day start
    playerdeactivated - Character switching, rollbacking.
    event_player_leaving - Custom event for when the player is migrating shards, leaving the game.
    --]]
    for k, event in pairs(event_listeners) do
        _G.TheWorld:RemoveEventCallback(event,SavePersistentChestData) -- Player can trigger OnLoad while switching characters
        --Stacking the same event multiple times would be bad, so let's remove it just in case.
        _G.TheWorld:ListenForEvent(event,SavePersistentChestData)
    end
end


--//Changing functions to get non-existent event handlers--
--Previously forgot to return the old function. That could've lead to some issues...
local old_DoRestart = _G.DoRestart
function _G.DoRestart(val)
	if val == true and _G.TheWorld then
		_G.TheWorld:PushEvent(event_player_leaving)
	end
	return old_DoRestart(val)
end
local old_MigrateToServer = _G.MigrateToServer
function _G.MigrateToServer(ip,port,...)
	if ip and port and _G.TheWorld then --Whoops, you should check if TheWorld exists first before pushing an event!
		_G.TheWorld:PushEvent(event_player_leaving)
	end
	return old_MigrateToServer(ip,port,...)
end
--\\Changing functions to get non-existent event handlers--

local function RemoveChestWidgets()
    _G.ThePlayer.components.chestmemorymanager:RemoveAllWidgets()
    is_chestsenabled = false
end

-- Do it differently, these look very inefficient.
local function BreakSearchThread()
    if _G.ThePlayer.searchandmark_thread then
        _G.KillThreadsWithID(_G.ThePlayer.searchandmark_thread.id)
        _G.ThePlayer.searchandmark_thread:SetList(nil)
        _G.ThePlayer.searchandmark_thread = nil
        UnmarkAllChests(nil,10)
    end
end
local function BreakGrabThread()
   if _G.ThePlayer.searchandgrab_thread then
        _G.KillThreadsWithID(_G.ThePlayer.searchandgrab_thread.id)
        _G.ThePlayer.searchandgrab_thread:SetList(nil)
        _G.ThePlayer.searchandgrab_thread = nil
   end
end


local function ConsoleScreenPostInit(self) -- You can do better than console commands. Go for a UI!
    self.console_edit:AddWordPredictionDictionary({
    words = {"searchchests","grabitems","searchchestsmemory"},
    delim = "cs_",
    num_chars = 0
})
end
-- Do it differently, container searching user implementation is not easy to use.


local chest_names = {"treasurechest","minotaurchest","sacred_chest","dragonflychest","pandoraschest"}
local function AddContainerToChestNames(condition,container_name)
	if condition then
		chest_names[#chest_names+1] = container_name
	end
end

AddContainerToChestNames(include_icebox,"icebox")
AddContainerToChestNames(include_saltbox,"saltbox")

for _,name in pairs(chest_names) do
    AddPrefabPostInit(name,function(inst)
        if default_show and is_chestsenabled then
            inst:DoTaskInTime(0,function()
                if _G.ThePlayer and _G.ThePlayer.components and _G.ThePlayer.components.chestmemorymanager then
                    _G.ThePlayer.components.chestmemorymanager:AddWidget(inst)
                end
            end)
        end
    end)
end
AddPlayerPostInit(function(inst) 
	if default_show and is_chestsenabled then
		inst:DoTaskInTime(2,function()
			if inst == _G.ThePlayer then
				AddChestDisplayToNearbyChests()
			end
		end)
	end
	inst:DoTaskInTime(0,function()
		if inst == _G.ThePlayer then
			OnLoad()
		end
	end)
end)

--[[
local interrupt_controls = {}
for control = _G.CONTROL_ATTACK, _G.CONTROL_MOVE_RIGHT do
    interrupt_controls[control] = true
end

AddComponentPostInit("playercontroller", function(self, inst)
    if inst ~= _G.ThePlayer then return end
    local mouse_controls = {[_G.CONTROL_PRIMARY] = true, [_G.CONTROL_SECONDARY] = true}

    local PlayerControllerOnControl = self.OnControl
    self.OnControl = function(self, control, down)
        local mouse_control = mouse_controls[control]
        local interrupt_control = interrupt_controls[control]
        if interrupt_control or mouse_control then
            if down and InGame() and (_G.ThePlayer.searchandmark_thread or _G.ThePlayer.searchandgrab_thread) then
                BreakSearchThread()
                BreakGrabThread()
            end
        end
        PlayerControllerOnControl(self, control, down)
    end
end)
AddClassPostConstruct("screens/consolescreen", ConsoleScreenPostInit)
-]]

local last_highlight

local function PushHighlightEvent(item)
	if _G.ThePlayer and item then
		_G.ThePlayer:PushEvent(mod_prefix.."highlight_ingredient",item)
		--print("highlight_ingredient Trigger",item)
		last_highlight = item
	end
end

local function PushUnhighlightEvent(item)
	if _G.ThePlayer and item then
		_G.ThePlayer:PushEvent(mod_prefix.."unhighlight_ingredient",item)
		--print("unhighlight_ingredient Trigger",item)
		last_highlight = nil
	end	
end

AddClassPostConstruct("widgets/ingredientui",function(self, atlas, image, quantity, on_hand, has_enough, name, owner, recipe_type)
	local old_OnGainFocus = self.OnGainFocus
    local old_OnLoseFocus = self.OnLoseFocus
	
	function self:OnGainFocus(...)
		--print("ingredientui OnGainFocus",atlas, image, quantity, on_hand, has_enough, name, owner, recipe_type)
		PushHighlightEvent(recipe_type)
		old_OnGainFocus(self,...)
	end
	
	function self:OnLoseFocus(...)
		--print("ingredientui OnLoseFocus",atlas, image, quantity, on_hand, has_enough, name, owner, recipe_type)
		PushUnhighlightEvent(recipe_type)
		old_OnLoseFocus(self,...)
	end
		
	end)

AddClassPostConstruct("widgets/tabgroup",function(self) 
		local old_DeselectAll = self.DeselectAll
		function self.DeselectAll(self,...)
			--print("ingredientui DeselectAll",self,...)--Scrolling through tabs; New tab selected; Tab opened event
			PushUnhighlightEvent(last_highlight)
			old_DeselectAll(self,...)
		end
	end)
--[[AddClassPostConstruct("widgets/craftslot", function(self, atlas, bgim, owner) 
		local old_Open = self.Open
		function self:Open(...)
			print("craftslot Open",...)--Tab opened via highlighting with mouse; OnGainFocus
			old_Open(self,...)
		end
		local old_OnGainFocus = self.OnGainFocus
		function self:OnGainFocus(...)
			print("craftslot OnGainFocus",...)
			old_OnGainFocus(self,...)
		end
		
	end)-]]
	AddClassPostConstruct("widgets/crafting", function(self, owner, num_slots)
			local old_ScrollUp = self.ScrollUp
			local old_ScrollDown = self.ScrollDown
			--Player can bypass OnLoseFocus by scrolling through recipes. That would leave things highlighted, so one way of knowing that the player isn't hovering over them anymore is looking for the scroll events.
			function self:ScrollUp(...)
				--print("crafting ScrollUp")
				PushUnhighlightEvent(last_highlight)
				old_ScrollUp(self,...)
			end
			function self:ScrollDown(...)
				--print("crafting ScrollDown")
				PushUnhighlightEvent(last_highlight)
				old_ScrollDown(self,...)
			end
			
		end)




local cycle_c = not default_show and 1
local cycles = {"Disabled","Hidden","Single","All"}

local option_order = {}
if widget_cycle == "default" then
	option_order = {"Disabled"}
	table.insert(option_order,2,widget_displaytype)
elseif widget_cycle == "all_displays" then
	option_order = {"Disabled","Single","All"}
elseif widget_cycle == "all" then
	option_order = cycles
end

local cycle_count = #option_order

for k,cycle in pairs(option_order) do
   if cycle == widget_displaytype and default_show then
      cycle_c = k
      break
   end
end

local function DoCycle()
    cycle_c = cycle_c % cycle_count + 1
    --print(cycle_c)
    local specialkey_down = TheInput:IsKeyDown((highlightpause_button ~= 0 and highlightpause_button) or 308)
    if option_order[cycle_c] == "Hidden" then
       cycle_c = cycle_c % cycle_count + 1
--     print(cycle_c,"Hidden shuffle")
    end
    if option_order[cycle_c] == "Disabled" and (widget_cycle == "all") and (not specialkey_down) then
        cycle_c = cycle_c % cycle_count + 1
--      print(cycle_c,"Disable shuffle")
    end
    _G.ThePlayer.components.chestmemorymanager:SetAndPushDisplayType(option_order[cycle_c])
    _G.ThePlayer.components.talker:Say("Chest Widget Display: "..option_order[cycle_c])
end

if widget_toggle ~= 0 then
	TheInput:AddKeyUpHandler(widget_toggle,function()
		if not InGame() then return else
            DoCycle()
			if cycle_c > 1 then
                _G.ThePlayer.components.chestmemorymanager:SetRemoveWidgets(false)
                is_chestsenabled = true
				AddChestDisplayToNearbyChests()
			else
                _G.ThePlayer.components.chestmemorymanager:SetRemoveWidgets(true)
                _G.ThePlayer.components.chestmemorymanager:RemoveAllWidgets()
                is_chestsenabled = false
			end
		end
	end)
end