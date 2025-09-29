--=============================
-- Auto Plant + Utility + Gifting + Eggs + Auto Sell Brainrot (Final)
-- UI lib: https://raw.githubusercontent.com/IkantTongkol/Gui/refs/heads/main/Test3
--=============================

--=============================
-- UI Loader (Test3)
--=============================
local Players      = game:GetService("Players")
local LP           = Players.LocalPlayer
local PlayerGui    = LP:WaitForChild("PlayerGui")

local UI
do
    local ok, err = pcall(function()
        local src = game:HttpGet("https://raw.githubusercontent.com/IkantTongkol/Gui/refs/heads/main/Test3")
        UI = loadstring(src)()
        assert(type(UI) == "table" and UI.CreateWindow, "UI lib missing CreateWindow")
    end)
    if not ok then
        warn("[UI] Gagal load Test3:", err)
        local sg = Instance.new("ScreenGui")
        sg.Name = "AutoPlant_FallbackUI"
        sg.ResetOnSpawn = false
        sg.Parent = PlayerGui
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.fromOffset(330, 80)
        lbl.Position = UDim2.fromScale(0.03, 0.1)
        lbl.BackgroundColor3 = Color3.fromRGB(25,25,25)
        lbl.TextColor3 = Color3.fromRGB(255,255,255)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 14
        lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.TextYAlignment = Enum.TextYAlignment.Top
        lbl.Text = "UI gagal dimuat.\nCek koneksi/GitHub.\nScript berhenti."
        lbl.Parent = sg
        return
    end
end

--=============================
-- Window & Tabs
--=============================
local win      = UI:CreateWindow({ Name = "AutoPlantUI", Title = "Auto Plant (Tongkol GUI)" })
local tabPlant = win:CreateTab({ Name = "Planting" })
local tabUtil  = win:CreateTab({ Name = "Utility" })
local tabGift  = win:CreateTab({ Name = "Gifting" })
local tabEgg   = win:CreateTab({ Name = "Eggs" })
local tabSell  = win:CreateTab({ Name = "Selling" })

local function notify(t, m, d)
    if win and win.Notify then win:Notify(t, m, d or 2.0) else print(("[UI] %s: %s"):format(t, m)) end
end

--=============================
-- Services & Remotes
--=============================
local RS       = game:GetService("ReplicatedStorage")
local Plots    = workspace:WaitForChild("Plots")
local Remotes  = RS:WaitForChild("Remotes")

local EquipItemRemote          = Remotes:WaitForChild("EquipItem")
local PlaceItemRemote          = Remotes:WaitForChild("PlaceItem")
local BuyItemRemote            = Remotes:WaitForChild("BuyItem")
local BuyGearRemote            = Remotes:WaitForChild("BuyGear")
local EquipBestBrainrotsRemote = Remotes:WaitForChild("EquipBestBrainrots")
local GiftItemRemote           = Remotes:WaitForChild("GiftItem")
local AcceptGiftRemote         = Remotes:WaitForChild("AcceptGift")
local OpenEggRemote            = Remotes:WaitForChild("OpenEgg")
local FavoriteItemRemote       = Remotes:WaitForChild("FavoriteItem")
local ItemSellRemote           = Remotes:WaitForChild("ItemSell")

--=============================
-- Helpers (shared)
--=============================
local function shuffle(t)
    local rng = Random.new()
    for i = #t, 2, -1 do
        local j = rng:NextInteger(1, i)
        t[i], t[j] = t[j], t[i]
    end
end

local function partCFrame(inst)
    if inst:IsA("BasePart") then return inst.CFrame end
    if inst:IsA("Model") then
        return inst.PrimaryPart and inst.PrimaryPart.CFrame or inst:GetPivot()
    end
    return CFrame.new()
end

local function setToggleState(toggle, state)
    if not toggle then return end
    pcall(function()
        if toggle.Set then toggle:Set(state)
        elseif toggle.SetState then toggle:SetState(state)
        elseif toggle.SetValue then toggle:SetValue(state)
        elseif toggle.Toggle and toggle.State ~= state then toggle:Toggle() end
    end)
end

local function updateDropdown(drop, names)
    if drop.Refresh     and pcall(function() drop:Refresh(names, true) end) then return end
    if drop.SetOptions  and pcall(function() drop:SetOptions(names) end)    then return end
    if drop.SetItems    and pcall(function() drop:SetItems(names) end)      then return end
    if drop.ClearOptions and drop.AddOption then
        local ok = pcall(function()
            drop:ClearOptions()
            for _, n in ipairs(names) do drop:AddOption(n) end
        end)
        if ok then return end
    end
    drop.Options = names
end

