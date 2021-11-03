ContainerSearcher = {}
--TODO: Add an ability to choose or input mark color. Perhaps colours should also mix if input is satisfied twice.
--I think it would be nicer to put this all into a component \shrug
local function InGame()
return ThePlayer
end

local function DoBuffer(...)
    if InGame() then
        ThePlayer.components.playercontroller:DoAction(BufferedAction(...))
    end
end

function FindNearbyChests(posx,posy,posz,rad)
    if InGame() then
        local player_pos = ThePlayer:GetPosition()
        local x = posx or player_pos.x
        local y = posy or player_pos.y
        local z = posz or player_pos.z
        local radius = rad or 60
        local chest_table = TheSim:FindEntities(x,y,z,radius,{"chest","_container"},{"INLIMBO","_equippable","backpack","burnt"})
        return chest_table
    else
        print("Error: No Player")
    end
    
    
end

local function CombineTables(a,b)
    local new_table = {}
    local table_pos = 1
    for k,v in pairs(a) do
        table.insert(new_table,table_pos,v)
        table_pos=table_pos+1
    end
    for k,v in pairs(b) do
        table.insert(new_table,table_pos,v)
        table_pos=table_pos+1
    end
    return new_table
end

local function SortTableByDistanceToEnt(tosort,ent)
    table.sort(tosort,function(x,y) return ((x and x:IsValid()) and (y and y:IsValid()) and (ent and ent:IsValid()) and x:GetDistanceSqToInst(ent)<y:GetDistanceSqToInst(ent)) or (x and not y) end)
end

local function MarkChest(chest,r,g,b)
    if chest then
        chest.marked = true
        if chest.AnimState then
            chest.AnimState:SetAddColour(r,g,b,1) --Could also use SetMultColour, but I feel like SetAddColour makes it feel more "selected".
        end
    end
end

local function CheckChestForItem(chest,prefab,case)
    if InGame() then
        local anim = chest
        local chest = chest and chest.replica and chest.replica.container or nil
        if chest and chest:IsOpenedBy(ThePlayer) then
            local prefab_slots = {}
            for slot,item in pairs(chest:GetItems()) do
                if item and item.prefab == prefab then
                    if case == "mark" then --Mark it in green = contains that item.
                        MarkChest(anim,0,0.5,0)
                    elseif case == "take" then
                        table.insert(prefab_slots,slot,item)
                    end
                end
            end
            return prefab_slots
        end
    end
end
local function OpenChestOrStoreActiveItem(chest,store)
    local inv = ThePlayer.replica.inventory
    if (chest and (chest.AnimState:IsCurrentAnimation("closed") or chest.AnimState:IsCurrentAnimation("close")) and (not chest:HasTag("burnt"))) then --chestrep._isopen is always a false value no matter what you do,so I guess I'll try to go through animstates :/--Well it's only true if YOU open it, but not other players, so it still isn't useful for me.
        local chestpos = chest:GetPosition()
        if TheWorld.ismastersim then --Buffer action
            if store and inv:GetActiveItem() then
                DoBuffer(ThePlayer,chest,ACTIONS.STORE,inv:GetActiveItem())
            else
            --Remove Active Item, if one exists
                if inv:GetActiveItem() then
                    inv:ReturnActiveItem()
                end
                DoBuffer(ThePlayer,chest,ACTIONS.RUMMAGE)
            end
        else --Do RPC
            if store and inv:GetActiveItem() then
                SendRPCToServer(RPC.LeftClick,ACTIONS.STORE.code,chestpos.x,chestpos.z,chest)
            else    
            --Remove Active Item, if one exists
                if inv:GetActiveItem() then
                    inv:ReturnActiveItem()
                end
                SendRPCToServer(RPC.LeftClick,ACTIONS.RUMMAGE.code,chestpos.x,chestpos.z,chest)
            end
        end
    end
end

