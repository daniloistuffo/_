
-- CONTROLE RAPIDO V2
-- LocalScript

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- CONFIGURACAO
local CHECK_INTERVAL = 0.15
local DISTANCE_EXTRA = 2

-- REMOVER UI ANTIGA
local oldUI = playerGui:FindFirstChild("ControleRapidoUI")
if oldUI then
    oldUI:Destroy()
end

-- ESTADOS
local isAnchored = false
local autoPromptEnabled = false
local activePrompts = {}
local registeredPrompts = {}

-- CRIAR INTERFACE
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ControleRapidoUI"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Name = "MainFrame"
frame.Size = UDim2.new(0, 220, 0, 118)
frame.Position = UDim2.new(0, 20, 0.5, -59)
frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
frame.BorderSizePixel = 0
frame.Active = true
frame.Draggable = true
frame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.new(0, 8, 0, 6)
title.BackgroundTransparency = 1
title.Text = "Painel Rapido"
title.TextColor3 = Color3.fromRGB(240, 240, 245)
title.Font = Enum.Font.GothamBold
title.TextSize = 14
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local function createButton(name, text, y, color)
    local button = Instance.new("TextButton")
    button.Name = name
    button.Size = UDim2.new(1, -16, 0, 34)
    button.Position = UDim2.new(0, 8, 0, y)
    button.BackgroundColor3 = color
    button.Text = text
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 13
    button.AutoButtonColor = true
    button.Parent = frame

    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 8)
    c.Parent = button

    return button
end

local anchorBtn = createButton(
    "AnchorButton",
    "Ancorar: OFF",
    34,
    Color3.fromRGB(45, 95, 180)
)

local promptBtn = createButton(
    "PromptButton",
    "Auto Prompt: OFF",
    74,
    Color3.fromRGB(55, 55, 65)
)

-- ANCORAGEM
local function setCharacterAnchored(state)
    local character = player.Character
    if not character then return end

    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") then
            part.Anchored = state

            if state then
                part.AssemblyLinearVelocity = Vector3.zero
                part.AssemblyAngularVelocity = Vector3.zero
            end
        end
    end

    local humanoid = character:FindFirstChildOfClass("Humanoid")

    if humanoid then
        humanoid.PlatformStand = state
    end
end

anchorBtn.Activated:Connect(function()
    isAnchored = not isAnchored
    setCharacterAnchored(isAnchored)

    if isAnchored then
        anchorBtn.Text = "Ancorar: ON"
        anchorBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
    else
        anchorBtn.Text = "Ancorar: OFF"
        anchorBtn.BackgroundColor3 = Color3.fromRGB(45, 95, 180)
    end
end)

player.CharacterAdded:Connect(function(character)
    character:WaitForChild("HumanoidRootPart")

    if isAnchored then
        task.wait(0.2)
        setCharacterAnchored(true)
    end
end)

-- PROXIMITY PROMPT

local function getPromptPart(prompt)
    local parent = prompt.Parent

    if not parent then
        return nil
    end

    if parent:IsA("Attachment") then
        parent = parent.Parent
    end

    if parent:IsA("BasePart") then
        return parent
    end

    if parent:IsA("Model") then
        return parent.PrimaryPart
            or parent:FindFirstChildWhichIsA("BasePart", true)
    end

    return nil
end

local function isPromptInRange(prompt)
    if not prompt or not prompt.Parent or not prompt.Enabled then
        return false
    end

    local character = player.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")

    if not root then
        return false
    end

    local part = getPromptPart(prompt)

    if not part then
        return false
    end

    local distance = (root.Position - part.Position).Magnitude

    return distance <= prompt.MaxActivationDistance + DISTANCE_EXTRA
end

local function releasePrompt(prompt)
    if not activePrompts[prompt] then
        return
    end

    activePrompts[prompt] = nil

    pcall(function()
        prompt:InputHoldEnd()
    end)
end

local function stopAllPrompts()
    for prompt in pairs(activePrompts) do
        releasePrompt(prompt)
    end
end

-- REGISTRAR PROMPTS

local function registerPrompt(prompt)
    if registeredPrompts[prompt] then
        return
    end

    registeredPrompts[prompt] = true
end

for _, object in ipairs(workspace:GetDescendants()) do
    if object:IsA("ProximityPrompt") then
        registerPrompt(object)
    end
end

workspace.DescendantAdded:Connect(function(object)
    if object:IsA("ProximityPrompt") then
        registerPrompt(object)
    end
end)

workspace.DescendantRemoving:Connect(function(object)
    if object:IsA("ProximityPrompt") then
        releasePrompt(object)
        registeredPrompts[object] = nil
    end
end)

-- INICIAR INTERACAO

local function startPrompt(prompt)
    if activePrompts[prompt] then
        return
    end

    if not isPromptInRange(prompt) then
        return
    end

    activePrompts[prompt] = true

    task.spawn(function()
        local success = pcall(function()
            prompt:InputHoldBegin()
        end)

        if not success then
            releasePrompt(prompt)
            return
        end

        local holdTime = math.max(prompt.HoldDuration, 0.1)
        local elapsed = 0

        while elapsed < holdTime do
            if not autoPromptEnabled
                or not prompt.Parent
                or not isPromptInRange(prompt) then
                break
            end

            local step = math.min(0.05, holdTime - elapsed)
            task.wait(step)
            elapsed += step
        end

        releasePrompt(prompt)
    end)
end

-- BOTAO AUTO PROMPT

promptBtn.Activated:Connect(function()
    autoPromptEnabled = not autoPromptEnabled

    if autoPromptEnabled then
        promptBtn.Text = "Auto Prompt: ON"
        promptBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 90)
    else
        promptBtn.Text = "Auto Prompt: OFF"
        promptBtn.BackgroundColor3 = Color3.fromRGB(55, 55, 65)

        stopAllPrompts()
    end
end)

-- LOOP OTIMIZADO

task.spawn(function()
    while screenGui.Parent do
        if autoPromptEnabled then
            for prompt in pairs(registeredPrompts) do
                if prompt.Parent then
                    if isPromptInRange(prompt) then
                        startPrompt(prompt)
                    else
                        releasePrompt(prompt)
                    end
                else
                    releasePrompt(prompt)
                    registeredPrompts[prompt] = nil
                end
            end
        end

        task.wait(CHECK_INTERVAL)
    end
end)

-- DETECTAR INTERACAO CONCLUIDA

ProximityPromptService.PromptTriggered:Connect(function(prompt, whoTriggered)
    if whoTriggered == player then
        releasePrompt(prompt)
    end
end)

-- LIMPEZA
screenGui.Destroying:Connect(function()
    autoPromptEnabled = false
    stopAllPrompts()
end)

print("Controle Rapido V2 carregado!")