local function myPlayerFolder()
    local wp = workspace:FindFirstChild("Players")
    return wp and wp:FindFirstChild(LP.Name) or nil
end

local function safeName(inst)
    local raw = (typeof(inst)=="Instance" and inst.GetAttribute and inst:GetAttribute("ItemName"))
                or (typeof(inst)=="Instance" and inst.Name)
                or tostring(inst)
    return tostring(raw):gsub("^%b[]%s*", "")
end

local function parseWeightKg(instOrName)
    local raw = typeof(instOrName)=="Instance"
        and ((instOrName.GetAttribute and instOrName:GetAttribute("ItemName")) or instOrName.Name)
        or tostring(instOrName)

    if typeof(instOrName)=="Instance" and instOrName.GetAttribute then
        local direct = instOrName:GetAttribute("Weight") or instOrName:GetAttribute("Mass")
        if type(direct)=="number" then return direct, true end
    end

    local num = tostring(raw):match("^%[%s*([%d%.,]+)%s*[kK][gG]%s*%]")
    if num then
        num = num:gsub(",", ".")
        local v = tonumber(num)
        if v then return v, true end
    end
    return 0, false
end

local function equipTool(tool)
    if not tool or not tool.Parent then return false end
    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local deadline = os.clock()+2
    if hum then pcall(function() hum:EquipTool(tool) end) end
    repeat
        if tool.Parent==char then return true end
        task.wait(0.05)
    until os.clock()>deadline
    return tool.Parent==char
end

local function isFavorited(inst)
    if typeof(inst) ~= "Instance" or not inst.GetAttribute then return false end
    local ok, v = pcall(inst.GetAttribute, inst, "Favorited")
    return ok and v == true
end

local function ensureFav(id, inst)
    if isFavorited(inst) then return end
    pcall(function() FavoriteItemRemote:FireServer(id) end)
end

--=============================
-- Planting
--=============================
local DELAY_BETWEEN     = 0.10
local AUTO_BUY_INTERVAL = 0.30

local function findMyPlot()
    for _, p in ipairs(Plots:GetChildren()) do
        if p:GetAttribute("OwnerUserId") == LP.UserId then return p end
    end
    for _, p in ipairs(Plots:GetChildren()) do
        if p:GetAttribute("Owner") == LP.Name then return p end
    end
end

local function collectGrassTiles(plot)
    local tiles = {}
    if not plot then return tiles end
    local rows = plot:FindFirstChild("Rows")
    if not rows then return tiles end
    for _, row in ipairs(rows:GetChildren()) do
        local grass = row:FindFirstChild("Grass")
        if grass then
            for _, tile in ipairs(grass:GetChildren()) do
                if tile:IsA("BasePart") or tile:IsA("Model") then
                    table.insert(tiles, tile)
                end
            end
        end
    end
    return tiles
end

local function isTileFree(tile)
    if tile:GetAttribute("Occupied") == true then return false end
    if tile:FindFirstChild("Plant") or tile:FindFirstChild("Crop") then return false end
    return true
end

-- Seeds whitelist
local SeedsFolder = RS:WaitForChild("Assets"):WaitForChild("Seeds")
local function getSeedSet()
    local set = {}
    for _, inst in ipairs(SeedsFolder:GetChildren()) do
        set[inst.Name:gsub("%s+Seed$", "")] = true
    end
    return set
end
local SEED_WHITELIST = getSeedSet()

-- Scan Backpack Seeds
local function scanBackpackSeeds()
    local bag = LP:WaitForChild("Backpack")
    local byType, seen = {}, {}
    for _, inst in ipairs(bag:GetDescendants()) do
        local id = inst.GetAttribute and inst:GetAttribute("ID")
        if id and not seen[id] then
            local itemName = (inst.GetAttribute and inst:GetAttribute("ItemName")) or inst.Name
            if itemName:find("Seed") then
                local plant = itemName:gsub("^%b[]%s*", ""):gsub("%s*Seed%s*$", "")
                if SEED_WHITELIST[plant] then
                    byType[plant] = byType[plant] or { stacks = {} }
                    table.insert(byType[plant].stacks, { id = id, inst = inst })
                    seen[id] = true
                end
            end
        end
    end
    return byType
end

local function getWorkspacePlayerFolder()
    return myPlayerFolder()
end

local function waitSeedInWorkspaceByID(id, plantName, timeout)
    local pf = getWorkspacePlayerFolder()
    if not pf then return false end
    local deadline = os.clock() + (timeout or 2)
    repeat
        for _, c in ipairs(pf:GetChildren()) do
            local ok, v = pcall(c.GetAttribute, c, "ID")
            if ok and v ~= nil and tostring(v) == tostring(id) then
                return true
            end
        end
        if plantName then
            for _, t in ipairs(pf:GetChildren()) do
                if t:IsA("Tool") and t.Name:find("Seed") and t.Name:find(plantName) then
                    return true
                end
            end
        end
        task.wait(0.05)
    until os.clock() > deadline
    return false
