local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "🐟 Ikan Tongkol",
   Icon = 0,
   LoadingTitle = "IkanTongkol Interface Suite",
   LoadingSubtitle = "by Makhluk Putih",
   ShowText = "IkanTongkol",
   Theme = "Default",
   ToggleUIKeybind = "K",
   DisableRayfieldPrompts = false,
   DisableBuildWarnings = false,

   ConfigurationSaving = {
      Enabled = true,
      FolderName = "IkanTongkol",
      FileName = "IkanTongkol Hub"
   }
})

--------------------------------------------------
-- Services
--------------------------------------------------
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local PetsService = ReplicatedStorage.GameEvents:WaitForChild("PetsService")
local PetEggService = ReplicatedStorage.GameEvents:WaitForChild("PetEggService")
local SellEvent = ReplicatedStorage.GameEvents:WaitForChild("SellPet_RE")
local player = Players.LocalPlayer
local backpack = player:WaitForChild("Backpack")

-- Ambil root
local char = player.Character or player.CharacterAdded:Wait()
local root = char:WaitForChild("HumanoidRootPart")

-- Tempat drop items (isi lewat TextBox UI)
local destinationName = ""
local destination = nil

--------------------------------------------------
-- Egg Handling
--------------------------------------------------
local function getEggs()
    local eggs = {}
    local farm = workspace:FindFirstChild("Farm")
    if farm and farm:FindFirstChild("Farm")
        and farm.Farm:FindFirstChild("Important")
        and farm.Farm.Important:FindFirstChild("Objects_Physical") then
        for _, obj in pairs(farm.Farm.Important.Objects_Physical:GetChildren()) do
            if obj.Name == "PetEgg" then
                table.insert(eggs, obj)
            end
        end
    end
    return eggs
end

-- Hatch egg selama N detik
local function hatchEgg(duration)
    duration = duration or 12
    local tEnd = os.clock() + duration

    while os.clock() < tEnd and _G.autoFarm do
        local eggs = getEggs()
        for _, egg in ipairs(eggs) do
            if egg.Parent then
                PetEggService:FireServer("HatchPet", egg)
                task.wait(0.2)
            end
        end
        task.wait(0.3)
    end
end

-- Balikin pet ke backpack
local function returnPetsToBackpack()
    if not destination then return end
    for _, pet in ipairs(destination:GetChildren()) do
        if pet:IsA("Model") then
            pet.Parent = backpack
            task.wait(0.3)
        end
    end
end

--------------------------------------------------
-- Egg Handling
--------------------------------------------------
local targetEggNames = {}
local function isTargetEgg(eggName)
    for _, keyword in ipairs(targetEggNames) do
        if string.find(eggName, keyword) then
            return true
        end
    end
    return false
end

local function placeEggTen()
    if not destination then return end
    for i = 1, 10 do
        for _, item in ipairs(backpack:GetChildren()) do
            if isTargetEgg(item.Name) then
                item.Parent = destination
            end
        end
        local offsetX, offsetZ = math.random(-5,5), math.random(-5,5)
        local pos = root.Position + Vector3.new(offsetX, 0, offsetZ)
        PetEggService:FireServer("CreateEgg", pos)
        task.wait(0.3)
    end
end

local function returnEggsToBackpack()
    if not destination then return end
    for _, obj in ipairs(destination:GetChildren()) do
        if isTargetEgg(obj.Name) then
            obj.Parent = backpack
            task.wait(0.2)
        end
    end
end

--------------------------------------------------
-- Sell Handling
--------------------------------------------------
local ignoreList = {}
local sellWhitelist = {}
local weightLimit = 4 -- default

local function extractWeight(petName)
    local weightStr = string.match(petName, "%[(.-) KG%]")
    return tonumber(weightStr) or 0
end

local function isIgnoredPet(petName)
    for _, keyword in ipairs(ignoreList) do
        if string.find(petName, keyword) then
            return true
        end
    end
    return false
end

local function isWhitelistedForSell(petName)
    for _, keyword in ipairs(sellWhitelist) do
        if string.find(petName, keyword) then
            return true
        end
    end
    return false
end

local function sellPets()
    if not destination then return end
    for _, pet in ipairs(backpack:GetChildren()) do
        if pet:IsA("Model") 
            and not isIgnoredPet(pet.Name) 
            and isWhitelistedForSell(pet.Name) 
        then
            local weight = extractWeight(pet.Name)
            pet.Parent = destination
            task.wait(1)
            if weight <= weightLimit then
                SellEvent:FireServer(pet.Name)
            end
        end
    end
