--[[
    ANHub V5.6 | 变身逃脱 专用工具箱
    ANUI 主面板 + 玩家/NPC ESP + 全中文物资标记 + 高价值样本重点高亮
    + 秒互动增强 + 物资/地图标记 + 视觉/移动设置 + 玩家列表/背包信息

    注意：
    - 需要在支持 Roblox 客户端 Lua 的执行环境中运行。
    - ANUI 远程地址若发生变化，请更新下面的 ANUI_URL。
    - 游戏更新可能改变 Workspace 地图结构或 Handler 字段，相关标记会自动尽力识别。
]]

local ENV = _G
pcall(function() ENV = getgenv() end)

if ENV.__ANHub_V5_Cleanup then
    pcall(ENV.__ANHub_V5_Cleanup)
end
if ENV.__ANHub_V4_Cleanup then
    pcall(ENV.__ANHub_V4_Cleanup)
end

local ANUI_URL = "https://raw.githubusercontent.com/ANHub-Script/ANUI/refs/heads/main/dist/main.lua"
local ANUI = loadstring(game:HttpGet(ANUI_URL))()

local Players = game:GetService("Players")
local Workspace = workspace
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local UserInputService = game:GetService("UserInputService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local Window = ANUI:CreateWindow({
    Title = "变身逃脱 | ANHub V5.6",
    Author = "ANHub",
    Icon = "scan-eye",
    Folder = "ANHub_BianShen_Toolbox",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightShift,
    OpenButton = {
        Title = "ANHub 工具箱",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false
    }
})

if not Window then
    error("ANUI 创建窗口失败")
end

pcall(function()
    Window:Tag({Title = "孤立胶兽感染实验 V5.6", Icon = "shield"})
end)

local Tabs = {
    overview = Window:Tab({Title = "总览", Icon = "house", Desc = "运行状态和快捷恢复"}),
    esp = Window:Tab({Title = "全图 ESP", Icon = "scan-eye", Desc = "玩家、敌人、物资和地图标记"}),
    map = Window:Tab({Title = "物资与地图", Icon = "package", Desc = "物资、储物点、门禁和交互点"}),
    visual = Window:Tab({Title = "视觉设置", Icon = "sun", Desc = "本地亮度、雾效与视野"}),
    movement = Window:Tab({Title = "移动设置", Icon = "move", Desc = "本地速度、跳跃和自我旋转"}),
    players = Window:Tab({Title = "玩家与背包", Icon = "users", Desc = "玩家列表、阵营和工具清单"}),
    isolate = Window:Tab({Title = "隐蔽感染", Icon = "map-pin", Desc = "寻找落单胶兽、隐蔽性检查与感染监控"}),
}

local Config = {
    playerESP = true,
    enemyESP = true,
    autoFaction = true,
    names = true,
    lootESP = true,
    storageESP = true,
    containerContentsESP = true,
    infectionESP = true,
    infectionEstimate = true,
    infectionAssumedSeconds = 120,
    gateESP = true,
    spawnESP = false,
    corpseESP = true,
    interactESP = false,
    halfInfectionLock = false,
    instantInteract = false,
    isolationRadius = 200,
    isolationRetreat = true,

    fullBright = false,
    noFog = false,
    fovEnabled = false,
    fov = 80,

    speedEnabled = false,
    speed = 28,
    jumpEnabled = false,
    jump = 75,
    spinEnabled = false,
    spinSpeed = 240,
}

local Marks = {}
local Original = {
    brightness = Lighting.Brightness,
    clockTime = Lighting.ClockTime,
    ambient = Lighting.Ambient,
    outdoorAmbient = Lighting.OutdoorAmbient,
    fogStart = Lighting.FogStart,
    fogEnd = Lighting.FogEnd,
    globalShadows = Lighting.GlobalShadows,
    fov = Workspace.CurrentCamera and Workspace.CurrentCamera.FieldOfView or 70,
}
local BaseMovement = {}
local MapStats = {players = 0, friends = 0, foes = 0, npcs = 0, loot = 0, samples = 0, valuable = 0, storage = 0, gates = 0, spawns = 0, corpses = 0, interact = 0}
local LastStatusUpdate = 0
local ScanElapsed = 0
local ScanInterval = 4.5 -- 原版 0.6 秒会反复扫全图；改为低频分批扫描
local RefreshBusy = false
local Running = true
local WALK_YIELD_EVERY = 180
local MAX_LOOT_MARKS = 120
local MAX_CONTAINER_MARKS = 100
local PlayerRefreshElapsed = 0
local StorageDiagnostics = {}