end

local function equipSeedIntoWorkspace(stack)
    local id   = stack.id
    local inst = stack.inst
    local plantName = (inst and ((inst.GetAttribute and inst:GetAttribute("ItemName")) or inst.Name) or "")
    plantName = plantName:gsub("^%b[]%s*"," "):gsub("%s*Seed%s*$","")

    local char = LP.Character or LP.CharacterAdded:Wait()
    local hum  = char:FindFirstChildOfClass("Humanoid")
    if hum and inst and inst.Parent then pcall(function() hum:EquipTool(inst) end) end

    pcall(function()
        if EquipItemRemote:IsA("RemoteEvent") then
            EquipItemRemote:FireServer({ ID = id, Instance = inst, ItemName = inst and inst.Name or nil })
        elseif EquipItemRemote:IsA("BindableEvent") then
            EquipItemRemote:Fire(inst or id)
        elseif EquipItemRemote:IsA("RemoteFunction") then
            EquipItemRemote:InvokeServer({ ID = id })
        end
    end)

    if waitSeedInWorkspaceByID(id, plantName, 2) then return true end

    local pf = getWorkspacePlayerFolder()
    if pf and inst and inst.Parent and not inst:IsDescendantOf(pf) then
        pcall(function() inst.Parent = pf end)
        if waitSeedInWorkspaceByID(id, plantName, 1) then return true end
    end
    return false
end

local function sendPlant(stack, tile, plantName)
    local payload = {
        ID     = stack.id,
        CFrame = partCFrame(tile),
        Item   = plantName,
        Floor  = tile,
    }
    local ok = pcall(function()
        PlaceItemRemote:FireServer(payload)
    end)
    if not ok then
        warn("[AutoPlant] PlaceItem:FireServer gagal")
    end
end

local function prepareAndSendPlant(stack, tile, plantName)
    equipSeedIntoWorkspace(stack)
    sendPlant(stack, tile, plantName)
end

-- Shop Seed/Gear
local function getAllSeedNamesFull()
    local list = {}
    for _, inst in ipairs(SeedsFolder:GetChildren()) do
        table.insert(list, inst.Name)
    end
    table.sort(list)
    return list
end

local function buySeedOnce(fullSeedName)
    local ok = pcall(function()
        BuyItemRemote:FireServer(fullSeedName)
    end)
    if not ok then warn("[AutoPlant] BuyItem gagal:", fullSeedName) end
    return ok
end

local function getAllGearNames()
    local list = {}
    local ok, gearStocks = pcall(function()
        return require(RS.Modules.Library.GearStocks)
    end)
    if ok and type(gearStocks) == "table" then
        for gearName in pairs(gearStocks) do
            if type(gearName) == "string" then table.insert(list, gearName) end
        end
    end
    if #list == 0 then list = { "Water Bucket", "Frost Blower", "Frost Grenade", "Carrot Launcher", "Banana Gun" } end
    table.sort(list)
    return list
end

local function buyGearOnce(gearName)
    local ok = pcall(function()
        BuyGearRemote:FireServer(gearName)
    end)
    if not ok then warn("[AutoPlant] BuyGear gagal:", gearName) end
    return ok
end

-- UI State (Planting)
local ownedSeeds = {}
local selectedSeeds = {}
local onlyFree, running = true, false

local ddSeeds = tabPlant:CreateDropdown({
    Name = "Seed (Planting) — Multi",
    Options = {"(Klik 'Refresh Seed')"},
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then
            selectedSeeds = values
        elseif typeof(values) == "string" then
            selectedSeeds = { values }
        else
            selectedSeeds = {}
        end
    end
})