local function GetCurrentlyOpenedChest()
    -- Not gonna change anything, but I do recommend to any modders
    -- to use ThePlayer.replica.inventory:GetOpenedContainers() to
    -- find out which containers the player currently has opened and then simply
    -- checking the prefab or tag should give you your desired container entity.
    local mychest
    for _,chest in pairs(FindNearbyChests(nil,nil,nil,3.5)) do --Player keeps the chest opened till he walks away 3 units from it.
        if chest.replica.container:IsOpenedBy(ThePlayer) then
            mychest = chest
            break
        end
        
    
    end
    return mychest
    
end
local function GetEmptyPlayerInventorySlots()--TODO: Check if a player has the item you're grabbing and if you can stack it. That way you won't get weird action with having an entire inventory of grabable item while it says you got no slots(which is technically true).
    -- Calculating that may be a bit difficult in interpreting "empty" slots.
    local empty_slots = 0
    local inv = ThePlayer.replica.inventory:GetItems()
    local inv_rep = ThePlayer.replica.inventory
    local body_slot = inv_rep:GetEquippedItem(EQUIPSLOTS.BODY)
    local body_slot_rep = body_slot and body_slot.replica.container
    local backpack = body_slot and body_slot:HasTag("_container") and body_slot_rep:GetItems()
    for i = 1,inv_rep:GetNumSlots() do
        if inv[i] == nil then
            empty_slots = empty_slots + 1    
        end
    end
    if backpack then
        for i = 1,body_slot_rep:GetNumSlots() do
            if backpack[i] == nil then
                empty_slots = empty_slots + 1    
            end
        end
    end
    return empty_slots
end

local function UnmarkAllChests(radius,time)
    local time = time or 0
    local radius = radius or 60
    ThePlayer:DoTaskInTime(time,function()
        local chests = FindNearbyChests(nil,nil,nil,radius)
        for _,v in pairs(chests) do
            if v.marked then
                v.marked = nil
                if v.AnimState then
                    v.AnimState:SetAddColour(0,0,0,0)
                end
            end
        end
    end)
end


local function BreakSearchThread() --Not sure why, but it didn't seem like it could set a local variable to nil. Maybe I'm just bad.
    if ThePlayer.searchandmark_thread then
        KillThreadsWithID(ThePlayer.searchandmark_thread.id)
        ThePlayer.searchandmark_thread:SetList(nil)
        ThePlayer.searchandmark_thread = nil
    end
end

local function BreakGrabThread()
   if ThePlayer.searchandgrab_thread then
        KillThreadsWithID(ThePlayer.searchandgrab_thread.id)
        ThePlayer.searchandgrab_thread:SetList(nil)
        ThePlayer.searchandgrab_thread = nil
   end
end

local function SearchAndMarkChestsWithItem(prefab,searchradius,duration)
    if InGame() then
        if prefab then
            local duration = duration or 20
            local chests = FindNearbyChests(nil,nil,nil,searchradius)
            ThePlayer.searchandmark_thread = StartThread(function()
                    while chests[1] do
                        local currentchest = chests[1]
                        Sleep(FRAMES)
                        if currentchest == GetCurrentlyOpenedChest() then
                            table.remove(chests,1)
                            SortTableByDistanceToEnt(chests,ThePlayer)
                            CheckChestForItem(currentchest,prefab,"mark")
                        else
                            OpenChestOrStoreActiveItem(currentchest)
                        end
                        if #chests == 0 then --I really don't like this way of checking if the thread is done...
                        print("Done")
                        UnmarkAllChests(nil,duration)
                        BreakSearchThread()
                        end
                    end
                
            end)
        else
            print("Error: no prefab")
            print("Input: prefab,search radius, markduration")
            print("Example: cs_searchchests(\"pickaxe\",60,5)")
        end
    else
        print("Warning: Console command \"cs_searchchests\" should only be used in-game")
    end
end