-- 分批遍历实例树，避免一次性 GetDescendants() 为大型地图创建巨型数组并卡住渲染帧。
local function walkDescendants(root, callback, includeRoot)
    if not root then return 0 end
    local stack = {}
    if includeRoot then
        stack[1] = root
    else
        local first = root:GetChildren()
        for i = 1, #first do stack[#stack + 1] = first[i] end
    end

    local processed = 0
    while #stack > 0 do
        local object = stack[#stack]
        stack[#stack] = nil
        if object and (object == root or object.Parent) then
            callback(object)
            local children = object:GetChildren()
            for i = 1, #children do
                stack[#stack + 1] = children[i]
            end
        end
        processed += 1
        if processed % WALK_YIELD_EVERY == 0 then
            task.wait()
        end
    end
    return processed
end

local StorageNames = {
    Locker = "储物柜",
    Crate = "物资箱",
    Drawer = "抽屉",
    Container = "储物箱",
    Shelf = "货架",
    Counter = "柜台",
    ["Metal Table"] = "金属桌",
}

-- 物品名称本地化与价值分级。样本最高优先级，重要物资次之。
-- 只改变本地显示，不会创建物品，也不会改变服务器库存。
local ItemRules = {
    {label = "血液样本", tier = 3, patterns = {"bloodsample", "bloodspecimen", "血液样本"}},
    {label = "组织样本", tier = 3, patterns = {"tissuesample", "tissuespecimen", "组织样本"}},
    {label = "病毒样本", tier = 3, patterns = {"virussample", "pathogensample", "病毒样本"}},
    {label = "血清样本", tier = 3, patterns = {"serumsample", "serum", "血清样本", "血清"}},
    {label = "实验样本 A", tier = 3, exact = {"samplea", "sample1", "specimena"}},
    {label = "实验样本 B", tier = 3, exact = {"sampleb", "sample2", "specimenb"}},
    {label = "实验样本 C", tier = 3, exact = {"samplec", "sample3", "specimenc"}},
    {label = "研究数据", tier = 2, patterns = {"researchdata", "researchfile", "研究数据", "实验数据"}},
    {label = "样本", tier = 3, patterns = {"sample", "specimen", "样本", "标本"}},
    {label = "门禁卡", tier = 2, patterns = {"keycard", "accesscard", "securitycard", "keyfob", "门禁卡", "钥匙卡"}},
    {label = "急救包", tier = 2, patterns = {"medkit", "medicalkit", "firstaidkit", "firstaid", "急救包", "医疗包"}},
    {label = "解毒剂", tier = 2, patterns = {"antidote", "解毒剂"}},
    {label = "注射器", tier = 2, patterns = {"syringe", "injection", "注射器", "针管"}},
    {label = "能源电池", tier = 2, patterns = {"powercell", "energycell", "能源电池"}},
    {label = "电池", tier = 2, patterns = {"battery", "电池", "电芯"}},
    {label = "保险丝", tier = 2, patterns = {"fuse", "保险丝"}},
    {label = "弹药", tier = 2, patterns = {"ammunition", "ammo", "bullets", "弹药"}},
    {label = "燃料桶", tier = 2, patterns = {"gascan", "fuelcan", "fuelcontainer", "燃料桶", "汽油桶"}},
    {label = "门钥匙", tier = 2, exact = {"key", "housekey", "labkey", "门钥匙", "钥匙"}, patterns = {"钥匙"}},
    {label = "药品", tier = 1, patterns = {"medicine", "medication", "pills", "tablet", "药品", "药片", "药物"}},
    {label = "绷带", tier = 1, patterns = {"bandage", "绷带"}},
    {label = "手电筒", tier = 1, patterns = {"flashlight", "torch", "手电筒", "手电"}},
    {label = "无线电", tier = 1, patterns = {"radio", "walkietalkie", "无线电", "对讲机"}},
    {label = "扳手", tier = 1, patterns = {"wrench", "扳手"}},
    {label = "螺丝刀", tier = 1, patterns = {"screwdriver", "螺丝刀"}},
    {label = "撬棍", tier = 1, patterns = {"crowbar", "撬棍"}},
    {label = "锤子", tier = 1, patterns = {"hammer", "锤子"}},
    {label = "电线", tier = 1, patterns = {"wire", "cable", "电线", "线缆"}},
    {label = "金属零件", tier = 1, patterns = {"metalpart", "scrapmetal", "metalcomponent", "金属零件", "金属废料"}},
    {label = "稀有物资", tier = 2, patterns = {"crystal", "artifact", "relic", "rare", "晶体", "遗物", "核心", "稀有"}},
    {label = "饮用水", tier = 1, patterns = {"waterbottle", "drinkingwater", "饮用水", "水瓶"}},
    {label = "食物", tier = 1, patterns = {"food", "snack", "ration", "食物", "口粮", "零食"}},
}
local UnknownItemLabels = {}
local UnknownItemCount = 0

local function normalizeItemName(value)
    return string.lower(tostring(value or "")):gsub("[%s%p]", "")
end

local function getItemNameCandidates(object)
    local candidates, seen = {}, {}
    if not object then return candidates end
    local function add(value)
        if typeof(value) == "string" and value ~= "" and not seen[value] then
            seen[value] = true
            table.insert(candidates, value)
        end
    end

    -- 优先检查游戏可能提供的显示名/物品 ID；只看 Instance.Name 会漏掉很多真实物资名。
    for _, attributeName in ipairs({
        "DisplayNameCN", "ChineseName", "LocalizedName", "DisplayName", "ItemName",
        "ItemId", "ItemID", "ItemType", "Type", "Category", "Name"
    }) do
        local ok, value = pcall(function() return object:GetAttribute(attributeName) end)
        if ok then add(value) end
    end
    add(object.Name)

    -- 有些 Tool 的 Tooltip 才是实际物品名；作为后备候选，而不是无条件覆盖 Instance.Name。
    if object:IsA("Tool") then
        local ok, tip = pcall(function() return object.ToolTip end)
        if ok then add(tip) end
    end
    return candidates
end

local function classifyItemName(rawName)
    local normalized = normalizeItemName(rawName)
    for _, rule in ipairs(ItemRules) do
        for _, exactName in ipairs(rule.exact or {}) do
            if normalized == normalizeItemName(exactName) then
                return rule.label, rule.tier
            end
        end
        for _, pattern in ipairs(rule.patterns or {}) do
            local needle = normalizeItemName(pattern)
            if needle ~= "" and string.find(normalized, needle, 1, true) then
                return rule.label, rule.tier
            end
        end
    end
    return nil, 0
end

local GenericNameParts = {
    {"gasmask", "防毒面具"}, {"mask", "面具"}, {"medkit", "急救包"},
    {"firstaid", "急救包"}, {"bandage", "绷带"}, {"antidote", "解毒剂"},
    {"syringe", "注射器"}, {"blood", "血液"}, {"tissue", "组织"},
    {"sample", "样本"}, {"specimen", "样本"}, {"serum", "血清"},
    {"research", "研究资料"}, {"document", "文件"}, {"paper", "纸张"},
    {"notebook", "笔记本"}, {"keycard", "门禁卡"}, {"accesscard", "门禁卡"},
    {"key", "钥匙"}, {"battery", "电池"}, {"powercell", "能源电池"},
    {"fuse", "保险丝"}, {"ammo", "弹药"}, {"bullet", "子弹"},
    {"flashlight", "手电筒"}, {"radio", "无线电"}, {"walkie", "对讲机"},
    {"wrench", "扳手"}, {"screwdriver", "螺丝刀"}, {"crowbar", "撬棍"},
    {"hammer", "锤子"}, {"wire", "电线"}, {"cable", "线缆"},
    {"metal", "金属零件"}, {"scrap", "废料"}, {"fuel", "燃料"},
    {"gascan", "汽油桶"}, {"water", "饮用水"}, {"bottle", "瓶子"},
    {"food", "食物"}, {"snack", "零食"}, {"ration", "口粮"},
    {"coin", "硬币"}, {"money", "钱币"}, {"cash", "现金"},
    {"crystal", "晶体"}, {"artifact", "遗物"}, {"relic", "遗物"},
    {"computer", "电脑"}, {"laptop", "笔记本电脑"}, {"usb", "U盘"},
    {"flashdrive", "U盘"}, {"toolbox", "工具箱"}, {"tool", "工具"},
    {"box", "箱子"}, {"crate", "物资箱"}, {"locker", "储物柜"},
}

local function fallbackChineseLabel(rawName)
    local normalized = normalizeItemName(rawName)
    for _, pair in ipairs(GenericNameParts) do
        if string.find(normalized, pair[1], 1, true) then
            return pair[2]
        end
    end
    -- 若游戏直接把中文显示名放在实例名里，原样保留。
    if rawName ~= "" and not string.find(rawName, "%a") then return rawName end
    return "普通物资"
end

local function classifyItemObject(object)
    local candidates = getItemNameCandidates(object)
    local rawName = candidates[1] or (object and object.Name) or ""
    local bestLabel, bestTier, bestRaw = nil, 0, rawName

    -- 在内部名、属性名和 Tooltip 中逐个找匹配；优先保留最高价值等级。
    for _, candidate in ipairs(candidates) do
        local label, tier = classifyItemName(candidate)
        if label and (not bestLabel or tier > bestTier) then
            bestLabel, bestTier, bestRaw = label, tier, candidate
            if tier >= 3 then break end
        end
    end

    if bestLabel then return bestLabel, bestTier, bestRaw end

    -- 不再把整张地图的物品都显示成“未收录物资 01/02/03”。
    -- 使用属性/名称里可识别的词汇生成中文兜底；完全无法判断时统一显示“普通物资”。
    for _, candidate in ipairs(candidates) do
        local fallback = fallbackChineseLabel(candidate)
        if fallback ~= "普通物资" then
            return fallback, 0, candidate
        end
    end
    return fallbackChineseLabel(rawName), 0, rawName
end

local function getItemStyle(tier)
    if tier >= 3 then
        return "★★★ 高价值样本 ★★★", Color3.fromRGB(255, 35, 220), {
            fillTransparency = 0.10,
            outlineColor = Color3.fromRGB(255, 245, 70),
            textColor = Color3.fromRGB(255, 248, 80),
            textSize = 17,
            billboardSize = UDim2.fromOffset(410, 88),
            studsOffset = Vector3.new(0, 4.6, 0),
            strokeColor = Color3.fromRGB(75, 0, 55),
            strokeTransparency = 0.02,
        }
    elseif tier >= 2 then
        return "【高价值】", Color3.fromRGB(255, 125, 30), {
            fillTransparency = 0.26,
            outlineColor = Color3.fromRGB(255, 225, 80),
            textColor = Color3.fromRGB(255, 190, 75),
            textSize = 15,
            billboardSize = UDim2.fromOffset(360, 82),
            studsOffset = Vector3.new(0, 4.0, 0),
            strokeColor = Color3.fromRGB(50, 20, 0),
            strokeTransparency = 0.05,
        }
    elseif tier >= 1 then
        return "【重要物资】", Color3.fromRGB(80, 230, 180), {
            fillTransparency = 0.46,
            outlineColor = Color3.fromRGB(120, 255, 220),
            textColor = Color3.fromRGB(135, 255, 220),
            textSize = 14,
            billboardSize = UDim2.fromOffset(330, 76),
            studsOffset = Vector3.new(0, 3.7, 0),
            strokeColor = Color3.fromRGB(0, 35, 30),
            strokeTransparency = 0.08,
        }
    end
    return "【物资】", Color3.fromRGB(125, 190, 255), {
        fillTransparency = 0.68,
        outlineColor = Color3.fromRGB(150, 210, 255),
        textColor = Color3.fromRGB(180, 220, 255),
        textSize = 13,
        billboardSize = UDim2.fromOffset(310, 72),
        studsOffset = Vector3.new(0, 3.5, 0),
        strokeColor = Color3.fromRGB(10, 10, 10),
        strokeTransparency = 0.1,
    }
end

local function getValue(model, name)
    if not model then return nil end
    local handler = model:FindFirstChild("Handler")
    local item = handler and handler:FindFirstChild(name, true)
    if item and item:IsA("ValueBase") then return item.Value end
    return nil
end

-- === 实验功能：变异后尝试本地半感染锁定（不会在打开开关时立即生效） ===
local halfWatchedHandler = nil
local halfWatchConnections = {}
local halfSnapshot = {}
local halfLockLatched = false
local halfApplying = false
local halfSuppressUntil = 0

local function getLocalHandler()
    local character = LocalPlayer.Character
    return character and character:FindFirstChild("Handler") or nil
end

local function disconnectHalfWatcher()
    for _, connection in ipairs(halfWatchConnections) do
        pcall(function() connection:Disconnect() end)
    end
    halfWatchConnections = {}
end

local function enforceHalfInfectionLocal()
    if not Config.halfInfectionLock or halfApplying then return end
    local handler = getLocalHandler()
    if not handler then return end

    halfLockLatched = true
    halfApplying = true
    halfSuppressUntil = os.clock() + 0.35

    -- 实验性本地近似值：服务器若重写这些值，客户端尝试持续维持。
    local desired = {
        Hazard = 50,
        Infected = false,
        Poisoned = true,
        PoisonStage = 1,
        Awaken = false,
    }

    for name, value in pairs(desired) do
        local object = handler:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            pcall(function() object.Value = value end)
        end
    end

    halfApplying = false
    for _, name in ipairs({"Hazard", "Infected", "Poisoned", "PoisonStage", "Awaken", "LType"}) do
        local object = handler:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            halfSnapshot[name] = object.Value
        end
    end
end

local function refreshHalfLockWatcher(force)
    local handler = getLocalHandler()
    if not force and handler == halfWatchedHandler then return end

    disconnectHalfWatcher()
    halfWatchedHandler = handler
    halfSnapshot = {}
    if not handler then return end

    local watchedNames = {"LType", "Infected", "Poisoned", "PoisonStage", "Hazard", "Awaken"}
    for _, name in ipairs(watchedNames) do
        local object = handler:FindFirstChild(name)
        if object and object:IsA("ValueBase") then
            halfSnapshot[name] = object.Value
            table.insert(halfWatchConnections, object:GetPropertyChangedSignal("Value"):Connect(function()
                local newValue = object.Value
                local oldValue = halfSnapshot[name]
                halfSnapshot[name] = newValue

                if halfApplying or os.clock() < halfSuppressUntil or not Config.halfInfectionLock then
                    return
                end

                local triggered = false
                if name == "LType" then
                    triggered = newValue ~= oldValue and tostring(newValue) ~= ""
                elseif name == "Infected" or name == "Poisoned" then
                    triggered = newValue == true and oldValue ~= true
                elseif name == "PoisonStage" then
                    triggered = (tonumber(newValue) or 0) > 0 and (tonumber(oldValue) or 0) <= 0
                elseif name == "Hazard" then
                    triggered = (tonumber(newValue) or 0) >= 100 and (tonumber(oldValue) or 0) < 100
                elseif name == "Awaken" then
                    triggered = newValue == true and oldValue ~= true
                end

                if triggered then
                    task.defer(enforceHalfInfectionLocal)
                end
            end))
        end
    end

    table.insert(halfWatchConnections, handler.DescendantAdded:Connect(function()
        task.defer(function() refreshHalfLockWatcher(true) end)
    end))
end

-- getRoot 在下方定义；先声明以便交互输入回调捕获同一个局部函数。
local getRoot

-- === 秒互动增强：提示长按归零 + 动态重应用 + 按提示键时触发兜底 ===
local promptOriginals = setmetatable({}, {__mode = "k"})
local promptTriggerTimes = setmetatable({}, {__mode = "k"})
local interactionReapplyElapsed = 0

local function setPromptInstant(prompt, enabled)
    if not prompt or not prompt:IsA("ProximityPrompt") then return end
    if enabled then
        if not promptOriginals[prompt] then
            promptOriginals[prompt] = {
                HoldDuration = prompt.HoldDuration,
                RequiresLineOfSight = prompt.RequiresLineOfSight,
            }
        end
        pcall(function()
            prompt.HoldDuration = 0
            prompt.RequiresLineOfSight = false
        end)
    else
        local original = promptOriginals[prompt]
        if original then
            pcall(function()
                prompt.HoldDuration = original.HoldDuration
                prompt.RequiresLineOfSight = original.RequiresLineOfSight
            end)
            promptOriginals[prompt] = nil
        end
    end
end

local function setInstantInteract(enabled)
    Config.instantInteract = enabled
    local promptCount = 0
    if not enabled then
        -- 只遍历之前实际改过的提示，避免关闭时再次全图扫描。
        for prompt in pairs(promptOriginals) do
            if prompt and prompt.Parent then
                setPromptInstant(prompt, false)
            else
                promptOriginals[prompt] = nil
            end
        end
        return 0
    end

    walkDescendants(Workspace, function(object)
        if object:IsA("ProximityPrompt") then
            promptCount += 1
            setPromptInstant(object, true)
        end
    end, false)
    return promptCount
end

local function reapplyInstantInteract()
    if not Config.instantInteract then return end
    for prompt in pairs(promptOriginals) do
        if prompt and prompt.Parent then
            setPromptInstant(prompt, true)
        end
    end
end

local interactionAddedConnection = Workspace.DescendantAdded:Connect(function(object)
    if Config.instantInteract and object:IsA("ProximityPrompt") then
        task.defer(function()
            if Config.instantInteract and object.Parent then
                setPromptInstant(object, true)
            end
        end)
    end
end)

local promptShownConnection = ProximityPromptService.PromptShown:Connect(function(prompt)
    if Config.instantInteract then
        task.defer(function()
            if Config.instantInteract and prompt and prompt.Parent then
                setPromptInstant(prompt, true)
            end
        end)
    end
end)

local promptTriggeredConnection = ProximityPromptService.PromptTriggered:Connect(function(prompt)
    promptTriggerTimes[prompt] = os.clock()
end)

local interactionInputConnection = UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not Config.instantInteract or input.KeyCode == Enum.KeyCode.Unknown then
        return
    end

    local characterRoot = getRoot(LocalPlayer.Character)
    if not characterRoot then return end

    local bestPrompt, bestDistance = nil, math.huge
    for prompt in pairs(promptOriginals) do
        if prompt and prompt.Parent and prompt.Enabled and prompt.KeyboardKeyCode == input.KeyCode then
            local promptParent = prompt.Parent
            local part = nil
            if promptParent:IsA("Attachment") then
                part = promptParent.Parent
            else
                part = getRoot(promptParent)
            end
            if part and part:IsA("BasePart") then
                local distance = (characterRoot.Position - part.Position).Magnitude
                local allowedDistance = tonumber(prompt.MaxActivationDistance) or 0
                if distance <= allowedDistance and distance < bestDistance then
                    bestPrompt = prompt
                    bestDistance = distance
                end
            end
        end
    end

    if not bestPrompt then return end
    local selected = bestPrompt
    local inputTime = os.clock()
    task.delay(0.12, function()
        if not Config.instantInteract or not selected.Parent then return end
        -- 原生零等待若已成功触发，不重复触发；仅在未收到本地触发回执时兜底。
        if (promptTriggerTimes[selected] or 0) >= inputTime then return end

        local firePrompt = fireproximityprompt
        if typeof(firePrompt) == "function" then
            pcall(firePrompt, selected, 0)
        else
            pcall(function()
                selected:InputHoldBegin()
                task.delay(0.03, function()
                    if selected and selected.Parent then
                        pcall(function() selected:InputHoldEnd() end)
                    end
                end)
            end)
        end
    end)
end)

local function getHandler(model)
    return model and model:FindFirstChild("Handler") or nil
end

getRoot = function(object)
    if not object then return nil end
    if object:IsA("BasePart") then return object end
    if object:IsA("Tool") then
        return object:FindFirstChild("Handle", true)
            or object:FindFirstChild("_Handle", true)
            or object:FindFirstChildWhichIsA("BasePart", true)
    end
    return object:FindFirstChild("HumanoidRootPart")
        or object:FindFirstChild("UpperTorso")
        or object:FindFirstChild("Torso")
        or object:FindFirstChild("Head")
        or object.PrimaryPart
        or object:FindFirstChildWhichIsA("BasePart", true)
end

local function getHumanoid(model)
    return model and model:FindFirstChildOfClass("Humanoid") or nil
end

-- 实测优先：真正的感染值来自客户端已经同步的数据。
-- 估算只根据实测变化速度或者本会话观察到的“未感染→感染中”事件。
-- 如果从未看到开始事件，也没有历史实测值，不能凭空计算一个百分比。
local InfectionFieldNames = {
    infected = {"Infected", "IsInfected", "InfectionState"},
    hazard = {"Hazard", "InfectionProgress", "InfectionPercent", "InfectionPercentage", "Corruption"},
    poisoned = {"Poisoned", "IsPoisoned"},
    stage = {"PoisonStage", "InfectionStage", "TransformationStage"},
    bitten = {"Bitten", "BiteCount", "Bites"},
    awaken = {"Awaken", "Awakened", "IsAwakened"},
    ltype = {"LType", "LatexType", "InfectionType"},
}
local InfectionHistory = setmetatable({}, {__mode = "k"})
local InfectionRate = nil  -- 根据客户端观察到的真实增量计算经验增长速度（百分比/秒）
local InfectionSamples = 0
local function readReplicatedField(model, player, names)
    local roots = {}
    if model then
        local handler = model:FindFirstChild("Handler")
        if handler then table.insert(roots, handler) end
        table.insert(roots, model)
    end
    if player then table.insert(roots, player) end
    for _, root in ipairs(roots) do
        for _, name in ipairs(names) do
            local value = root:GetAttribute(name)
            if value ~= nil and (typeof(value) == "number" or typeof(value) == "boolean" or typeof(value) == "string") then
                return value, name
            end
            local object = root:FindFirstChild(name)
            if not object and root.Name == "Handler" then
                object = root:FindFirstChild(name, true)
            end
            if object and object:IsA("ValueBase") then
                return object.Value, name
            end
        end
    end
    return nil, nil
end

local function getInfectionInfo(model, player)
    local infected = readReplicatedField(model, player, InfectionFieldNames.infected)
    local hazard, hazardKey = readReplicatedField(model, player, InfectionFieldNames.hazard)
    local poisoned = readReplicatedField(model, player, InfectionFieldNames.poisoned)
    local stage = readReplicatedField(model, player, InfectionFieldNames.stage)
    -- V4 已验证的感染相关字段：被咬次数、觉醒标志、感染类型。
    local bitten = readReplicatedField(model, player, InfectionFieldNames.bitten)
    local awaken = readReplicatedField(model, player, InfectionFieldNames.awaken)
    local ltype = readReplicatedField(model, player, InfectionFieldNames.ltype)

    if typeof(infected) == "string" then
        local str = infected:lower()
        if str == "true" or str == "infected" or str == "yes" then infected = true
        elseif str == "false" or str == "human" or str == "no" then infected = false
        else infected = nil end
    end
    if typeof(poisoned) == "string" then
        local str = poisoned:lower()
        if str == "true" or str == "yes" then poisoned = true
        elseif str == "false" or str == "no" then poisoned = false
        else poisoned = nil end
    end
    if typeof(awaken) == "string" then
        local aw = awaken:lower()
        if aw == "true" or aw == "yes" or aw == "1" then awaken = true
        elseif aw == "false" or aw == "no" or aw == "0" then awaken = false
        else awaken = nil end
    end
    local amount = tonumber(hazard)
    if amount and (hazardKey == "InfectionProgress" or hazardKey == "Corruption")
        and amount > 0 and amount <= 1 then
        amount *= 100
    end
    if amount ~= nil then
        if amount ~= amount or amount == math.huge or amount == -math.huge then amount = nil
        else amount = math.clamp(amount, 0, 100) end
    end

    local now = os.clock()
    local key = player or model
    local history = key and InfectionHistory[key] or nil
    if key and (not history or (model and history.character ~= model)) then
        history = {character = model}
        InfectionHistory[key] = history
    end

    -- 只有实际观察到上一刻未感染，下一刻开始中毒/感染，才启动计时。
    -- 不把进入服务器时已感染的人误认为刚刚开始感染。
    local progressWasClean = history and history.lastActual == 0
    local becamePoisoned = history and history.previousPoisoned == false and poisoned == true
    local becameProgressing = history and progressWasClean and amount and amount > 0
    if history and (becamePoisoned or becameProgressing) and not history.onset then
        history.onset = now
    end
    if history and poisoned == false and (amount == nil or amount <= 0) then
        history.onset = nil
    end
    if history and amount == 0 then history.onset = nil end

    -- 校准：排除太短的采样间隔、突变和通过脚本人为修改的自身感染数据。
    if history and amount ~= nil then
        local last = history.lastActual
        local dt = history.lastActualAt and now - history.lastActualAt or nil
        if last ~= nil and dt and dt >= 0.75 and dt <= 30 and amount > last
            and amount - last <= 30 and not (player == LocalPlayer and Config.halfInfectionLock) then
            local rate = (amount - last) / dt
            if rate >= 0.03 and rate <= 20 then
                history.slope = history.slope and history.slope * 0.65 + rate * 0.35 or rate
                InfectionRate = InfectionRate and InfectionRate * 0.8 + rate * 0.2 or rate
                InfectionSamples += 1
            end
        end
        -- 每隔约一秒记录实测值，避免一次 UI 重绘就把历史时间重置。
        if not history.lastActualAt or now - history.lastActualAt >= 0.75 then
            history.lastActual = amount
            history.lastActualAt = now
        end
    end
    if history then
        if poisoned ~= nil then history.previousPoisoned = poisoned end
        if amount ~= nil then history.lastKnownActual = amount end
    end

    local teamName = player and player.Team and player.Team.Name:lower() or ""
    local teamInfected = teamName:find("infect", 1, true)
        or teamName:find("latex", 1, true) or teamName:find("mutant", 1, true)
    local status, color = "未知", Color3.fromRGB(190, 190, 190)
    if infected == true or teamInfected or (amount and amount >= 100) then
        if awaken == true then
            status, color = "有意识感染者", Color3.fromRGB(205, 110, 255)
        elseif awaken == false then
            status, color = "感染者（未觉醒）", Color3.fromRGB(255, 65, 85)
        else
            status, color = "已感染", Color3.fromRGB(255, 65, 85)
        end
    elseif (amount and amount > 0) or poisoned == true or (tonumber(stage) or 0) > 0 then
        status, color = "感染中", Color3.fromRGB(255, 180, 65)
    elseif infected == false or amount == 0 then
        status, color = "未感染", Color3.fromRGB(80, 225, 145)
    end

    local shown, evidence = amount, amount and "同步实测" or nil
    if shown == nil and Config.infectionEstimate and history then
        local age = history.lastActualAt and (now - history.lastActualAt) or nil
        if age and age <= 10 and history.lastActual ~= nil then
            -- 实测值暂时丢失：沿用同一玩家过去真实观察到的增长速率。
            local slope = history.slope
            if slope and slope > 0 and status ~= "未感染" then
                shown = math.clamp(history.lastActual + slope * age, 0, 100)
                evidence = "趋势外推·中可信"
            else
                shown = history.lastActual
                evidence = "历史实测·已过" .. math.floor(age) .. "秒"
            end
        elseif history.onset and status == "感染中" then
            -- 可观察到本局开始感染的时刻时，才能启用计时估计。
            -- 经验速率由其他真实读数学习；不足时按可调假设感染时长计算。
            local elapsed = now - history.onset
            if InfectionSamples >= 2 and InfectionRate then
                shown = math.clamp(elapsed * InfectionRate, 0, 99)
                evidence = "经验速率估算·低可信"
            else
                shown = math.clamp(elapsed / Config.infectionAssumedSeconds * 100, 0, 99)
                evidence = "假设时长估算·低可信"
            end
        end
    end
    if (status == "已感染" or status == "有意识感染者" or status == "感染者（未觉醒）")
        and shown ~= nil and evidence ~= "同步实测" then
        -- 阵营 / 感染标志不一定对应进度刚好达到 100，避免估值冒充实测。
        evidence = evidence .. "（状态已变）"
    end

    local pieces = {"感染：" .. status}
    if shown ~= nil then
        local prefix = evidence == "同步实测" and "" or "≈"
        local blocks = math.clamp(math.floor(shown / 10), 0, 10)
        -- 参考 V4 使用直观的感染度条；真实/估算始终明确标注。
        table.insert(pieces, string.format("感染度 %s%.0f/100 [%s] %s",
            prefix, shown, string.rep("█", blocks) .. string.rep("·", 10 - blocks), evidence or "未知"))
    else
        table.insert(pieces, "感染度：未同步 / 无足够观测")
    end
    local more = {}
    if stage ~= nil then table.insert(more, "毒阶段 " .. tostring(stage)) end
    if bitten ~= nil then table.insert(more, "被咬 " .. tostring(bitten)) end
    if awaken ~= nil then table.insert(more, awaken and "已觉醒" or "未觉醒") end
    if ltype ~= nil and tostring(ltype) ~= "" then table.insert(more, "类型 " .. tostring(ltype)) end
    if #more > 0 then table.insert(pieces, "\n" .. table.concat(more, " | ")) end
    return {
        status = status, color = color, progress = shown, source = evidence,
        stage = stage, bitten = bitten, awaken = awaken, ltype = ltype,
        infected = (infected == true or teamInfected ~= nil or (amount and amount >= 100) or false),
        text = table.concat(pieces, " | "),
    }
end

local function isInfected(model, player)
    return getInfectionInfo(model, player).infected == true
end



local function sameFaction(player, model)
    if not Config.autoFaction then return nil end
    local mineInfected = isInfected(LocalPlayer.Character, LocalPlayer)
    local targetInfected = isInfected(model, player)
    if mineInfected ~= targetInfected then return false end

    if mineInfected then return true end

    local myTeam = LocalPlayer.Team and LocalPlayer.Team.Name or ""
    local targetTeam = player and player.Team and player.Team.Name or ""
    if myTeam ~= "" and targetTeam ~= "" then
        return myTeam == targetTeam
    end
    return true
end

local function distanceTo(part)
    local myRoot = getRoot(LocalPlayer.Character)
    if not myRoot or not part then return nil end
    return math.floor((myRoot.Position - part.Position).Magnitude)
end

local function clearMark(key)
    local record = Marks[key]
    if not record then return end
    if record.highlight then pcall(function() record.highlight:Destroy() end) end
    if record.billboard then pcall(function() record.billboard:Destroy() end) end
    Marks[key] = nil
end

local function markObject(key, object, title, color, model, detail, style)
    if not key or not key.Parent or not object or not object.Parent then return end
    local part = getRoot(object)
    if not part then return end
    style = style or {}

    local record = Marks[key]
    if not record then
        record = {}
        Marks[key] = record
    end

    if not record.highlight or not record.highlight.Parent then
        record.highlight = Instance.new("Highlight")
        record.highlight.Name = "ANHub_V5_ESP"
        record.highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        record.highlight.Parent = Workspace
    end
    record.highlight.Adornee = object
    record.highlight.FillColor = color
    record.highlight.OutlineColor = style.outlineColor or color
    record.highlight.FillTransparency = style.fillTransparency == nil and 0.86 or style.fillTransparency
    record.highlight.OutlineTransparency = style.outlineTransparency == nil and 0 or style.outlineTransparency

    if Config.names then
        if not record.billboard or not record.billboard.Parent then
            record.billboard = Instance.new("BillboardGui")
            record.billboard.Name = "ANHub_V5_Tag"
            record.billboard.AlwaysOnTop = true
            record.billboard.LightInfluence = 0
            record.billboard.Parent = PlayerGui

            record.label = Instance.new("TextLabel")
            record.label.Name = "ANHub_V5_Label"
            record.label.BackgroundTransparency = 1
            record.label.Size = UDim2.fromScale(1, 1)
            record.label.Font = Enum.Font.GothamBold
            record.label.TextWrapped = true
            record.label.Parent = record.billboard
        end

        record.billboard.Size = style.billboardSize or UDim2.fromOffset(310, 76)
        record.billboard.StudsOffset = style.studsOffset or Vector3.new(0, 3.5, 0)
        record.billboard.Adornee = part
        local dist = distanceTo(part)
        local humanoid = model and getHumanoid(model)
        local hp = humanoid and string.format(
            " | 生命 %d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)
        ) or ""
        record.label.TextSize = style.textSize or 13
        record.label.TextStrokeColor3 = style.strokeColor or Color3.new(0.04, 0.04, 0.04)
        record.label.TextStrokeTransparency = style.strokeTransparency == nil and 0.1 or style.strokeTransparency
        record.label.Text = title .. (dist and (" | 距离 " .. dist) or "") .. hp
            .. (detail and ("\n" .. detail) or "")
        record.label.TextColor3 = style.textColor or color
    elseif record.billboard then
        pcall(function() record.billboard:Destroy() end)
        record.billboard = nil
        record.label = nil
    end
end

local function clearInactive(active)
    local processed = 0
    for key in pairs(Marks) do
        if not active[key] or not key.Parent then
            clearMark(key)
        end
        processed += 1
        if processed % 160 == 0 then task.wait() end
    end
end

local function captureMovement()
    local humanoid = getHumanoid(LocalPlayer.Character)
    if not humanoid then return end
    BaseMovement.walkSpeed = humanoid.WalkSpeed
    BaseMovement.jumpPower = humanoid.JumpPower
    BaseMovement.jumpHeight = humanoid.JumpHeight
    BaseMovement.useJumpPower = humanoid.UseJumpPower
end

local function applySpeed()
    local humanoid = getHumanoid(LocalPlayer.Character)
    if humanoid then
        humanoid.WalkSpeed = Config.speedEnabled and Config.speed or (BaseMovement.walkSpeed or 16)
    end
end

local function applyJump()
    local humanoid = getHumanoid(LocalPlayer.Character)
    if not humanoid then return end
    if Config.jumpEnabled then
        humanoid.UseJumpPower = true
        humanoid.JumpPower = Config.jump
    else
        humanoid.UseJumpPower = BaseMovement.useJumpPower == nil and true or BaseMovement.useJumpPower
        humanoid.JumpPower = BaseMovement.jumpPower or 50
        humanoid.JumpHeight = BaseMovement.jumpHeight or 7.2
    end
end

local function setFullBright(enabled)
    Config.fullBright = enabled
    if enabled then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(190, 190, 190)
        Lighting.OutdoorAmbient = Color3.fromRGB(190, 190, 190)
        Lighting.GlobalShadows = false
    else
        Lighting.Brightness = Original.brightness
        Lighting.ClockTime = Original.clockTime
        Lighting.Ambient = Original.ambient
        Lighting.OutdoorAmbient = Original.outdoorAmbient
        Lighting.GlobalShadows = Original.globalShadows
    end
end

local function setNoFog(enabled)
    Config.noFog = enabled
    if enabled then
        Lighting.FogStart = 0
        Lighting.FogEnd = 1000000
    else
        Lighting.FogStart = Original.fogStart
        Lighting.FogEnd = Original.fogEnd
    end
end

local function scanPlayers(active)
    local total, friends, foes = 0, 0, 0
    if not (Config.playerESP or Config.infectionESP) then return total, friends, foes end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character and player.Character.Parent and getRoot(player.Character) then
            local model = player.Character
            total += 1
            active[model] = true
            local faction = sameFaction(player, model)
            local color, role
            if faction == nil then
                color = player.TeamColor and player.TeamColor.Color or Color3.fromRGB(90, 170, 255)
                role = "[玩家]"
            elseif faction then
                color = Color3.fromRGB(65, 200, 255)
                role = "[友方]"
                friends += 1
            else
                color = Color3.fromRGB(255, 65, 65)
                role = "[敌人]"
                foes += 1
            end
            local info = Config.infectionESP and getInfectionInfo(model, player) or nil
            -- 与 V4 一致：只开感染透视时，仅显示可确认感染/正在感染的人。
            local relevant = info and (info.infected or info.status == "感染中")
            if Config.playerESP or relevant then
                if info and (info.infected or info.status == "感染中") then
                    color = info.color
                    if info.infected and faction ~= nil then
                        role = faction and "[感染友方]" or "[感染敌人]"
                    end
                end
                markObject(model, model, role .. " " .. player.DisplayName, color, model,
                    info and info.text or nil,
                    {billboardSize = UDim2.fromOffset(480, 116), textSize = 13})
            else
                active[model] = nil
                clearMark(model)
            end
        end
    end
    return total, friends, foes
end

local function scanEnemyNPCs(active)
    local folder = Workspace:FindFirstChild("Enemy")
    local count = 0
    if not folder or not Config.enemyESP then return count end

    walkDescendants(folder, function(model)
        if model:IsA("Model") and model ~= LocalPlayer.Character and getRoot(model) then
            local humanoid = getHumanoid(model)
            if not humanoid or humanoid.Health > 0 then
                count += 1
                active[model] = true
                local attacking = model:FindFirstChild("Attacking", true)
                local suffix = attacking and attacking:IsA("BoolValue") and attacking.Value and " [攻击中]" or ""
                local info = Config.infectionESP and getInfectionInfo(model, nil) or nil
                local role = info and info.infected and "[感染 NPC] " or "[敌人 NPC] "
                markObject(model, model, role .. model.Name .. suffix,
                    info and info.infected and info.color or Color3.fromRGB(255, 75, 75),
                    model, info and info.text or nil,
                    {billboardSize = UDim2.fromOffset(480, 116), textSize = 13})
            end
        end
    end, false)
    return count
end

local function getMap()
    return Workspace:FindFirstChild("Map")
end

local function isInsideCharacter(object)
    local ancestor = object and object.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") and ancestor:FindFirstChildOfClass("Humanoid") then
            return true
        end
        ancestor = ancestor.Parent
    end
    return false
end

local function hasValuableLootAncestor(object)
    local ancestor = object and object.Parent
    while ancestor and ancestor ~= Workspace do
        if ancestor:IsA("Model") or ancestor:IsA("Tool") then
            local _, tier = classifyItemObject(ancestor)
            if tier >= 2 then return true end
        end
        ancestor = ancestor.Parent
    end
    return false
end

local QuickValuableTokens = {
    "sample", "specimen", "blood", "tissue", "virus", "serum", "research",
    "keycard", "accesscard", "medkit", "firstaid", "antidote", "syringe",
    "powercell", "energycell", "battery", "fuse", "ammo", "fuelcan", "artifact",
    "relic", "crystal", "rare", "样本", "标本", "血液", "组织", "病毒", "血清",
    "研究", "门禁", "急救", "解毒", "注射器", "电池", "保险丝", "弹药", "燃料",
    "遗物", "晶体", "稀有",
}

local function mightBeValuableObject(object)
    local normalized = normalizeItemName(object.Name)
    for _, token in ipairs(QuickValuableTokens) do
        if string.find(normalized, token, 1, true) then
            return true
        end
    end
    -- 少数游戏版本把中文显示名放在属性里、实例名却是 Model；只对 Model 检查属性。
    if object:IsA("Model") then
        for _, attributeName in ipairs({"DisplayNameCN", "ChineseName", "LocalizedName", "DisplayName", "ItemName"}) do
            local value = object:GetAttribute(attributeName)
            if typeof(value) == "string" and value ~= "" then
                local attrName = normalizeItemName(value)
                for _, token in ipairs(QuickValuableTokens) do
                    if string.find(attrName, token, 1, true) then
                        return true
                    end
                end
            end
        end
    end
    return false
end

local function scanLoot(active, map)
    local count, sampleCount, valuableCount = 0, 0, 0
    if not Config.lootESP then return count, sampleCount, valuableCount end

    local roots = {}
    if map then table.insert(roots, map) end
    -- 兼容掉落物不在 Map 下面的版本，同时排除角色/NPC/尸体容器。
    for _, child in ipairs(Workspace:GetChildren()) do
        local playerCharacter = child:IsA("Model") and Players:GetPlayerFromCharacter(child) ~= nil
        if child ~= map and child ~= LocalPlayer.Character and not playerCharacter
            and child.Name ~= "Enemy" and child.Name ~= "Corpse" then
            table.insert(roots, child)
        end
    end

    local candidates = {}
    local visited = {}
    local myRoot = getRoot(LocalPlayer.Character)

    local function consider(object)
        if not object or visited[object] then return end
        visited[object] = true
        local isTool = object:IsA("Tool")
        local isValuableContainer = (object:IsA("Model") or object:IsA("BasePart"))
            and mightBeValuableObject(object)
        if not isTool and not isValuableContainer then return end
        if isInsideCharacter(object) then return end

        local label, tier = classifyItemObject(object)
        if isTool then
            if hasValuableLootAncestor(object) then return end
        else
            if tier < 2 or hasValuableLootAncestor(object) then return end
        end

        local part = getRoot(object)
        if not part then return end
        local distance = myRoot and (myRoot.Position - part.Position).Magnitude or math.huge
        table.insert(candidates, {
            object = object,
            label = label,
            tier = tier,
            distance = distance,
        })
    end

    for _, root in ipairs(roots) do
        walkDescendants(root, consider, true)
    end

    -- 样本/高价值优先，其余物资优先显示离玩家较近的，避免一张地图创建数百上千个 GUI。
    table.sort(candidates, function(a, b)
        if a.tier ~= b.tier then return a.tier > b.tier end
        return a.distance < b.distance
    end)

    local marked = 0
    for _, item in ipairs(candidates) do
        if item.tier >= 3 or marked < MAX_LOOT_MARKS then
            local object = item.object
            if object and object.Parent then
                count += 1
                marked += 1
                active[object] = true
                if item.tier >= 3 then sampleCount += 1 end
                if item.tier >= 2 then valuableCount += 1 end

                local prefix, color, style = getItemStyle(item.tier)
                local title = prefix .. " " .. item.label
                if item.tier >= 3 then
                    title = "★★★ 高价值样本 ★★★\n" .. item.label
                end
                markObject(object, object, title, color, nil, nil, style)
                if marked % 24 == 0 then task.wait() end
            end
        end
    end
    return count, sampleCount, valuableCount
end
-- 透视箱内物品：优先读取物品实例、字符串值与显式属性，不把网格、把手等装饰猜成物资。
local ContainerContentFolders = {
    Items = true, Item = true, Contents = true, Content = true,
    Inventory = true, Loot = true, Rewards = true, StoredItems = true,
}
local ContentKeys = {
    ItemName = true, ItemID = true, ItemId = true, ItemType = true,
    StoredItem = true, ContainedItem = true, Loot = true, LootItem = true,
    Reward = true, Content = true, Contents = true,
}
local ContainerMetadataKeys = {
    "ItemName", "ItemID", "ItemId", "ContainedItem", "StoredItem",
    "LootItem", "Loot", "Contents", "Content", "Reward",
}

local function getContainerLabel(object)
    local known = StorageNames[object.Name]
    if known then return known end
    local lower = object.Name:lower()
    local parts = {
        {"locker", "储物柜"}, {"crate", "物资箱"}, {"supplybox", "补给箱"},
        {"lootbox", "物资箱"}, {"chest", "宝箱"}, {"drawer", "抽屉"},
        {"container", "储物箱"}, {"cabinet", "柜子"}, {"shelf", "货架"},
        {"storagebox", "储物箱"}, {"箱子", "箱子"}, {"柜子", "柜子"},
    }
    for _, pair in ipairs(parts) do
        if lower:find(pair[1], 1, true) then return pair[2] end
    end
    return nil
end

local function getContainerContents(container)
    local found, ordered, inspected = {}, {}, 0
    local function addRaw(raw)
        if typeof(raw) ~= "string" and typeof(raw) ~= "number" then return end
        local name = tostring(raw):gsub("^%s+", ""):gsub("%s+$", "")
        local lower = name:lower()
        if name == "" or lower == "nil" or lower == "none" or lower == "empty"
            or lower == "null" or name == "无" or name == "空" or name == "0" then return end
        if #name > 65 or name:match("^%d+$") then return end
        local label, tier = classifyItemName(name)
        if not label then
            local fallback = fallbackChineseLabel(name)
            label = fallback ~= "普通物资" and fallback or name
        end
        if not found[label] then
            found[label] = 1
            table.insert(ordered, {name = label, tier = tier})
        else
            found[label] += 1
        end
    end
    local function readAttributes(object)
        for _, key in ipairs(ContainerMetadataKeys) do
            local value = object:GetAttribute(key)
            if typeof(value) == "string" then
                -- 部分箱子将一组物品以逗号、分号或竖线连接存储。
                for piece in value:gmatch("[^,;|]+") do addRaw(piece) end
            end
        end
    end

    readAttributes(container)
    local stack = {{obj = container, depth = 0, inventory = false}}
    while #stack > 0 and inspected < 220 do
        local entry = table.remove(stack)
        local obj, depth = entry.obj, entry.depth
        inspected += 1
        if depth > 0 then
            local inInventory = entry.inventory
            if obj:IsA("Tool") then
                addRaw(obj:GetAttribute("ItemName") or obj.Name)
            elseif obj:IsA("ValueBase") and ContentKeys[obj.Name] then
                if obj:IsA("ObjectValue") then
                    if obj.Value then addRaw(obj.Value:GetAttribute("ItemName") or obj.Value.Name) end
                elseif obj:IsA("StringValue") then
                    addRaw(obj.Value)
                end
            elseif inInventory and (obj:IsA("Model") or obj:IsA("Folder")) then
                local _, tier = classifyItemName(obj.Name)
                if tier > 0 or (depth <= 3 and not ContainerContentFolders[obj.Name]) then
                    addRaw(obj:GetAttribute("ItemName") or obj.Name)
                end
            elseif obj:IsA("Model") then
                local _, tier = classifyItemName(obj.Name)
                if tier >= 1 then addRaw(obj.Name) end
            end
            if obj:IsA("Model") or obj:IsA("Folder") or obj:IsA("BasePart") then
                readAttributes(obj)
            end
        end
        if depth < 5 and not obj:IsA("Tool") then
            local children = obj:GetChildren()
            for _, child in ipairs(children) do
                table.insert(stack, {
                    obj = child, depth = depth + 1,
                    inventory = entry.inventory or ContainerContentFolders[obj.Name] == true,
                })
            end
        end
    end
    table.sort(ordered, function(a, b)
        return a.tier > b.tier or (a.tier == b.tier and a.name < b.name)
    end)
    local textParts = {}
    for i = 1, math.min(5, #ordered) do
        local item = ordered[i]
        table.insert(textParts, item.name .. (found[item.name] > 1 and (" ×" .. found[item.name]) or ""))
    end
    if #ordered > 5 then table.insert(textParts, "+" .. (#ordered - 5) .. " 种") end
    if #textParts > 0 then
        return "箱内：" .. table.concat(textParts, "、"), true
    end
    for _, emptyKey in ipairs({"Empty", "IsEmpty", "Looted"}) do
        if container:GetAttribute(emptyKey) == true then return "箱内：空（状态已同步）", true end
    end
    return "箱内：未知（客户端未同步内容）", false
end

local function scanStorage(active, map)
    local count, readable = 0, 0
    StorageDiagnostics = {}
    if not Config.storageESP or not map then return count, readable end
    local seen = {}
    local function consider(object)
        if count >= MAX_CONTAINER_MARKS or seen[object] then return end
        seen[object] = true
        if not (object:IsA("Model") or object:IsA("BasePart")) then return end
        local containerLabel = getContainerLabel(object)
        if not containerLabel or not getRoot(object) then return end
        count += 1
        active[object] = true
        local detail, known = "", false
        if Config.containerContentsESP then
            detail, known = getContainerContents(object)
        end
        if known then readable += 1 end
        local color = known and Color3.fromRGB(85, 235, 155) or Color3.fromRGB(130, 195, 245)
        markObject(object, object, "[箱子] " .. containerLabel, color, nil,
            Config.containerContentsESP and detail or nil,
            {billboardSize = UDim2.fromOffset(430, 90), textSize = 14})
        if #StorageDiagnostics < 12 then
            table.insert(StorageDiagnostics, object:GetFullName() .. " | " .. (detail ~= "" and detail or "箱内显示关闭"))
        end
    end

    -- 此游戏已知结构：Workspace.Map.<房间>.Item.<柜/箱>。
    -- 顺便兼容嵌套一两级的箱子，避免再全量遍历大型地图造成卡顿。
    for _, room in ipairs(map:GetChildren()) do
        if count >= MAX_CONTAINER_MARKS then break end
        for _, folderName in ipairs({"Item", "Items", "Storage", "Loot"}) do
            local folder = room:FindFirstChild(folderName)
            if folder then
                for _, object in ipairs(folder:GetChildren()) do
                    consider(object)
                    if not getContainerLabel(object) then
                        for _, nested in ipairs(object:GetChildren()) do consider(nested) end
                    end
                end
            end
        end
    end
    return count, readable
end

local function scanGates(active, map)
    local count = 0
    if not Config.gateESP or not map then return count end
    for _, room in ipairs(map:GetChildren()) do
        if room:IsA("Model") then
            local gate = room:FindFirstChild("Gate")
            if gate and gate:IsA("Model") and getRoot(gate) then
                count += 1
                active[gate] = true
                markObject(gate, gate, "[门禁] " .. room.Name, Color3.fromRGB(255, 150, 60), nil, nil)
            else
                local gateFolder = room:FindFirstChild("_GATE_")
                if gateFolder then
                    for _, object in ipairs(gateFolder:GetChildren()) do
                        if (object:IsA("Model") or object:IsA("BasePart"))
                            and getRoot(object)
                            and (object.Name == "Door1" or object.Name == "Door1A"
                                or object.Name == "Base" or object.Name == "Trigger") then
                            count += 1
                            active[object] = true
                            markObject(object, object, "[门禁] " .. room.Name .. " / " .. object.Name,
                                Color3.fromRGB(255, 150, 60), nil, nil)
                        end
                    end
                end
            end
        end
    end
    return count
end

local function scanSpawns(active, map)
    local count = 0
    if not Config.spawnESP or not map then return count end
    for _, room in ipairs(map:GetChildren()) do
        if room:IsA("Model") then
            local folder = room:FindFirstChild("SP_Latex")
            if folder then
                walkDescendants(folder, function(object)
                    if object:IsA("BasePart") then
                        count += 1
                        active[object] = true
                        markObject(object, object, "[胶兽刷新点]", Color3.fromRGB(210, 110, 255), nil, nil)
                    end
                end, false)
            end
        end
    end
    return count
end

local function scanCorpses(active)
    local count = 0
    if not Config.corpseESP then return count end
    local folder = Workspace:FindFirstChild("Corpse")
    if not folder then return count end
    for _, model in ipairs(folder:GetChildren()) do
        if model:IsA("Model") and getRoot(model) then
            count += 1
            active[model] = true
            markObject(model, model, "[尸体] " .. model.Name, Color3.fromRGB(180, 180, 180), model, nil)
        end
    end
    return count
end

local function scanInteract(active, map)
    local count = 0
    if not Config.interactESP or not map then return count end
    walkDescendants(map, function(object)
        if object:IsA("ProximityPrompt") or object:IsA("ClickDetector") then
            local parent = object.Parent
            if parent and (parent:IsA("BasePart") or parent:IsA("Model")) and getRoot(parent) then
                count += 1
                active[parent] = true
                markObject(parent, parent, "[交互点] " .. parent.Name, Color3.fromRGB(100, 230, 230), nil, nil)
            end
        end
    end, false)
    return count
end

-- === 隐蔽感染：不改本地感染值；只尝试触发游戏原生的接触/咬伤流程 ===
-- 没有任何检查能保证绝对无人观察（观战、其他透视、玩家加入、服务器重放等）。
local Isolation = {
    queue = nil, active = false, selected = nil, origin = nil,
    character = nil, startedAt = 0, infectedAt = nil, elapsed = 0, checkElapsed = 0,
    nearest = nil, startHazard = nil, status = "尚未扫描",
}
local isolationStatusParagraph = nil
local function isolationStatus(message)
    Isolation.status = message
    if isolationStatusParagraph then
        pcall(function() isolationStatusParagraph:SetDesc(message) end)
    end
end
local function npcType(model)
    local v = getValue(model, "LType")
    return typeof(v) == "string" and v or "未知类型"
end
local function isBenignType(typename)
    return string.find(string.lower(typename), "benign", 1, true) ~= nil
end
local function getNpcCandidate(model)
    if not model or not model:IsA("Model") or not model:IsDescendantOf(Workspace) then return nil end
    local humanoid = getHumanoid(model)
    local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
    if not humanoid or humanoid.Health <= 0 or not root then return nil end
    if getValue(model, "Infected") ~= true then return nil end
    if getValue(model, "Awaken") == true then return nil end
    return {model=model, root=root, type=npcType(model), position=root.Position}
end
local function isolationCheck(position, targetModel)
    local nearest = math.huge
    local unknown = 0
    local minDistance = Config.isolationRadius
    local losParameters = RaycastParams.new()
    losParameters.FilterType = Enum.RaycastFilterType.Exclude
    losParameters.IgnoreWater = true
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local character = player.Character
            local head = character and (character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart"))
            if not head then
                unknown += 1 -- 位置未同步的玩家无法判定是否正在观察，保守拒绝
            else
                local distance = (head.Position - position).Magnitude
                nearest = math.min(nearest, distance)
                if distance < minDistance then return false, nearest, "附近有其他玩家" end
                if distance <= 650 then
                    losParameters.FilterDescendantsInstances = {character, targetModel, LocalPlayer.Character}
                    local direction = position - head.Position
                    local hit = Workspace:Raycast(head.Position, direction, losParameters)
                    if not hit then return false, nearest, "其他玩家存在无遮挡视线" end
                end
            end
        end
    end
    if unknown > 0 then return false, nearest, "有" .. unknown .. "名玩家位置未知" end
    return true, nearest, "已通过距离和视线检测（非绝对隐身）"
end
local function findIsolationTarget(benignOnly)
    local folder = Workspace:FindFirstChild("Enemy")
    if not folder then return nil, "当前未加载敌对 NPC 目录", 0, 0 end
    local eligible, safeCount, best, bestScore = 0, 0, nil, -math.huge
    local inspected = 0
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and obj:FindFirstChildOfClass("Humanoid") then
            inspected += 1
            if inspected > 180 then break end
            local candidate = getNpcCandidate(obj)
            if candidate and (not benignOnly or isBenignType(candidate.type)) then
                eligible += 1
                local ok, nearest = isolationCheck(candidate.position, candidate.model)
                if ok then
                    safeCount += 1
                    candidate.nearest = nearest
                    local value = math.min(nearest, 2000) + (isBenignType(candidate.type) and 20000 or 0)
                    if value > bestScore then best, bestScore = candidate, value end
                end
            end
        end
    end
    return best, nil, eligible, safeCount
end
local function getArrivalPosition(candidate)
    local exclude = RaycastParams.new()
    exclude.FilterType = Enum.RaycastFilterType.Exclude
    exclude.IgnoreWater = true
    exclude.FilterDescendantsInstances = {candidate.model, LocalPlayer.Character}
    for i = 1, 12 do
        local angle = i * (math.pi * 2 / 12)
        local offset = Vector3.new(math.cos(angle) * 3.2, 0, math.sin(angle) * 3.2)
        local sample = candidate.position + offset
        local hit = Workspace:Raycast(sample + Vector3.new(0,7,0), Vector3.new(0,-18,0), exclude)
        if hit and hit.Instance.CanCollide and hit.Normal.Y >= 0.7 then
            local arrival = hit.Position + Vector3.new(0,3.3,0)
            if math.abs(arrival.Y - candidate.position.Y) <= 5.5 then
                local safe = isolationCheck(arrival, candidate.model)
                if safe then return CFrame.lookAt(arrival, Vector3.new(candidate.position.X,arrival.Y,candidate.position.Z)) end
            end
        end
    end
    return nil
end
local function stopIsolation(restore, reason)
    Isolation.queue = nil
    local original, oldChar = Isolation.origin, Isolation.character
    Isolation.active, Isolation.selected, Isolation.origin, Isolation.character = false, nil, nil, nil
    if restore and original and oldChar == LocalPlayer.Character then
        local root = getRoot(oldChar)
        if root then
            pcall(function()
                oldChar:PivotTo(original)
                root.AssemblyLinearVelocity = Vector3.zero
            end)
        end
    end
    isolationStatus(reason or "已停止")
end
local function startIsolation(candidate)
    if Isolation.active then return false, "已有感染任务在运行" end
    if Config.halfInfectionLock then
        return false, "请先关闭本地半感染锁定实验，避免虚假觉醒结果"
    end
    local char = LocalPlayer.Character
    local root = getRoot(char)
    local humanoid = getHumanoid(char)
    if not root or not humanoid or humanoid.Health <= 0 then return false, "角色无效" end
    if LocalPlayer.Team and LocalPlayer.Team.Name:lower():find("infect", 1, true) then
        return false, "当前已经在感染阵营"
    end
    local ok, nearest, reason = isolationCheck(candidate.root.Position, candidate.model)
    if not ok then return false, reason end
    local arrival = getArrivalPosition(candidate)
    if not arrival then return false, "没有安全落脚点或 NPC 已移动" end
    Isolation.origin = char:GetPivot()
    Isolation.character = char
    Isolation.selected = candidate.model
    Isolation.nearest = nearest
    Isolation.active = true
    Isolation.startedAt = os.clock()
    Isolation.startHazard = tonumber(getValue(char, "Hazard")) or 0
    Isolation.infectedAt = nil
    Isolation.queue = nil
    local teleported, err = pcall(function()
        char:PivotTo(arrival)
        root.AssemblyLinearVelocity = Vector3.zero
    end)
    if not teleported then stopIsolation(false, "传送失败：" .. tostring(err)); return false, tostring(err) end
    isolationStatus(string.format("已抵达 %s（其他玩家最近 %.0f studs）；等待 NPC 自行咬伤。无必觉醒保证。",
        candidate.type, math.min(nearest, 99999)))
    return true
end
local function scanIsolationAndMaybeStart(mode, start)
    local benignOnly = mode == "benign"
    local target, err, count, safe = findIsolationTarget(benignOnly)
    if not target then
        local msg = string.format("%s：发现 %d 只目标，合格 %d 只；%s。",
            benignOnly and "Benign 模式" or "普通感染模式", count or 0, safe or 0,
            err or "附近有玩家、无遮挡视线或无法同步位置")
        isolationStatus(msg)
        return false
    end
    if not start then
        isolationStatus(string.format("找到孤立 %s，最近其他玩家约 %.0f studs。", target.type, math.min(target.nearest, 99999)))
        return true
    end
    local ok, reason = startIsolation(target)
    if not ok then isolationStatus("未传送：" .. tostring(reason)) end
    return ok
end
local function isolationWatch(dt)
    Isolation.elapsed += dt
    if Isolation.elapsed < 1.2 then return end
    Isolation.elapsed = 0
    if Isolation.active then
        if Isolation.character ~= LocalPlayer.Character then stopIsolation(false,"角色已切换，监控结束"); return end
        local selected = Isolation.selected
        local candidate = getNpcCandidate(selected)
        local character = LocalPlayer.Character
        local root = getRoot(character)
        local humanoid = getHumanoid(character)
        if not root or not humanoid or humanoid.Health <= 0 then
            stopIsolation(false,"角色死亡或无法控制"); return
        end
        local awaken = getValue(character,"Awaken")
        local infected = getValue(character,"Infected")
        if infected == true or (LocalPlayer.Team and LocalPlayer.Team.Name:lower():find("infect",1,true)) then
            Isolation.infectedAt = Isolation.infectedAt or os.clock()
            if awaken == true then
                stopIsolation(false, "已感染并同步觉醒标志！请确认服务器的角色状态。"); return
            elseif os.clock() - Isolation.infectedAt >= 3 then
                stopIsolation(false, "已感染，但服务器未同步觉醒。普通胶兽不能保证觉醒。"); return
            else
                isolationStatus("已发生感染，等待服务器同步 Awaken 结果…")
                return
            end
        end
        if not candidate then stopIsolation(Config.isolationRetreat,"NPC 已消失，停止等待"); return end
        local safe, nearest, message = isolationCheck(candidate.root.Position, selected)
        if not safe then
            stopIsolation(Config.isolationRetreat,"有其他玩家靠近或可观察，" .. (Config.isolationRetreat and "已尝试撤离" or "已停止") .. "：" .. message)
            return
        end
        if os.clock() - Isolation.startedAt >= 2.8 and (root.Position - candidate.root.Position).Magnitude > 28 then
            stopIsolation(false,"传送位置没有保持：服务器可能回弹或 NPC 已走开")
            return
        end
        local hazard=tonumber(getValue(character,"Hazard"))
        local poison = getValue(character,"Poisoned")
        local bitten = getValue(character,"Bitten")
        isolationStatus(string.format("等待 %s 造成感染 | Hazard %s/100 | 被咬 %s | 中毒 %s | 其他玩家最近 %.0f studs | %ds",
            candidate.type, hazard and tostring(hazard) or "?", tostring(bitten or "?"), tostring(poison==true), math.min(nearest,99999), os.clock()-Isolation.startedAt))
    elseif Isolation.queue then
        Isolation.checkElapsed += 1.2
        if Isolation.checkElapsed >= 4.8 then
            Isolation.checkElapsed = 0
            scanIsolationAndMaybeStart(Isolation.queue,true)
        end
    end
end

local overviewParagraph = Tabs.overview:Paragraph({
    Title = "ANHub V5.6 · 箱内透视、感染进度、隐蔽感染",
    Desc = "正在初始化玩家、物资和地图扫描…"
})

Tabs.overview:Divider()
Tabs.overview:Paragraph({
    Title = "物资优先级",
    Desc = "样本使用最醒目的高亮；门禁卡、急救包、电池、解毒剂等重要物资使用第二级高亮。场上没有的物品不会生成标记。"
})

Tabs.overview:Button({
    Title = "一键恢复本地设置",
    Desc = "恢复 FOV、光照、雾效、移动速度与跳跃，并关闭自我旋转",
    Callback = function()
        Config.fovEnabled = false
        Config.speedEnabled = false
        Config.jumpEnabled = false
        Config.spinEnabled = false
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.FieldOfView = Original.fov
        end
        setFullBright(false)
        setNoFog(false)
        applySpeed()
        applyJump()
        ANUI:Notify({Title = "已恢复", Content = "本地画面和移动参数已恢复。", Icon = "check", Duration = 3})
    end
})

local function addToggle(tab, title, desc, key, default)
    tab:Toggle({
        Title = title,
        Desc = desc,
        Value = default,
        Callback = function(value)
            Config[key] = value
        end
    })
end

-- 这里只移动玩家角色到真实胶兽附近，感染过程由服务器原生游戏逻辑处理。
isolationStatusParagraph = Tabs.isolate:Paragraph({
    Title = "落单胶兽 · 服务器感染实验",
    Desc = "尚未扫描。其他玩家距离需达阈值，近处还需被墙体遮挡；无法保证绝对不被观战或透视。"
})
Tabs.isolate:Slider({
    Title = "最小玩家隔离距离（studs）",
    Desc = "200～600；越大越难找到目标，建议 250 以上",
    Value = {Min=200,Max=600,Default=250}, Step=25,
    Callback=function(value) Config.isolationRadius=tonumber(value) or 250 end
})
Config.isolationRadius = 250
addToggle(Tabs.isolate, "发现其他玩家后自动撤离", "如果其他玩家接近或有直视路径，尝试返回原位置", "isolationRetreat", true)
Tabs.isolate:Button({
    Title = "扫描偏僻胶兽（不传送）",
    Desc = "只显示是否有合格感染 NPC，不改变游戏状态",
    Callback = function() scanIsolationAndMaybeStart("normal", false) end
})
Tabs.isolate:Button({
    Title = "寻找普通落单胶兽并感染",
    Desc = "没有安全目标就每 5 秒重试；普通感染为概率觉醒，不能保底",
    Callback = function()
        stopIsolation(false, "等待新的落单胶兽")
        Isolation.queue="normal"
        scanIsolationAndMaybeStart("normal",true)
    end
})
Tabs.isolate:Button({
    Title = "只寻找 Benign（保底觉醒式状态）",
    Desc = "只接受游戏实际复制的 Benign 敌人；找不到就等待，不会冒充普通必觉醒",
    Callback = function()
        stopIsolation(false, "正在等待 Benign")
        Isolation.queue="benign"
        scanIsolationAndMaybeStart("benign",true)
    end
})
Tabs.isolate:Button({
    Title = "停止搜索 / 撤离",
    Desc = "结束任务；若已传送，尝试回到原位置（不撤销已感染状态）",
    Callback = function() stopIsolation(true, "已停止并尝试回到起点") end
})
Tabs.isolate:Paragraph({
    Title="关于觉醒概率",
    Desc="普通胶兽被咬不会必觉醒。Wiki 记载 Benign 与 Hardcore 为保证觉醒式感染，但不计作普通 Rising Up 觉醒；想保证普通觉醒需满足徽章后使用样本机器。"
})

addToggle(Tabs.esp, "玩家全图透视", "显示其他玩家轮廓、名字、距离与生命值", "playerESP", true)
addToggle(Tabs.esp, "敌人透视", "标记敌对非玩家角色", "enemyESP", true)
addToggle(Tabs.esp, "自动分类友方 / 敌人", "结合队伍和当前阵营自动区分目标", "autoFaction", true)
addToggle(Tabs.esp, "名称标签", "显示目标名字、距离、血量和详细信息", "names", true)
addToggle(Tabs.esp, "掉落物 / 工具透视", "标记地面可拾取物资，并突出样本和重要物品", "lootESP", true)
addToggle(Tabs.esp, "箱子透视", "标记储物柜、物资箱、抽屉等", "storageESP", true)
addToggle(Tabs.esp, "箱内物品名称", "显示客户端已同步的箱内真实物品；没同步就显示未知", "containerContentsESP", true)
addToggle(Tabs.esp, "玩家感染 / 觉醒与进度", "参考 V4：Hazard、PoisonStage、Bitten、Awaken、LType；无法读取时再标注估算", "infectionESP", true)
addToggle(Tabs.esp, "感染进度算法估算", "基于已观测的变化速率或感染开始时刻估算；不是服务器真实值", "infectionEstimate", true)
Tabs.esp:Slider({
    Title = "估算感染全程时长（秒）",
    Desc = "30–300 秒；没有真实速率时仅用作低可信的计时假设",
    Value = {Min = 30, Max = 300, Default = 120},
    Step = 10,
    Callback = function(value)
        Config.infectionAssumedSeconds = math.clamp(tonumber(value) or 120, 30, 300)
    end
})
addToggle(Tabs.esp, "门禁 / 出入口透视", "标记门禁、门和出入口模型", "gateESP", true)
addToggle(Tabs.esp, "胶兽刷新点透视", "标记房间中的胶兽刷新位置", "spawnESP", false)
addToggle(Tabs.esp, "尸体透视", "标记地图中已生成的尸体模型", "corpseESP", true)
addToggle(Tabs.esp, "交互点 ESP", "标记 ProximityPrompt / ClickDetector", "interactESP", false)

Tabs.esp:Toggle({
    Title = "半感染锁定（实验）",
    Desc = "打开后不会立刻变异；检测到之后的变异/感染状态变化时，尝试本地维持半感染参数。服务器可能覆盖，不保证其他玩家可见。",
    Value = false,
    Callback = function(value)
        Config.halfInfectionLock = value
        halfLockLatched = false
        refreshHalfLockWatcher(true)
        if value then
            ANUI:Notify({
                Title = "半感染锁定已待命",
                Content = "不会立即改变状态；检测到后续变异时才尝试本地锁定。",
                Icon = "shield",
                Duration = 4
            })
        else
            ANUI:Notify({
                Title = "半感染锁定已关闭",
                Content = "已停止本地锁定；不会主动恢复之前的感染值。",
                Icon = "shield-off",
                Duration = 3
            })
        end
    end
})

Tabs.map:Toggle({
    Title = "秒互动增强",
    Desc = "长按时间设为 0，并在按下提示对应按键时提供兜底触发；关闭后恢复原始设置。",
    Value = false,
    Callback = function(value)
        local promptCount = setInstantInteract(value)
        ANUI:Notify({
            Title = value and "秒互动增强已开启" or "秒互动增强已关闭",
            Content = value
                and (promptCount > 0 and string.format("已处理 %d 个交互提示；若原生触发无回执，将尝试兜底触发。", promptCount)
                    or "当前地图未发现 ProximityPrompt；此类交互可能使用自定义逻辑。")
                or "已恢复交互提示的原始设置。",
            Icon = "zap",
            Duration = 4
        })
    end
})



Tabs.map:Button({
    Title = "复制箱子侦测结果",
    Desc = "复制当前扫描到的箱体路径与内容状态，便于排查未同步的内容",
    Callback = function()
        local report = #StorageDiagnostics > 0 and table.concat(StorageDiagnostics, "\n") or "尚未扫描到箱子；请开启箱子透视并刷新。"
        if typeof(setclipboard) == "function" then
            setclipboard(report)
            ANUI:Notify({Title = "已复制箱子诊断", Content = "已复制 " .. #StorageDiagnostics .. " 条箱子记录", Icon = "clipboard", Duration = 3})
        else
            ANUI:Notify({Title = "剪贴板不可用", Content = "请查看运行器打印日志。", Icon = "info", Duration = 3})
            print("[ANHub 箱子诊断]\n" .. report)
        end
    end
})

Tabs.map:Paragraph({
    Title = "地图对象统计",
    Desc = "统计当前 Map 中的物资、储物点、门禁和胶兽刷新点。"
})

Tabs.map:Button({
    Title = "刷新物资统计",
    Desc = "扫描当前地图对象数量",
    Callback = function()
        local map = getMap()
        local tools, samples, valuable, storage, gates, spawns = 0, 0, 0, 0, 0, 0
        if map then
            walkDescendants(map, function(object)
                if object:IsA("Tool") then
                    tools += 1
                    local _, tier = classifyItemObject(object)
                    if tier >= 3 then samples += 1 end
                    if tier >= 2 then valuable += 1 end
                elseif (object:IsA("Model") or object:IsA("BasePart")) and mightBeValuableObject(object) then
                    local _, tier = classifyItemObject(object)
                    if tier >= 3 then samples += 1 end
                    if tier >= 2 then valuable += 1 end
                end
                if object:IsA("Model") and StorageNames[object.Name] then storage += 1 end
                if object.Name == "Gate" then gates += 1 end
                if object.Name == "SP_Latex" and object:IsA("Folder") then spawns += #object:GetChildren() end
            end, false)
        end
        ANUI:Notify({
            Title = "地图统计",
            Content = string.format("工具 %d · 高价值 %d · 样本 %d · 储物点 %d · 门禁 %d · 刷新点 %d",
                tools, valuable, samples, storage, gates, spawns),
            Icon = "package",
            Duration = 5
        })
    end
})

Tabs.visual:Toggle({
    Title = "全亮模式",
    Desc = "提高亮度并关闭全局阴影",
    Value = false,
    Callback = setFullBright
})

Tabs.visual:Toggle({
    Title = "移除雾效",
    Desc = "调整本地 Lighting 雾效范围",
    Value = false,
    Callback = setNoFog
})

Tabs.visual:Toggle({
    Title = "自定义 FOV",
    Desc = "启用后应用下方视野角度",
    Value = false,
    Callback = function(value)
        Config.fovEnabled = value
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.FieldOfView = value and Config.fov or Original.fov
        end
    end
})

Tabs.visual:Slider({
    Title = "视野角度",
    Desc = "60–120 度",
    Value = {Min = 60, Max = 120, Default = 80},
    Step = 1,
    Callback = function(value)
        Config.fov = tonumber(value) or 80
        if Config.fovEnabled and Workspace.CurrentCamera then
            Workspace.CurrentCamera.FieldOfView = Config.fov
        end
    end
})

Tabs.visual:Button({
    Title = "恢复初始 FOV",
    Desc = "恢复脚本启动前的相机视野",
    Callback = function()
        Config.fovEnabled = false
        if Workspace.CurrentCamera then
            Workspace.CurrentCamera.FieldOfView = Original.fov
        end
    end
})

Tabs.movement:Toggle({
    Title = "自定义移动速度",
    Desc = "本地 WalkSpeed，服务器可能覆盖",
    Value = false,
    Callback = function(value)
        Config.speedEnabled = value
        applySpeed()
    end
})

Tabs.movement:Slider({
    Title = "移动速度",
    Desc = "16–80",
    Value = {Min = 16, Max = 80, Default = 28},
    Step = 1,
    Callback = function(value)
        Config.speed = tonumber(value) or 28
        if Config.speedEnabled then applySpeed() end
    end
})

Tabs.movement:Toggle({
    Title = "跳跃增强",
    Desc = "启用下方 JumpPower",
    Value = false,
    Callback = function(value)
        Config.jumpEnabled = value
        applyJump()
    end
})

Tabs.movement:Slider({
    Title = "跳跃力度",
    Desc = "50–150",
    Value = {Min = 50, Max = 150, Default = 75},
    Step = 5,
    Callback = function(value)
        Config.jump = tonumber(value) or 75
        if Config.jumpEnabled then applyJump() end
    end
})

Tabs.movement:Toggle({
    Title = "自我旋转",
    Desc = "持续旋转角色，可能影响移动手感",
    Value = false,
    Callback = function(value)
        Config.spinEnabled = value
    end
})

Tabs.movement:Slider({
    Title = "旋转速度",
    Desc = "30–720 度/秒",
    Value = {Min = 30, Max = 720, Default = 240},
    Step = 30,
    Callback = function(value)
        Config.spinSpeed = tonumber(value) or 240
    end
})

local playerList = Tabs.players:Paragraph({
    Title = "玩家 / 感染列表",
    Desc = "刷新玩家阵营、感染度、毒阶段、被咬次数、觉醒状态和类型。"
})

local inventoryList = Tabs.players:Paragraph({
    Title = "当前背包",
    Desc = "点击按钮查看 Backpack 和角色手持工具。"
})

Tabs.players:Button({
    Title = "刷新玩家 / 感染列表",
    Desc = "显示感染状态、Hazard、PoisonStage、Bitten、Awaken、LType 与生命值",
    Callback = function()
        local rows = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local model = player.Character
                local faction = sameFaction(player, model)
                local role = faction == nil and "玩家" or (faction and "友方" or "敌人")
                local humanoid = getHumanoid(model)
                local hp = humanoid and string.format("%d/%d", math.floor(humanoid.Health), math.floor(humanoid.MaxHealth)) or "?/?"
                local infection = getInfectionInfo(model, player)
                table.insert(rows, string.format(
                    "%s (@%s) | %s | 队伍 %s | 生命 %s | %s",
                    player.DisplayName,
                    player.Name,
                    role,
                    player.Team and player.Team.Name or "无",
                    hp, infection.text
                ))
            end
        end
        table.sort(rows)
        playerList:SetTitle("玩家列表 · " .. #rows .. " 人")
        playerList:SetDesc(#rows > 0 and table.concat(rows, "\n") or "当前没有其他玩家。")
    end
})



Tabs.players:Button({
    Title = "刷新背包 / 手持工具",
    Desc = "显示角色和背包中的 Tool",
    Callback = function()
        local rows = {}
        local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
        if backpack then
            for _, object in ipairs(backpack:GetChildren()) do
                if object:IsA("Tool") then table.insert(rows, "背包 · " .. object.Name) end
            end
        end
        if LocalPlayer.Character then
            for _, object in ipairs(LocalPlayer.Character:GetChildren()) do
                if object:IsA("Tool") then table.insert(rows, "手持 · " .. object.Name) end
            end
        end
        inventoryList:SetTitle("当前工具 · " .. #rows .. " 件")
        inventoryList:SetDesc(#rows > 0 and table.concat(rows, "\n") or "当前没有检测到 Tool。")
    end
})

Tabs.players:Button({
    Title = "复制玩家列表",
    Desc = "执行器支持 setclipboard 时复制玩家阵营和队伍",
    Callback = function()
        local rows = {}
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer then
                local faction = sameFaction(player, player.Character)
                table.insert(rows, player.Name .. " | " .. (faction == nil and "玩家" or (faction and "友方" or "敌人"))
                    .. " | 队伍 " .. (player.Team and player.Team.Name or "无"))
            end
        end
        local text = #rows > 0 and table.concat(rows, "\n") or "当前没有其他玩家"
        if typeof(setclipboard) == "function" then
            setclipboard(text)
            ANUI:Notify({Title = "已复制", Content = "玩家列表已复制。", Icon = "clipboard", Duration = 3})
        else
            playerList:SetDesc(text)
        end
    end
})



local function refresh()
    if not Running then return end
    local active = {}
    local map = getMap()

    local playerCount, friendCount, foeCount = 0, 0, 0
    local npcCount = 0
    local lootCount, sampleCount, valuableCount = 0, 0, 0
    local storageCount, readableBoxes, gateCount, spawnCount, corpseCount, interactCount = 0, 0, 0, 0, 0, 0

    if Config.playerESP then
        playerCount, friendCount, foeCount = scanPlayers(active)
    end
    npcCount = scanEnemyNPCs(active)
    lootCount, sampleCount, valuableCount = scanLoot(active, map)
    storageCount, readableBoxes = scanStorage(active, map)
    gateCount = scanGates(active, map)
    spawnCount = scanSpawns(active, map)
    corpseCount = scanCorpses(active)
    interactCount = scanInteract(active, map)

    clearInactive(active)

    MapStats = {
        players = playerCount, friends = friendCount, foes = foeCount, npcs = npcCount,
        loot = lootCount, samples = sampleCount, valuable = valuableCount,
        storage = storageCount, readableBoxes = readableBoxes, gates = gateCount, spawns = spawnCount,
        corpses = corpseCount, interact = interactCount
    }

    if os.clock() - LastStatusUpdate >= 1 then
        LastStatusUpdate = os.clock()
        local markCount = 0
        for _ in pairs(Marks) do markCount += 1 end

        overviewParagraph:SetTitle("ANHub V5.6 · 完整功能运行中")
        overviewParagraph:SetDesc(string.format(
            "玩家 %d · 友方 %d · 敌人 %d · NPC %d\n物资 %d · 高价值 %d · 样本 %d\n箱子 %d · 可读内容 %d · 门禁 %d · 刷新点 %d\n尸体 %d · 交互点 %d · 标记总数 %d",
            playerCount, friendCount, foeCount, npcCount,
            lootCount, valuableCount, sampleCount, storageCount, readableBoxes, gateCount, spawnCount, corpseCount, interactCount, markCount
        ))
    end
end

local characterConnection = LocalPlayer.CharacterAdded:Connect(function()
    task.delay(1, function()
        captureMovement()
        applySpeed()
        applyJump()
    end)
end)

captureMovement()

local function scheduleRefresh()
    if not Running or RefreshBusy then return end
    RefreshBusy = true
    task.spawn(function()
        local ok, err = pcall(refresh)
        RefreshBusy = false
        if not ok then
            warn("[ANHub V5] 分批扫描出错：" .. tostring(err))
        end
    end)
end

local spinConnection = RunService.Heartbeat:Connect(function(dt)
    if Config.instantInteract then
        interactionReapplyElapsed += dt
        if interactionReapplyElapsed >= 1 then
            interactionReapplyElapsed = 0
            reapplyInstantInteract()
        end
    end

    if Config.spinEnabled then
        local rootPart = getRoot(LocalPlayer.Character)
        if rootPart and rootPart:IsA("BasePart") then
            rootPart.CFrame = rootPart.CFrame * CFrame.Angles(0, math.rad(Config.spinSpeed) * dt, 0)
        end
    end

    refreshHalfLockWatcher(false)
    if Config.halfInfectionLock and halfLockLatched then
        enforceHalfInfectionLocal()
    end

    PlayerRefreshElapsed += dt
    if PlayerRefreshElapsed >= 1.0 then
        PlayerRefreshElapsed = 0
        if Running and (Config.playerESP or Config.infectionESP) and not RefreshBusy then
            local ok, err = pcall(function() scanPlayers({}) end)
            if not ok then warn("[ANHub] 玩家感染标签刷新：" .. tostring(err)) end
        end
    end

    isolationWatch(dt)

    ScanElapsed += dt
    if ScanElapsed >= ScanInterval then
        ScanElapsed = 0
        scheduleRefresh()
    end
end)

local function cleanup()
    if not Running then return end
    Running = false
    stopIsolation(false,"面板关闭，自动感染已停止")

    if spinConnection then pcall(function() spinConnection:Disconnect() end) end
    if characterConnection then pcall(function() characterConnection:Disconnect() end) end
    if interactionAddedConnection then pcall(function() interactionAddedConnection:Disconnect() end) end
    if promptShownConnection then pcall(function() promptShownConnection:Disconnect() end) end
    if promptTriggeredConnection then pcall(function() promptTriggeredConnection:Disconnect() end) end
    if interactionInputConnection then pcall(function() interactionInputConnection:Disconnect() end) end
    disconnectHalfWatcher()
    setInstantInteract(false)

    for key in pairs(Marks) do clearMark(key) end

    setFullBright(false)
    setNoFog(false)

    if Workspace.CurrentCamera then
        Workspace.CurrentCamera.FieldOfView = Original.fov
    end

    local humanoid = getHumanoid(LocalPlayer.Character)
    if humanoid then
        humanoid.WalkSpeed = BaseMovement.walkSpeed or 16
        humanoid.UseJumpPower = BaseMovement.useJumpPower == nil and true or BaseMovement.useJumpPower
        humanoid.JumpPower = BaseMovement.jumpPower or 50
        humanoid.JumpHeight = BaseMovement.jumpHeight or 7.2
    end
end

ENV.__ANHub_V5_Cleanup = cleanup
ENV.__ANHub_V4_Cleanup = cleanup

pcall(function()
    Window:OnDestroy(cleanup)
end)

-- 首轮扫描也放到后台分批执行，不阻塞脚本启动时的渲染帧。
scheduleRefresh()

ANUI:Notify({
    Title = "ANHub V5.6 已启动",
    Content = "新增隐蔽感染：自动筛选孤立胶兽、真实感染监控与 Benign 优先模式；不保证绝对隐身。右 Shift 显示/隐藏。",
    Icon = "shield",
    Duration = 5
})

return "ANHub V5.6 isolated infection scanner and ESP loaded"