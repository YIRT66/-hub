--[[
    YIRT66 / Hitman Card Game - Card Information Inspector
    PlaceId: 92352895821733
    UI: ANHub-Script / ANUI (official dist/main.lua)
    This is read-only. It shows only card identities actually replicated
    to this client. Server-hidden deck order and opponent hands are UNKNOWN.
]]
if game.PlaceId ~= 92352895821733 then
    warn("[YIRT66] 错误游戏；本脚本仅适用于 Hitman Card Game (92352895821733)")
    return
end

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer
if not LocalPlayer then return end

local ENV = (type(getgenv) == "function" and getgenv()) or _G
if ENV.YIRT66HitmanInspector and ENV.YIRT66HitmanInspector.Stop then
    pcall(ENV.YIRT66HitmanInspector.Stop)
end

local ok, ANUI = pcall(function()
    return loadstring(game:HttpGet("https://raw.githubusercontent.com/ANHub-Script/ANUI/refs/heads/main/dist/main.lua"))()
end)
if not ok or not ANUI then
    warn("[YIRT66] ANUI 加载失败: " .. tostring(ANUI))
    return
end

local Window = ANUI:CreateWindow({
    Title = "Hitman 卡牌检测",
    Author = "YIRT66 | ANUI",
    Icon = "scan-eye",
    Theme = "Dark",
    ToggleKey = Enum.KeyCode.RightShift,
    OpenButton = {
        Title = "卡牌",
        Enabled = true,
        Draggable = true,
        OnlyMobile = false,
    },
})
if not Window then
    warn("[YIRT66] ANUI 只能存在一个窗口；请先关闭已有 ANUI 窗口")
    return
end

local state = {
    alive = true,
    automatic = true,
    interval = 1,
    overlayVisible = true,
    report = "尚未读取",
    window = Window,
}
ENV.YIRT66HitmanInspector = state

local gui = Instance.new("ScreenGui")
gui.Name = "YIRT66_Hitman_Card_Info"
gui.IgnoreGuiInset = true
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
state.overlay = gui

local frame = Instance.new("Frame")
frame.Name = "Readout"
frame.AnchorPoint = Vector2.new(1, 0.5)
frame.Position = UDim2.new(1, -18, 0.5, 0)
frame.Size = UDim2.fromOffset(410, 455)
frame.BackgroundColor3 = Color3.fromRGB(19, 22, 29)
frame.BackgroundTransparency = 0.07
frame.BorderSizePixel = 0
frame.Parent = gui
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame
local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(70, 80, 105)
stroke.Thickness = 1
stroke.Parent = frame

local heading = Instance.new("TextLabel")
heading.Name = "Heading"
heading.BackgroundTransparency = 1
heading.Position = UDim2.fromOffset(14, 10)
heading.Size = UDim2.new(1, -28, 0, 28)
heading.Text = "HITMAN | 卡牌情报"
heading.TextColor3 = Color3.fromRGB(104, 207, 255)
heading.Font = Enum.Font.GothamBold
heading.TextSize = 17
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.Parent = frame

local note = Instance.new("TextLabel")
note.BackgroundTransparency = 1
note.Position = UDim2.fromOffset(14, 38)
note.Size = UDim2.new(1, -28, 0, 35)
note.Text = "只展示客户端可验证的信息；? 表示真实牌面未公开"
note.TextColor3 = Color3.fromRGB(176, 186, 203)
note.Font = Enum.Font.Gotham
note.TextSize = 12
note.TextWrapped = true
note.TextXAlignment = Enum.TextXAlignment.Left
note.Parent = frame

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Cards"
scroll.Position = UDim2.fromOffset(12, 78)
scroll.Size = UDim2.new(1, -24, 1, -90)
scroll.BorderSizePixel = 0
scroll.BackgroundTransparency = 1
scroll.ScrollBarThickness = 4
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.Parent = frame

local output = Instance.new("TextLabel")
output.Name = "ReadoutText"
output.BackgroundTransparency = 1
output.Position = UDim2.fromOffset(2, 2)
output.Size = UDim2.new(1, -10, 0, 0)
output.AutomaticSize = Enum.AutomaticSize.Y
output.TextColor3 = Color3.fromRGB(239, 241, 249)
output.Font = Enum.Font.Code
output.TextSize = 14
output.TextXAlignment = Enum.TextXAlignment.Left
output.TextYAlignment = Enum.TextYAlignment.Top
output.TextWrapped = true
output.RichText = false
output.Text = "正在检测游戏状态..."
output.Parent = scroll