local function SearchAndGrabItemsFromChest(prefab,searchradius)
   if InGame() then
       local inv = ThePlayer.replica.inventory
       if prefab then
           local chests = FindNearbyChests(nil,nil,nil,searchradius)
           ThePlayer.searchandgrab_thread = StartThread(function()
                    while chests[1] do 
                        local freeslots = GetEmptyPlayerInventorySlots()--Someone might give you an item while you're walking to a chest, thus I need to check at start.
                        if GetEmptyPlayerInventorySlots() == 0 and inv:GetActiveItem() ~= nil then
                            print("No slots to grab items to. Thread done.")
                           BreakGrabThread()
                           break
                        end
                        local currentchest = chests[1]
                        OpenChestOrStoreActiveItem(currentchest)
                        Sleep(FRAMES)
                        if currentchest == GetCurrentlyOpenedChest() then
                           table.remove(chests,1)
                           SortTableByDistanceToEnt(chests,ThePlayer)
                            for slot,item in pairs(CheckChestForItem(currentchest,prefab,"take") or {}) do 
                                if false then --Buffer--RPC seems to work perfectly here, so no need to check TheWorld.ismastersim.
                                    if inv:GetActiveItem() then--We should have some free slots because of the code at line  228-231.
                                        
                                    else --Perhaps we don't have any free slots, but active item is available.
                                        if freeslots > 0 then
                                            
                                        else
                                            
                                        end
                                    end
                                else --RPC
                                    if inv:GetActiveItem() ~= nil then--Comment at line 248
                                        SendRPCToServer(RPC.MoveItemFromAllOfSlot,1,currentchest)
                                    else--Active item slot available, free slots available too perhaps?
                                        if freeslots ~= 0 then
                                            SendRPCToServer(RPC.MoveItemFromAllOfSlot,slot,currentchest)
                                        elseif freeslots == 0 then
                                            SendRPCToServer(RPC.TakeActiveItemFromAllOfSlot,slot,currentchest)--TODO: Fix this to work in the same chest if your inventory gets filled up when you're in the same chest. It only works when you enter new chest at the moment.
                                            Sleep(FRAMES)
                                            break
                                        end
                                    end
                                end
                            end
                        end
                        if #chests == 0 or (freeslots == 0 and inv:GetActiveItem()) then
                            print("Done")
                            BreakGrabThread()
                        end
                    end
                    BreakGrabThread()
            end)
       else
           print("Error: no prefab")
           print("Input: prefab,search radius")
           print("Example: cs_grabitems(\"spoiled_food\",60)")
       end
  else
      print("Warning: Console command \"cs_grabitems\" should only be used in-game")
   end
end
local function MarkChestsWithItemByMemory(prefab,searchradius, duration)
   if InGame() then
       if prefab then
           for num,_table in pairs(FindNearbyChests(nil,nil,nil,searchradius) or {}) do
               for slot,item in pairs(ThePlayer.components.chestmemorymanager:GetChestContents(_table)) do 
                    if item and item.prefab == prefab then
                        MarkChest(_table,0,0.5,0)
                        _table:DoTaskInTime(type(duration) == "number" and duration or 20,function()
                            if _table.AnimState then
                                _table.AnimState:SetAddColour(0,0,0,0)
                            end
                            if _table.marked then
                                _table.marked = nil
                            end
                        end)
                        break
                    end
               end
           end
       else
           print("Error: no prefab")
           print("Input: prefab, search radius, mark duration")
           print("Example: cs_searchchestsmemory(\"goldnugget\",70,10)")
       end
  else
      print("Warning: Console command \"cs_searchchestsmemory\" should only be used in-game")
   end
end
table.insert(ContainerSearcher,1,UnmarkAllChests) --Not that great of a way to transfer a function from here to modmain
cs_searchchests = SearchAndMarkChestsWithItem --Perhaps you should add it in the console word dictionary too?
cs_grabitems = SearchAndGrabItemsFromChest
cs_getemptyinvslots = GetEmptyPlayerInventorySlots
cs_searchchestsmemory = MarkChestsWithItemByMemory
return ContainerSearcher