local function refreshSeeds()
    ownedSeeds = scanBackpackSeeds()
    local names = {}
    for k in pairs(ownedSeeds) do table.insert(names, k) end
    table.sort(names)
    updateDropdown(ddSeeds, names)
    notify("Seed List", ("%d jenis ditemukan"):format(#names), 1.2)
end

tabPlant:CreateButton({ Name = "Refresh Seed (sekali)", Callback = refreshSeeds })

tabPlant:CreateToggle({
    Name = "Only Free Tiles",
    Default = true,
    Callback = function(v) onlyFree = v end
})

local function getEmptyTiles(plot)
    local tiles = collectGrassTiles(plot)
    if onlyFree then
        local free = {}
        for _, t in ipairs(tiles) do if isTileFree(t) then table.insert(free, t) end end
        tiles = free
    end
    return tiles
end

local startToggle
local function runPlantAllMulti(seedList)
    local plot = findMyPlot()
    if not plot then notify("Error","Plot tidak ditemukan",1.6); setToggleState(startToggle,false); return 0 end
    local tiles = getEmptyTiles(plot)
    if #tiles == 0 then setToggleState(startToggle,false); return 0 end
    shuffle(tiles)

    ownedSeeds = scanBackpackSeeds()

    local order = {}
    for _, name in ipairs(seedList) do
        if ownedSeeds[name] then table.insert(order, name) end
    end
    if #order == 0 then
        notify("Error","Semua pilihan tidak ada stok",1.6)
        setToggleState(startToggle,false)
        return 0
    end

    local sIdx = {}
    for _, name in ipairs(order) do sIdx[name] = 1 end

    local planted, i, seedIdx = 0, 1, 1
    while running and i <= #tiles and #order > 0 do
        local name = order[seedIdx]
        local bucket = ownedSeeds[name]
        if (not bucket) or (#bucket.stacks == 0) then
            table.remove(order, seedIdx)
            if seedIdx > #order then seedIdx = 1 end
        else
            local idx = sIdx[name]; if idx > #bucket.stacks then idx = 1 end
            local stack = bucket.stacks[idx]
            sIdx[name] = (idx % #bucket.stacks) + 1

            local tile = tiles[i]; i += 1
            prepareAndSendPlant(stack, tile, name)
            planted += 1

            seedIdx += 1
            if seedIdx > #order then seedIdx = 1 end
            task.wait(DELAY_BETWEEN)
        end
    end
    return planted
end

startToggle = tabPlant:CreateToggle({
    Name = "Auto Plant (ON/OFF)",
    Default = false,
    Callback = function(state)
        if state then
            if running then return end
            if (not selectedSeeds) or (#selectedSeeds == 0) or (#selectedSeeds == 1 and selectedSeeds[1] == "(Klik 'Refresh Seed')") then
                notify("Info","Pilih seed dulu (multi)",1.4); setToggleState(startToggle,false); return
            end
            running = true
            task.spawn(function()
                local ok, err = pcall(function()
                    local planted = runPlantAllMulti(selectedSeeds)
                    if planted > 0 then notify("Selesai", ("Planted %d total"):format(planted), 1.6) end
                end)
                if not ok then notify("Error", tostring(err), 2.0) end
                running = false
                setToggleState(startToggle,false)
            end)
        else
            running = false
        end
    end
})

-- Shop Seed (multi)
local shopSeedList = {}

tabPlant:CreateDropdown({
    Name = "Shop Seed — Multi",
    Options = getAllSeedNamesFull(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then shopSeedList = values
        elseif typeof(values) == "string" then shopSeedList = { values }
        else shopSeedList = {} end
    end
})


tabPlant:CreateButton({
    Name = "Buy 1 Seed (first selected)",
    Callback = function()
        if not shopSeedList or #shopSeedList == 0 then notify("Info","Pilih Shop Seed dulu",1.0); return end
        buySeedOnce(shopSeedList[1])
    end
})

local autoBuyingSeed = false

tabPlant:CreateToggle({
    Name = "Auto Buy Seed (0.3s)",
    Default = false,
    Callback = function(state)
        autoBuyingSeed = state
        if not autoBuyingSeed then return end
        task.spawn(function()
            local idx = 1
            while autoBuyingSeed do
                if not shopSeedList or #shopSeedList == 0 then
                    task.wait(1)
                else
                    if idx > #shopSeedList then idx = 1 end
                    buySeedOnce(shopSeedList[idx]); idx += 1
                    task.wait(AUTO_BUY_INTERVAL)
                end
            end
        end)
    end
})

-- Shop Gear (multi)
local shopGearList = {}

tabPlant:CreateDropdown({
    Name = "Shop Gear — Multi",
    Options = getAllGearNames(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then shopGearList = values
        elseif typeof(values) == "string" then shopGearList = { values }
        else shopGearList = {} end
    end
})


tabPlant:CreateButton({
    Name = "Buy 1 Gear (first selected)",
    Callback = function()
        if not shopGearList or #shopGearList == 0 then notify("Info","Pilih Shop Gear dulu",1.0); return end
        buyGearOnce(shopGearList[1])
    end
})

local autoBuyingGear = false

tabPlant:CreateToggle({
    Name = "Auto Buy Gear (0.3s)",
    Default = false,
    Callback = function(state)
        autoBuyingGear = state
        if not autoBuyingGear then return end
        task.spawn(function()
            local idx = 1
            while autoBuyingGear do
                if not shopGearList or #shopGearList == 0 then
                    task.wait(1)
                else
                    if idx > #shopGearList then idx = 1 end
                    buyGearOnce(shopGearList[idx]); idx += 1
                    task.wait(AUTO_BUY_INTERVAL)
                end
            end
        end)
    end
})

--=============================
-- Utility: Equip Best Brainrots
--=============================
local autoEquipBR = false
local brInterval  = 5


tabUtil:CreateInput({
    Name = "Auto Equip Brainrots Interval (s)",
    PlaceholderText = tostring(brInterval),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0.5 then
            brInterval = v
            notify("OK", ("Interval set ke %.2fs"):format(brInterval), 1.0)
        else
            notify("Info", "Minimal 0.5s", 1.2)
        end
    end
})


tabUtil:CreateButton({
    Name = "Equip Best Brainrots (Sekali)",
    Callback = function()
        pcall(function() EquipBestBrainrotsRemote:FireServer() end)
    end
})


tabUtil:CreateToggle({
    Name = "Auto Equip Best Brainrots (ON/OFF)",
    Default = false,
    Callback = function(state)
        autoEquipBR = state
        if not autoEquipBR then return end
        task.spawn(function()
            while autoEquipBR do
                pcall(function() EquipBestBrainrotsRemote:FireServer() end)
                task.wait(brInterval)
            end
        end)
    end
})

--=============================
-- Gifting (no seed)
--=============================
local function isSeedName(name)
    if name:match("Seed%s*$") then return true end
    if SEED_WHITELIST and SEED_WHITELIST[name:gsub("%s+Seed$","")] then return true end
    return false
end

local function collectGiftables()
    local out = {}
    local function push(inst)
        if not inst:IsA("Tool") then return end
        local name = safeName(inst)
        if isSeedName(name) then return end
        out[name] = out[name] or { tools = {} }
        table.insert(out[name].tools, inst)
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do push(t) end end
    local char = LP.Character
    if char then for _, t in ipairs(char:GetChildren()) do push(t) end end
    local pf = myPlayerFolder()
    if pf then for _, t in ipairs(pf:GetChildren()) do push(t) end end
    return out
end

local function giftTool(tool, targetUsername)
    return pcall(function()
        GiftItemRemote:FireServer({ Item = tool, ToGift = targetUsername })
    end)
end

-- Players dropdown
local playerLabelMap = {}
local ddPlayers      = nil
local function buildPlayerOptions()
    local opts, map = {}, {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local uname = p.Name
            local dname = p.DisplayName or uname
            local label = string.format("%s (@%s)", dname, uname)
            table.insert(opts, label)
            map[label] = uname
        end
    end
    table.sort(opts)
    return opts, map
end

local giftTargetUsername = ""
local giftDelay          = 0.20
local runningGift        = false
local selectedGiftNames  = {}

local ddGift = tabGift:CreateDropdown({
    Name = "Items to Gift — Multi",
    Options = (function()
        local set, inv = {}, collectGiftables()
        for name in pairs(inv) do set[name] = true end
        local list = {}
        for n in pairs(set) do table.insert(list, n) end
        table.sort(list)
        return list
    end)(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values) == "table" then
            selectedGiftNames = values
        elseif typeof(values) == "string" then
            selectedGiftNames = { values }
        else
            selectedGiftNames = {}
        end
    end
})

local function _updateDrop(drop, opts)
    if updateDropdown then return updateDropdown(drop, opts) end
    if drop.Refresh and pcall(function() drop:Refresh(opts, true) end) then return end
    if drop.SetOptions and pcall(function() drop:SetOptions(opts) end) then return end
    if drop.SetItems   and pcall(function() drop:SetItems(opts)   end) then return end
    if drop.ClearOptions and drop.AddOption then
        pcall(function()
            drop:ClearOptions()
            for _, n in ipairs(opts) do drop:AddOption(n) end
        end)
        return
    end
    drop.Options = opts
end

 do
    local opts, map = buildPlayerOptions()
    playerLabelMap = map
    ddPlayers = tabGift:CreateDropdown({
        Name = "Players Online (Recipient)",
        Options = opts,
        MultiSelection = false,
        Search = true,
        Callback = function(label)
            if type(label) == "string" and #label > 0 then
                local uname = playerLabelMap[label]
                if uname and #uname > 0 then
                    giftTargetUsername = uname
                    notify("Recipient", ("Set to: %s"):format(label), 1.0)
                end
            end
        end
    })
end


tabGift:CreateButton({
    Name = "Refresh Players",
    Callback = function()
        local opts, map = buildPlayerOptions()
        playerLabelMap = map
        _updateDrop(ddPlayers, opts)
        notify("Players", "Daftar player di-refresh", 1.0)
    end
})


tabGift:CreateButton({
    Name = "Refresh Giftables",
    Callback = function()
        local set, inv = {}, collectGiftables()
        for name in pairs(inv) do set[name] = true end
        local list = {}
        for n in pairs(set) do table.insert(list, n) end
        table.sort(list)
        _updateDrop(ddGift, list)
        notify("Gift", "Daftar giftables di-refresh", 1.0)
    end
})

local function ensureRecipient()
    if giftTargetUsername ~= "" then return true end
    local opts, map = buildPlayerOptions()
    playerLabelMap = map
    if #opts > 0 then
        local firstLabel = opts[1]
        giftTargetUsername = playerLabelMap[firstLabel] or ""
        pcall(function() if ddPlayers and ddPlayers.SetValue then ddPlayers:SetValue(firstLabel) end end)
        notify("Recipient", "Auto set: "..firstLabel, 1.0)
        return true
    end
    notify("Recipient", "Tidak ada pemain lain online", 1.2)
    return false
end


tabGift:CreateButton({
    Name = "Gift Selected Once",
    Callback = function()
        if not ensureRecipient() then return end
        if not selectedGiftNames or #selectedGiftNames == 0 then
            notify("Info","Pilih item dulu",1.0); return
        end
        local inv = collectGiftables()
        for _, name in ipairs(selectedGiftNames) do
            local bucket = inv[name]
            if bucket and #bucket.tools > 0 then
                local tool = bucket.tools[1]
                equipTool(tool)
                giftTool(tool, giftTargetUsername)
                task.wait(giftDelay)
            end
        end
    end
})

local giftToggle
local function runAutoGift()
    while runningGift do
        if not ensureRecipient() or not selectedGiftNames or #selectedGiftNames == 0 then
            task.wait(0.6)
        else
            local inv = collectGiftables()
            local nothing = true
            for _, name in ipairs(selectedGiftNames) do
                local bucket = inv[name]
                if bucket and #bucket.tools > 0 then
                    nothing = false
                    local tool = bucket.tools[1]
                    equipTool(tool)
                    giftTool(tool, giftTargetUsername)
                    task.wait(giftDelay)
                end
            end
            if nothing then task.wait(0.6) end
        end
    end
end


giftToggle = tabGift:CreateToggle({
    Name = "Auto Gift (ON/OFF)",
    Default = false,
    Callback = function(state)
        runningGift = state
        if runningGift then
            task.spawn(function()
                local ok, err = pcall(runAutoGift)
                if not ok then warn("[AutoGift] error:", err) end
                setToggleState(giftToggle, false)
            end)
        end
    end
})

-- Auto Accept Gift (single toggle)
local autoAcceptGift = false

tabGift:CreateToggle({
    Name = "Auto Accept Gift (ON/OFF)",
    Default = autoAcceptGift,
    Callback = function(state) autoAcceptGift = state end
})

GiftItemRemote.OnClientEvent:Connect(function(payload)
    if not autoAcceptGift then return end
    if type(payload) ~= "table" or not payload.ID then return end
    pcall(function() AcceptGiftRemote:FireServer({ ID = payload.ID }) end)
    pcall(function()
        local main = LP.PlayerGui:FindFirstChild("Main")
        local openUI = Remotes:FindChild("OpenUI")
        if main and main:FindFirstChild("Gifting") and openUI then
            openUI:Fire(main.Gifting, false)
        end
    end)
end)

--=============================
-- Eggs
--=============================
local function findEggTool(eggName)
    local char = LP.Character
    if char then
        for _, t in ipairs(char:GetChildren()) do
            if t:IsA("Tool") and safeName(t) == eggName then return t end
        end
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then
        for _, t in ipairs(bp:GetChildren()) do
            if t:IsA("Tool") and safeName(t) == eggName then return t end
        end
    end
    local pf = myPlayerFolder()
    if pf then
        for _, t in ipairs(pf:GetChildren()) do
            if t:IsA("Tool") and safeName(t) == eggName then return t end
        end
    end
    return nil
end

local function equipToCharacterEgg(tool)
    if not tool then return false end
    if not equipTool(tool) then return false end
    pcall(function()
        if EquipItemRemote:IsA("RemoteEvent") then
            local id = tool:GetAttribute("ID")
            EquipItemRemote:FireServer({ ID = id, Instance = tool, ItemName = tool.Name })
        end
    end)
    return true
end

local EGG_LIST = { "Godly Lucky Egg", "Meme Lucky Egg", "Secret Lucky Egg" }
local selectedEggs = {}
local eggDelay     = 0.30
local autoOpen     = false
local eggToggle, ddEggMulti


ddEggMulti = tabEgg:CreateDropdown({
    Name = "Select Eggs (Multi)",
    Options = EGG_LIST,
    MultiSelection = true,
    Search = false,
    Callback = function(values)
        if typeof(values) == "table" then
            selectedEggs = values
        elseif typeof(values) == "string" then
            selectedEggs = { values }
        else
            selectedEggs = {}
        end
    end
})


tabEgg:CreateInput({
    Name = "Open Delay (s)",
    PlaceholderText = tostring(eggDelay),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0.05 then
            eggDelay = v
            notify("Eggs", ("Delay set: %.2fs"):format(eggDelay), 1.0)
        else
            notify("Eggs", "Minimal 0.05s", 1.0)
        end
    end
})

local function openEggOnce(eggName)
    local tool = findEggTool(eggName)
    if not tool then return false end
    if not equipToCharacterEgg(tool) then return false end
    local ok = pcall(function() OpenEggRemote:FireServer(eggName) end)
    return ok
end


tabEgg:CreateButton({
    Name = "Open All Selected (Once)",
    Callback = function()
        if not selectedEggs or #selectedEggs == 0 then
            notify("Eggs", "Pilih minimal 1 egg", 1.0); return
        end
        for _, eggName in ipairs(selectedEggs) do
            openEggOnce(eggName)
            task.wait(eggDelay)
        end
    end
})

local function runAutoOpen()
    local idx = 1
    while autoOpen do
        if not selectedEggs or #selectedEggs == 0 then
            task.wait(0.6)
        else
            if idx > #selectedEggs then idx = 1 end
            local eggName = selectedEggs[idx]
            local ok = openEggOnce(eggName)
            if not ok then
                local anyOk = false
                for j = 1, #selectedEggs do
                    local k = ((idx + j - 1) % #selectedEggs) + 1
                    if openEggOnce(selectedEggs[k]) then
                        anyOk = true
                        idx = k + 1
                        break
                    end
                end
                if not anyOk then
                    autoOpen = false
                    notify("Eggs", "Tidak ada egg tersedia. Auto Open dimatikan.", 1.4)
                    setToggleState(eggToggle, false)
                    break
                end
            else
                idx = idx + 1
            end
            task.wait(eggDelay)
        end
    end
end


eggToggle = tabEgg:CreateToggle({
    Name = "Auto Open Selected Eggs (ON/OFF)",
    Default = false,
    Callback = function(state)
        autoOpen = state
        if autoOpen then
            task.spawn(function()
                local ok, err = pcall(runAutoOpen)
                if not ok then
                    warn("[AutoOpenEgg-Multi] error:", err)
                    setToggleState(eggToggle, false)
                end
            end)
        end
    end
})

--=============================
-- Selling (Whitelist / Blacklist) — dari Assets.Brainrots
-- Flow: FAV proteksi → SELL target → UNFAV proteksi
--=============================

-- Helper khusus Selling
local function _safeGetAttribute(inst, key)
    if typeof(inst) ~= "Instance" or not inst.GetAttribute then return nil end
    local ok, v = pcall(inst.GetAttribute, inst, key)
    if ok then return v end
    return nil
end

local function ensureUnfav(id, inst)
    if isFavorited(inst) then pcall(function() FavoriteItemRemote:FireServer(id) end) end
end

-- Ambil daftar brainrot dari Assets
local function getBrainrotAssetNames()
    local list = {}
    local ok, folder = pcall(function() return RS.Assets.Brainrots end)
    if not ok or not folder then return list end
    for _, ch in ipairs(folder:GetChildren()) do
        table.insert(list, ch.Name)
    end
    table.sort(list)
    return list
end

local function makeAssetSet()
    local s = {}
    for _, n in ipairs(getBrainrotAssetNames()) do s[n] = true end
    return s
end

local function isBrainrot(inst, assetSet)
    if typeof(inst) ~= "Instance" then return false end
    local n = safeName(inst)
    if assetSet[n] then return true end
    local a = _safeGetAttribute(inst, "Brainrot"); if a == true then return true end
    local c = _safeGetAttribute(inst, "Category"); if type(c)=="string" and c:lower()=="brainrot" then return true end
    return tostring(inst.Name):lower():find("brainrot") ~= nil
end

local function collectBrainrotTools(assetSet)
    local out = {}
    local function push(inst)
        if not inst:IsA("Tool") then return end
        if not isBrainrot(inst, assetSet) then return end
        local id = _safeGetAttribute(inst, "ID")
        if not id then return end
        table.insert(out, { id=tostring(id), inst=inst, name=safeName(inst) })
    end
    local bp = LP:FindFirstChild("Backpack")
    if bp then for _, t in ipairs(bp:GetChildren()) do push(t) end end
    local ch = LP.Character
    if ch then for _, t in ipairs(ch:GetChildren()) do push(t) end end
    local pf = myPlayerFolder()
    if pf then for _, t in ipairs(pf:GetChildren()) do push(t) end end
    return out
end

-- ===== UI State (Selling) =====
local sellMode = "Whitelist"          -- "Whitelist" / "Blacklist"
local selectedNames = {}              -- pilihan dari dropdown
local sellDelay = 0.12                -- jeda antar sell
local autoSelling = false

-- ===== UI (Selling) =====
local modeDD = tabSell:CreateDropdown({
    Name = "Mode",
    Options = { "Whitelist", "Blacklist" },
    MultiSelection = false,
    Search = false,
    Callback = function(v) if v then sellMode = v end end
})

local ddNames = tabSell:CreateDropdown({
    Name = "Pilih Brainrot — Multi",
    Options = getBrainrotAssetNames(),
    MultiSelection = true,
    Search = true,
    Callback = function(values)
        if typeof(values)=="table" then
            selectedNames = values
        elseif typeof(values)=="string" then
            selectedNames = { values }
        else
            selectedNames = {}
        end
    end
})


tabSell:CreateButton({
    Name = "Refresh Daftar (Assets)",
    Callback = function()
        local opts = getBrainrotAssetNames()
        if ddNames.Refresh and pcall(function() ddNames:Refresh(opts, true) end) then return end
        if ddNames.SetOptions and pcall(function() ddNames:SetOptions(opts) end) then return end
        ddNames.Options = opts
        if win and win.Notify then win:Notify("Selling", "Daftar Brainrot di-refresh", 1.0) end
    end
})


tabSell:CreateInput({
    Name = "Sell Delay (s)",
    PlaceholderText = tostring(sellDelay),
    NumbersOnly = true,
    OnEnter = false,
    RemoveTextAfterFocusLost = false,
    Callback = function(txt)
        local v = tonumber(txt)
        if v and v >= 0 then sellDelay = v else (win and win.Notify and win:Notify("Info","Masukkan angka ≥ 0",1.0)) end
    end
})

-- core plan: WL → fav non-selected, sell selected; BL → fav selected, sell non-selected
local function buildPlan(inv, assetSet)
    local sel = {}
    for _, n in ipairs(selectedNames or {}) do sel[n] = true end

    local favSet, sellList = {}, {}
    for _, it in ipairs(inv) do
        local name = it.name
        if sellMode == "Whitelist" then
            if sel[name] then
                table.insert(sellList, it)           -- yang dipilih → JUAL
            else
                favSet[it.id] = it.inst              -- lainnya → FAV proteksi
            end
        else -- Blacklist
            if sel[name] then
                favSet[it.id] = it.inst              -- yang dipilih → FAV proteksi
            else
                table.insert(sellList, it)           -- lainnya → JUAL
            end
        end
    end
    return favSet, sellList
end

-- satu siklus: fav proteksi → sell target → unfav proteksi
local function applySellCycle(assetSet)
    -- scan terbaru
    local inv = collectBrainrotTools(assetSet)

    -- susun rencana
    local favSet, sellList = buildPlan(inv, assetSet)

    -- 1) FAV proteksi
    for id, inst in pairs(favSet) do
        ensureFav(id, inst)
        task.wait(0.03)
    end

    -- 2) SELL target (tanpa equip)
    for _, it in ipairs(sellList) do
        pcall(function()
            ItemSellRemote:FireServer()  -- cukup panggil ini; sesuaikan jika server butuh argumen
        end)
        task.wait(sellDelay)
    end

    -- 3) UNFAV proteksi (balikkan ke kondisi semula)
    for id, inst in pairs(favSet) do
        ensureUnfav(id, inst)
        task.wait(0.03)
    end
end

-- tombol sekali

tabSell:CreateButton({
    Name = "Fav → Sell → Unfav (Sekali)",
    Callback = function()
        local assetSet = makeAssetSet()
        local ok, err = pcall(applySellCycle, assetSet)
        if not ok then warn("[Selling] sekali error:", err) end
    end
})

-- toggle auto

tabSell:CreateToggle({
    Name = "Auto Sell (ON/OFF)",
    Default = false,
    Callback = function(state)
        autoSelling = state
        if not autoSelling then return end
        task.spawn(function()
            local assetSet = makeAssetSet()
            while autoSelling do
                local ok, err = pcall(applySellCycle, assetSet)
                if not ok then warn("[Selling] loop error:", err) end
                task.wait(math.max(0.8, sellDelay)) -- jeda antar siklus
            end
        end)
    end
})

--=============================
-- Init seeds list (Planting tab)
--=============================
local function initPopulate()
    local names = {}
    ownedSeeds = scanBackpackSeeds()
    for k in pairs(ownedSeeds) do table.insert(names, k) end
    table.sort(names)
    updateDropdown(ddSeeds, names)
end
initPopulate()