local function getCardType(card)
    if not card:IsA("BasePart") and not card:IsA("Model") then return nil end
    local id = card:GetAttribute("Type")
    if typeof(id) == "string" and id ~= "" then return id end
    return nil
end

local function collectCards(folder)
    local known, unknown = {}, 0
    if folder then
        for _, card in ipairs(folder:GetChildren()) do
            if card:IsA("BasePart") or card:IsA("Model") then
                local kind = getCardType(card)
                if kind then
                    table.insert(known, kind)
                else
                    unknown = unknown + 1
                end
            end
        end
    end
    table.sort(known)
    return known, unknown
end

local function findRoom()
    local rooms = ReplicatedStorage:FindFirstChild("Rooms")
    if not rooms then return nil end
    local host = LocalPlayer:GetAttribute("MatchHost")
    if typeof(host) == "string" then
        local exact = rooms:FindFirstChild(host)
        if exact then return exact end
    end
    for _, room in ipairs(rooms:GetChildren()) do
        local members = room:FindFirstChild("Members")
        if members and members:FindFirstChild(LocalPlayer.Name) then
            return room
        end
    end
    return nil
end

local function formatKnown(known)
    return #known > 0 and table.concat(known, ", ") or "无已确认牌面"
end

local function buildReport()
    local lines = {
        "游戏: Hitman Card Game",
        "Place ID: " .. tostring(game.PlaceId),
        "----------------------------------",
    }
    local setup = workspace:FindFirstChild("MatchSetup")
    local hand = setup and setup:FindFirstChild("Hand")
    local deck = setup and setup:FindFirstChild("Deck")
    local room = findRoom()

    if not hand or not deck then
        table.insert(lines, "状态: 尚未进入正在进行的对局")
        table.insert(lines, "请在开局后自动等待刷新。")
        return table.concat(lines, "\n")
    end

    table.insert(lines, "状态: 检测到对局场景")
    if room then
        table.insert(lines, "房间: " .. room.Name)
    end
    table.insert(lines, "")
    table.insert(lines, "[抽牌堆]")
    local remaining = room and room:GetAttribute("CardsLeft")
    table.insert(lines, "剩余张数: " .. (typeof(remaining) == "number" and tostring(remaining) or "未知"))
    local deckKnown = {}
    local ownType = getCardType(deck)
    if ownType then table.insert(deckKnown, ownType) end
    for _, child in ipairs(deck:GetChildren()) do
        local kind = getCardType(child)
        if kind then table.insert(deckKnown, kind) end
    end
    table.insert(lines, "已公开的堆内牌: " .. formatKnown(deckKnown))
    table.insert(lines, "未公开的抽牌顺序: ? (服务器未提供)")

    table.insert(lines, "")
    table.insert(lines, "[我的手牌]")
    local myKnown, myUnknown = collectCards(hand)
    table.insert(lines, "牌面: " .. formatKnown(myKnown))
    if myUnknown > 0 then
        table.insert(lines, "未确认: " .. tostring(myUnknown) .. " 张")
    end

    table.insert(lines, "")
    table.insert(lines, "[其他玩家手牌]")
    local opponents = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local folder = setup:FindFirstChild(player.Name .. " Cards")
            local count = player:GetAttribute("CardCount")
            if folder or typeof(count) == "number" then
                table.insert(opponents, { player = player, folder = folder, count = count })
            end
        end
    end
    table.sort(opponents, function(a, b)
        return a.player.Name:lower() < b.player.Name:lower()
    end)

    if #opponents == 0 then
        table.insert(lines, "暂无可识别的对手信息")
    end
    for _, entry in ipairs(opponents) do
        local known, unknown = collectCards(entry.folder)
        if typeof(entry.count) == "number" then
            unknown = math.max(unknown, entry.count - #known)
        end
        table.insert(lines, "- " .. entry.player.DisplayName .. " (@" .. entry.player.Name .. ")")
        table.insert(lines, "  已确认: " .. formatKnown(known))
        if unknown > 0 then
            table.insert(lines, "  隐藏牌: " .. tostring(unknown) .. " 张 [?]")
        elseif #known == 0 then
            table.insert(lines, "  手牌数量/牌面: 未公开")
        end
    end

    table.insert(lines, "")
    table.insert(lines, "[公开弃牌 / 已出牌]")
    local pile = setup:FindFirstChild("CardPile")
    local played, pileUnknown = collectCards(pile)
    table.insert(lines, "已确认: " .. formatKnown(played))
    if pileUnknown > 0 then
        table.insert(lines, "未知: " .. tostring(pileUnknown) .. " 张")
    end
    table.insert(lines, "")
    table.insert(lines, "注: ? 不是猜测牌型，而是未知数据。")
    return table.concat(lines, "\n")
end

local function refresh()
    if not state.alive then return end
    local success, report = pcall(buildReport)
    if success then
        state.report = report
        output.Text = report
    else
        state.report = "[YIRT66] 读取错误: " .. tostring(report)
        output.Text = state.report
        warn(state.report)
    end
end

function state.Stop()
    if not state.alive then return end
    state.alive = false
    pcall(function() gui:Destroy() end)
    pcall(function() Window:Destroy() end)
    if ENV.YIRT66HitmanInspector == state then
        ENV.YIRT66HitmanInspector = nil
    end
end

Window:OnDestroy(function()
    state.alive = false
    pcall(function() gui:Destroy() end)
    if ENV.YIRT66HitmanInspector == state then
        ENV.YIRT66HitmanInspector = nil
    end
end)

local overview = Window:Tab({ Title = "牌堆", Icon = "layers" })
overview:Paragraph({
    Title = "牌堆可见信息",
    Desc = "读取当前对局的牌堆剩余张数、公开弃牌和有 Type 属性的牌。\n服务器未复制到客户端的抽牌顺序不会被伪造。",
})
overview:Button({
    Title = "立即读取牌堆与手牌",
    Icon = "refresh-cw",
    Callback = function()
        refresh()
        ANUI:Notify({ Title = "读取完成", Content = "已更新右侧卡牌面板", Duration = 3 })
    end,
})

local handsTab = Window:Tab({ Title = "手牌", Icon = "users" })
handsTab:Paragraph({
    Title = "对手手牌辨识",
    Desc = "遍历 MatchSetup 中每个玩家的 Cards 容器。\n若目标牌没有 Type 属性，显示 ?；不会把卡背贴图误判为牌面。",
})
handsTab:Button({
    Title = "复制本次报告",
    Icon = "copy",
    Callback = function()
        refresh()
        if type(setclipboard) == "function" then
            setclipboard(state.report)
            ANUI:Notify({ Title = "复制成功", Content = "报告已复制到剪贴板", Duration = 3 })
        else
            ANUI:Notify({ Title = "复制失败", Content = "执行器不支持 setclipboard", Duration = 4 })
        end
    end,
})

local settings = Window:Tab({ Title = "设置", Icon = "settings" })
settings:Toggle({
    Title = "自动刷新",
    Desc = "自动更新卡牌信息",
    Value = true,
    Callback = function(value) state.automatic = value end,
})
settings:Toggle({
    Title = "显示卡牌面板",
    Desc = "切换右侧实时文字面板",
    Value = true,
    Callback = function(value)
        state.overlayVisible = value
        gui.Enabled = value
    end,
})
settings:Slider({
    Title = "刷新间隔 (秒)",
    Value = { Min = 1, Max = 5, Default = 1, Step = 1 },
    Callback = function(value)
        state.interval = math.clamp(tonumber(value) or 1, 1, 5)
    end,
})
settings:Button({
    Title = "关闭并卸载",
    Icon = "x",
    Callback = function() state.Stop() end,
})
settings:Paragraph({
    Title = "数据来源与限制",
    Desc = "MCP 已确认本游戏的 MatchSetup.Hand、玩家 Cards 文件夹、CardPile 和房间 CardsLeft。\n真正只存在于服务器内存的牌堆顺序、其他玩家的秘密手牌，不可直接从客户端读取。",
})

refresh()
task.spawn(function()
    while state.alive do
        if state.automatic then refresh() end
        task.wait(state.interval)
    end
end)
print("[YIRT66] Hitman Card Inspector / ANUI 初始化完成")
