local ContainerData = Class(function(self,id)
        self.persistdata = {}
        self.id = id
        self._isdatasaved = true
    end)
    
    function ContainerData:GetID()
        return self.id
    end
    
    function ContainerData:ChangePersistData(val)
        if type(val) == "table" then
            self.persistdata = val
            --print("WARNING: Persistdata has been changed to another table")
            --print("Saving it will remove the previous known data")
        else
            print("ERROR: Attempted to change persistdata with a non-table value")
        end
        
    end
    
    function ContainerData:Save()
        --[[print("self.persistdata:")
        for k,v in pairs(self.persistdata) do print(k,v) end
        print("------------")--]]
        local encoded_var = json.encode(self.persistdata)
        SavePersistentString(self.id,encoded_var,ENCODE_SAVES)
        self._isdatasaved = true
    end
    
    function ContainerData:Load(var)
        if not self._isdatasaved then
            self:Save()
        end
        TheSim:GetPersistentString(self.id,function(success,data)
                if success then 
                    self.persistdata = json.decode(data)
                end 
            end,false)
        return self.persistdata
    end
    
    function ContainerData:SetValue(entry,val)
        self.persistdata[entry] = val
        self._isdatasaved = false
    end
    
    function ContainerData:SetIndexedValue(index,entry,val)--Because it's annoying using the entire cake when you just want a slice.
       if self.persistdata[index] ~= nil then
          self.persistdata[index][entry] = val 
       else
           self.persistdata[index] = {}
           self.persistdata[index][entry] = val
       end
    end
    
    function ContainerData:SetPersistent(entry,val)
        self:SetValue(entry,val)
        self:Save()
    end
    
    function ContainerData:SetIndexedPersistent(index,entry,val)
       self:SetIndexedValue(index,entry,val)
       self:Save()
    end
    

    function ContainerData:GetValue(entry)
        return self.persistdata[entry]
    end
    
    function ContainerData:GetPersistDataTable()
        return self.persistdata
    end
    
    
    
    return ContainerData