end

-- Balikin pet ke backpack
local function returnPetsAfterSellToBackpack()
    if not destination then return end
    for _, pet in ipairs(destination:GetChildren()) do
        if pet:IsA("Model") then
            pet.Parent = backpack
            task.wait(0.3)
        end
    end
end

--------------------------------------------------
-- Fungsi tunggu yang bisa diputus
--------------------------------------------------
local function waitCountdown(seconds)
    for i = seconds,1,-1 do
        if not _G.autoFarm then return false end
        task.wait(1)
    end
    return true
end

--------------------------------------------------
-- Main Cycle (pakai waitCountdown)
--------------------------------------------------
local function mainCycle()
    while _G.autoFarm do
        if destination == nil or destinationName == "" or #targetEggNames == 0 then
            warn("⚠ Harap isi Destination & Target Egg dulu di UI!")
            return
        end

        -- Loadout 1
        PetsService:FireServer("SwapPetLoadout", 1)
        if not waitCountdown(5) then break end

        -- Loadout 2
        PetsService:FireServer("SwapPetLoadout", 2)
        if not waitCountdown(8) then break end

        hatchEgg(12)
        if not waitCountdown(15) then break end

        returnPetsToBackpack()
        if not waitCountdown(2) then break end

        placeEggTen()
        if not waitCountdown(8) then break end

        returnEggsToBackpack()
        if not waitCountdown(1) then break end

        -- Loadout 3
        PetsService:FireServer("SwapPetLoadout", 3)
        if not waitCountdown(8) then break end

        sellPets()
        if not waitCountdown(5) then break end

        returnPetsAfterSellToBackpack()
        if not waitCountdown(25) then break end
    end
end

--------------------------------------------------
-- UI
--------------------------------------------------
local tab = Window:CreateTab("Main", 4483362458)

-- TextBox untuk destination
tab:CreateInput({
    Name = "Masukan USN kamu (cek di leaderboard)",
    CurrentValue = "",
    PlaceholderText = "contoh: delhuna_12",
    RemoveTextAfterFocusLost = false,
    Flag = "DestInput",
    Callback = function(Text)
        destinationName = Text
        destination = workspace:FindFirstChild(destinationName)
    end,
})

-- Dropdown untuk target egg
tab:CreateDropdown({
    Name = "Target Egg (pilih telur)",
    Options = {"Zen Egg", "Paradise Egg", "Night Egg", "Common Egg", "Common Summer Egg"},
    CurrentOption = {},
    MultipleOptions = false,
    Flag = "EggDropdown",
    Callback = function(Options)
        targetEggNames = Options
    end,
})

-- Dropdown Ignore List
tab:CreateDropdown({
    Name = "Ignore List (tidak dijual)",
    Options = {"Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl", "Raccoon", "Shiba Inu","Nihonzaru","Tanuki","Tanchozuru","Kappa", "Ostrich", "Peacock", "Capybara", "Scarlet Macaw", "Mimic Octopus"},
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "IgnoreDropdown",
    Callback = function(Options)
        ignoreList = Options
    end,
})

-- Dropdown Whitelist Jual
tab:CreateDropdown({
    Name = "Whitelist Jual (boleh dijual)",
    Options = {"Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl", "Raccoon", "Shiba Inu","Nihonzaru","Tanuki","Tanchozuru","Kappa", "Ostrich", "Peacock", "Capybara", "Scarlet Macaw", "Mimic Octopus"},
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "WhitelistDropdown",
    Callback = function(Options)
        sellWhitelist = Options
    end,
})

-- TextBox Weight Limit
tab:CreateInput({
    Name = "Limit Berat Jual (KG)",
    CurrentValue = "4",
    PlaceholderText = "contoh: 4",
    RemoveTextAfterFocusLost = true,
    Flag = "WeightLimitInput",
    Callback = function(Text)
        local val = tonumber(Text)
        if val then
            weightLimit = val
        end
    end,
})

-- Toggle AutoFarm
tab:CreateToggle({
    Name = "Auto Farm (1 → 2 → Place Egg → 3 → Sell)",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
    Callback = function(Value)
        _G.autoFarm = Value
        if Value then
            task.spawn(mainCycle)
        end
    end,
})
