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
-- Helper Egg
--------------------------------------------------
local function collectEggs()
    local eggs, farmFolder = {}, workspace:FindFirstChild("Farm")
    if not farmFolder then return eggs end
    for _, node in ipairs(farmFolder:GetChildren()) do
        local important = node:FindFirstChild("Important")
            or (node:FindFirstChild("Farm") and node.Farm:FindFirstChild("Important"))
        if important then
            local objPhys = important:FindFirstChild("Objects_Physical")
            if objPhys then
                for _, inst in ipairs(objPhys:GetChildren()) do
                    if inst.Name == "PetEgg" or string.find(inst.Name, "Egg") then
                        table.insert(eggs, inst)
                    end
                end
            end
        end
    end
    return eggs
end

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

--------------------------------------------------
-- Tools
--------------------------------------------------
local function waitCountdown(seconds)
    for i = 1, seconds do
        if not _G.autoFarm then
            return false
        end
        task.wait(1)
    end
    return true
end

local function hatchEgg(duration)
    local tEnd = os.clock() + duration
    while os.clock() < tEnd and _G.autoFarm do
        local eggs = getEggs()
        for _, egg in ipairs(eggs) do
            PetEggService:FireServer("HatchPet", egg)
            task.wait(0.2)
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

-- Multi Place Egg (satu-satu, delay aman 0.3s antar egg)
local function multiPlaceEggs(duration)
    local startTime = os.clock()
    local endTime = startTime + duration

    while os.clock() < endTime and _G.autoFarm do
        for _, targetName in ipairs(targetEggNames) do
            local backpack = Players.LocalPlayer.Backpack
            local egg = backpack:FindFirstChild(targetName)

            if egg and destination then
                -- Step 1: Pindah ke destination
                egg.Parent = destination
                task.wait(0.3) -- biar kebaca "place"

                -- Step 2: Balikin lagi ke backpack
                local placedEgg = destination:FindFirstChild(targetName)
                if placedEgg then
                    placedEgg.Parent = backpack
                end

                -- Step 3: Delay sebelum lanjut egg berikutnya
                task.wait(0.3)
            end
        end

        -- Step 4: Delay antar cycle
        task.wait(0.8)
    end
end



local function returnEggsToBackpack()
    if not destination then return end
    for _, telur in ipairs(destination:GetChildren()) do
        if isTargetEgg(telur.Name) then
            telur.Parent = backpack
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

            -- transit ke destination
            pet.Parent = destination
            task.wait(1)

            if weight <= weightLimit then
                -- jual
                SellEvent:FireServer(pet.Name)
            else
                -- overweight → langsung balikin
                pet.Parent = backpack
                task.wait(1)
            end
        end
    end
end

-- Failsafe → apapun yg masih nongkrong di destination, balikin ke backpack
local function returnPetsAfterSellToBackpack()
    if not destination then return end
    for _, pet in ipairs(destination:GetChildren()) do
        if pet:IsA("Model") then
            pet.Parent = backpack
            task.wait(0.2)
        end
    end
end


--------------------------------------------------
-- Main Cycle (1 siklus lalu stop, lanjut lagi 25 detik)
--------------------------------------------------
local function mainCycle()
    if isRunning then return end
    isRunning = true

    repeat
        -- Step 1: Loadout 1
        PetsService:FireServer("SwapPetLoadout", 1)
        if not waitCountdown(5) then break end

        -- Step 2: Loadout 2
        PetsService:FireServer("SwapPetLoadout", 2)
        if not waitCountdown(8) then break end

        -- Step 3: Hatch eggs
        hatchEgg(12)
        if not waitCountdown(15) then break end

        -- Step 4: Balikin pet ke backpack
        returnPetsToBackpack()
        if not waitCountdown(2) then break end

        -- Step 5: Multi place egg selama 8 detik
        multiPlaceEggs(10)
        if not waitCountdown(1) then break end

        -- Step 6: Balikin sisa egg dari destination
        returnEggsToBackpack()
        if not waitCountdown(1) then break end

        -- Step 7: Loadout 3
        PetsService:FireServer("SwapPetLoadout", 3)
        if not waitCountdown(8) then break end

        -- Step 8: Jual pet
        sellPets()
        if not waitCountdown(5) then break end

        -- Step 9: Failsafe balikin pet dari destination
        returnPetsAfterSellToBackpack()
        if not waitCountdown(2) then break end

    until true

    isRunning = false

    -- kalau autoFarm masih aktif → jalan lagi 25 detik kemudian
    if _G.autoFarm then
        task.delay(25, function()
            if _G.autoFarm then
                mainCycle()
            end
        end)
    end
end


--------------------------------------------------
-- UI
--------------------------------------------------
local tab = Window:CreateTab("Main", 4483362458)

-- TextBox untuk destination
tab:CreateInput({
    Name = "Destination Folder (workspace)",
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
    Options = {"Zen Egg", "Paradise Egg", "Night Egg"},
    CurrentOption = {},
    MultipleOptions = true,
    Flag = "EggDropdown",
    Callback = function(Options)
        targetEggNames = Options
    end,
})

-- Dropdown Ignore List
tab:CreateDropdown({
    Name = "Ignore List (tidak dijual)",
    Options = {"Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl", "Raccoon", "Shiba Inu","Nihonzaru","Tanuki","Tanchozuru","Kappa", "Ostrich", "Peacock", "Capybara", "Scarlet Macaw", "Mimic Octopus", },
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
    Options = {"Hedgehog", "Mole", "Frog", "Echo Frog", "Night Owl", "Raccoon", "Shiba Inu","Nihonzaru","Tanuki","Tanchozuru","Kappa", "Ostrich", "Peacock", "Capybara", "Scarlet Macaw", "Mimic Octopus", },
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
    Name = "Auto Farm Egg",
    CurrentValue = false,
    Flag = "AutoFarmToggle",
    Callback = function(Value)
        _G.autoFarm = Value
        if Value then
            mainCycle()
        end
    end,
})


