local ItemSlot = require "widgets/itemslot"

local InvSlot = Class(ItemSlot, function(self, num, atlas, bgim, owner, container)
    ItemSlot._ctor(self, atlas, bgim, owner)
    self.owner = owner
    self.container = container
    self.num = num
end)

return InvSlot