local cloneref = cloneref or function(instance)
    return instance
end

local InputService = cloneref(game:GetService('UserInputService'))
local TweenService = cloneref(game:GetService('TweenService'))
local Players = cloneref(game:GetService('Players'))
local HttpService = cloneref(game:GetService('HttpService'))
local TextService = cloneref(game:GetService('TextService'))
local CoreGui = cloneref(game:GetService('CoreGui'))

local Signal = fetchScript('classes/signal')
local Maid = fetchScript('classes/maid')

local configIgnore = {
    'ConfigOptionsButton', 'DestructOptionsButton', 'HUDOptionsButton',
    'ClickGuiOptionsButton', 'ColorsOptionsButton', 'DiscordOptionsButton',
    'HUDOptionsButtonNotificationsToggle', 'ColorsOptionsButtonRainbowToggle',
    'ClickGuiOptionsButtonClickSoundsToggle', 'HUDOptionsButtonArrayListToggle',
    'HUDOptionsButtonListBackgroundToggle', 'HUDOptionsButtonListLinesToggle',
    'HUDOptionsButtonWatermarkToggle', 'HUDOptionsButtonWMLineToggle',
    'HUDOptionsButtonWMBackgroundToggle', 'HUDOptionsButtonRenderingSelector',
    'HUDOptionsButtonFPSToggle', 'HUDOptionsButtonSpeedToggle',
    'HUDOptionsButtonCoordsToggle', 'HUDOptionsButtonPingToggle',
    'RestartOptionsButton', 'FontOptionsButton',
    'FontOptionsButtonTextSizeSlider', 'ConfigOptionsButtonConfigNameTextbox'
}

local drawingClasses = {
    'Square',
    'Line',
    'Text',
    'Quad',
    'Circle',
    'Triangle'
}

local gui = {
    maid = Maid.new(),

    objects = {},
    signals = {},
    notifs = {},

    guiKeybind = 'RightControl',
    debugging = false,
    nextWindowPos = 40,
    clickSounds = true,

    colorTheme = { H = 1, S = 1, V = 0.7 },
    rainbow = false,
    rainbowSpeed = 10,
    textSize = 19,

    arrayListEnabled = false,
    listBackground = false,
    listLines = false,
    drawWatermark = false,
    watermarkLine = false,
    watermarkBackground = false,
    hudEnabled = true,

    drawCoords = false,
    drawSpeed = false,
    drawFPS = false,
    drawPing = false,

    base = nil,
    clickUI = nil,
    notifsBase = nil
}

local function isFunctionEmpty(func)
    local constants = #debug.getconstants(func)
    local protos = #debug.getprotos(func)
    local upvalues = #debug.getupvalues(func)

    return constants + protos + upvalues == 0
end

function gui:Create(class, props)
    if not class then
        return
    end

    props = props or {}

    local isDrawing = table.find(drawingClasses, class)
    local create = isDrawing and Drawing or Instance

    local instance = cloneref(create.new(class))

    for prop, value in next, props do
        if prop == 'Name' and not self.debugging then
            continue
        end

        instance[prop] = value
    end

    self.maid:GiveTask(instance)
    return instance
end

function gui:Connect(connection, callback)
    connection = connection:Connect(callback)
    self.maid:GiveTask(connection)

    return connection
end

function gui:Start()
    self.signals.updateColor = Signal.new()
    self.signals.statsUpdate = Signal.new()
    self.signals.hudUpdate = Signal.new()

    self.base = self:Create('ScreenGui', {
        IgnoreGuiInset = false,
        AutoLocalize = false,
        Enabled = true
    })

    self.clickUI = self:Create('Frame', {
        Name = 'ClickUI',
        Size = UDim2.new(1, 0, 1, 0),
        BackgroundTransparency = 1,
        Visible = false,
        Parent = self.base
    })

    self.notifsBase = self:Create('Frame', {
        Name = 'Notifications',
        BackgroundTransparency = 1,
        Active = false,
        Size = UDim2.new(1, 0, 1, 0),
        Parent = self.base
    })

    if gethui and not self.debugging then
        self.base.Parent = gethui()
    else
        self.base.Parent = cloneref(CoreGui)
    end

    self:SetupArrayList()
    self:SetupHUD()
    self:StartRainbow()

    self:Connect(InputService.InputBegan, function(input)
        if input.KeyCode.Name ~= self.guiKeybind or InputService:GetFocusedTextBox() then
            return
        end

        self.clickUI.Visible = not self.clickUI.Visible
    end)
end

function gui:Unload()
    self.maid:DoCleaning()
end

function gui:GetColor()
    return Color3.fromHSV(self.colorTheme.H, self.colorTheme.S, self.colorTheme.V)
end

function gui:Dragify(frame, point)
    local dragging, dragInput, startPos
    local dragStart = Vector3.new(0, 0, 0)

    local function update(input)
        local delta = input.Position - dragStart

        TweenService:Create(frame, TweenInfo.new(0.20), {
            Position = UDim2.new(
                startPos.X.Scale,
                startPos.X.Offset + delta.X,
                startPos.Y.Scale,
                startPos.Y.Offset + delta.Y
            )
        }):Play()
    end

    point.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 or dragging then
            return
        end

        dragStart = input.Position

        if (input.Position - dragStart).Y > 30 then
            return
        end

        dragging = self.clickUI and self.clickUI.Visible or false
        startPos = frame.Position

        input.Changed:Connect(function()
            if input.UserInputState ~= Enum.UserInputState.End then
                return
            end

            dragging = false
        end)
    end)

    point.InputChanged:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseMovement then
            return
        end

        dragInput = input
    end)

    self:Connect(InputService.InputChanged, function(input)
        if input ~= dragInput or not dragging then
            return
        end

        update(input)
    end)
end

function gui:PlayClickSound()
    if not self.clickSounds then
        return
    end

    self:Create('Sound', {
        SoundId = 'rbxassetid://535716488',
        PlayOnRemove = true,
        Parent = workspace
    }):Destroy()
end

function gui:StartRainbow()
    local i = 0

    self.maid:GiveTask(task.spawn(function()
        while self.base do
            if self.rainbow then
                self.colorTheme = { H = i, S = self.colorTheme.S, V = self.colorTheme.V }
                self.signals.updateColor:Fire(self.colorTheme)

                i = i + 0.000025 * (self.rainbowSpeed * 2.5)
                if i > 1 then i = 0 end
            end

            task.wait()
        end
    end))
end

function gui:DrawWatermark()
    if self._watermark then
        self._watermark:Destroy()
        self._watermark = nil
    end

    if self._watermarkUpdate then
        self._watermarkUpdate:Disconnect()
        self._watermarkUpdate = nil
    end

    if not self.drawWatermark then
        return
    end

    local watermark = self:Create('TextLabel', {
        Name = 'Watermark',
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 1,
        Position = UDim2.new(0, 110, 0, -27),
        Size = UDim2.new(0, 0, 0, 20),
        Font = Enum.Font.GothamSemibold,
        Text = 'GUI Watermark',
        BorderSizePixel = 0,
        TextSize = self.textSize,
        TextStrokeTransparency = 0.4,
        TextXAlignment = Enum.TextXAlignment.Center,
        TextColor3 = self:GetColor(),
        AutomaticSize = Enum.AutomaticSize.X,
        Parent = self.base
    })

    local bg = self:Create('TextLabel', {
        Name = 'Background',
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = self.watermarkBackground and 0.5 or 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        AnchorPoint = Vector2.new(0.5, 0.5),
        Size = UDim2.new(0, watermark.AbsoluteSize.X + 5, 0, watermark.AbsoluteSize.Y),
        Font = Enum.Font.GothamSemibold,
        Text = '',
        BorderSizePixel = 0,
        ZIndex = -1,
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = watermark
    })

    local line = self:Create('TextLabel', {
        Name = 'Line',
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = self.watermarkLine and 0 or 1,
        Position = UDim2.new(0, -5, 0.5, 0),
        AnchorPoint = Vector2.new(0, 0.5),
        Size = UDim2.new(0, 3, 0, 20),
        Font = Enum.Font.GothamSemibold,
        Text = '',
        BorderSizePixel = 0,
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Center,
        Parent = watermark
    })

    self._watermark = watermark

    self._watermarkUpdate = self.signals.updateColor:Connect(function()
        watermark.TextColor3 = self:GetColor()
        line.BackgroundColor3 = self:GetColor()
    end)
end

function gui:SetupArrayList()
    local arrayListFrame = self:Create('Frame', {
        Name = 'ArrayList',
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 197, 0, 346),
        Visible = false,
        Parent = self.base
    })

    local layout = self:Create('UIListLayout', {
        HorizontalAlignment = Enum.HorizontalAlignment.Right,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 0),
        Parent = arrayListFrame
    })

    self:Dragify(arrayListFrame, arrayListFrame)

    self._arrayListFrame = arrayListFrame
    self._arrayListLayout = layout
    self._arrayObjects = {}
    self._arrayConnections = {}
end

function gui:RefreshArrayList()
    for name, obj in next, self._arrayObjects do
        obj:Destroy()
        self._arrayObjects[name] = nil

        if self._arrayConnections[name] then
            self._arrayConnections[name]:Disconnect()
            self._arrayConnections[name] = nil
        end

        if self._arrayConnections['shadow_' .. name] then
            self._arrayConnections['shadow_' .. name]:Disconnect()
            self._arrayConnections['shadow_' .. name] = nil
        end
    end

    if not self.arrayListEnabled or not self.hudEnabled then
        self._arrayListFrame.Visible = false
        return
    end

    self._arrayListFrame.Visible = true

    local sorted = {}

    for _, v in next, self.objects do
        if v.type == 'Module' and not table.find(configIgnore, v.name .. 'OptionsButton') and v.api.enabled then
            table.insert(sorted, v)
        end
    end

    table.sort(sorted, function(a, b)
        local aText = a.name .. (typeof(a.arrayText) == 'function' and (' [' .. tostring(a.arrayText()) .. '] ') or ' ')
        local bText = b.name .. (typeof(b.arrayText) == 'function' and (' [' .. tostring(b.arrayText()) .. '] ') or ' ')
        local aSize = TextService:GetTextSize(aText, self.textSize, Enum.Font.GothamSemibold, Vector2.new(99999, 99999))
        local bSize = TextService:GetTextSize(bText, self.textSize, Enum.Font.GothamSemibold, Vector2.new(99999, 99999))

        return aSize.X > bSize.X
    end)

    for i, v in next, sorted do
        local text = v.name .. ' '

        if typeof(v.arrayText) == 'function' then
            text = text .. '<font color=\'rgb(130, 130, 130)\'>[</font><font color=\'rgb(170, 170, 170)\'>' .. tostring(v.arrayText()) .. '</font><font color=\'rgb(130, 130, 130)\'>]</font> '
        end

        local label = self:Create('TextLabel', {
            Name = v.name,
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = 1,
            Position = UDim2.new(0, 0, 0, 0),
            Size = UDim2.new(0, 0, 0, 18),
            Font = Enum.Font.GothamSemibold,
            RichText = true,
            Text = text,
            BorderSizePixel = 0,
            TextStrokeTransparency = 0.4,
            TextColor3 = self:GetColor(),
            TextSize = self.textSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            AutomaticSize = Enum.AutomaticSize.X,
            LayoutOrder = i,
            Parent = self._arrayListFrame
        })

        local shadow = self:Create('TextLabel', {
            Name = 'Background',
            BackgroundColor3 = Color3.fromRGB(0, 0, 0),
            BackgroundTransparency = self.listBackground and 0.5 or 1,
            Position = UDim2.new(0.5, 0, 0.5, 0),
            AnchorPoint = Vector2.new(0.5, 0.5),
            Size = UDim2.new(0, label.AbsoluteSize.X + 5, 0, label.AbsoluteSize.Y),
            Font = Enum.Font.GothamSemibold,
            Text = '',
            BorderSizePixel = 0,
            ZIndex = -1,
            TextSize = self.textSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = label
        })

        local line = self:Create('TextLabel', {
            Name = 'Line',
            BackgroundColor3 = self:GetColor(),
            BackgroundTransparency = self.listLines and 0 or 1,
            Position = UDim2.new(1, 1, 0.5, 0),
            AnchorPoint = Vector2.new(-1, 0.5),
            Size = UDim2.new(0, 3, 0, 20),
            Font = Enum.Font.GothamSemibold,
            Text = '',
            BorderSizePixel = 0,
            TextSize = self.textSize,
            TextXAlignment = Enum.TextXAlignment.Center,
            Parent = label
        })

        local colorConn = self.signals.updateColor:Connect(function()
            label.TextColor3 = self:GetColor()
            line.BackgroundColor3 = self:GetColor()
        end)

        local sizeConn = label:GetPropertyChangedSignal('Size'):Connect(function()
            shadow.Size = UDim2.new(0, label.AbsoluteSize.X + 7, 0, label.AbsoluteSize.Y)
        end)

        self._arrayObjects[v.name] = label
        self._arrayConnections[v.name] = colorConn
        self._arrayConnections['shadow_' .. v.name] = sizeConn
    end
end

function gui:SetupHUD()
    local hudFrame = self:Create('Frame', {
        Name = 'HUDElements',
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.fromOffset(200, 15),
        Parent = self.base
    })

    self:Create('UIListLayout', {
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = hudFrame
    })

    self:Dragify(hudFrame, hudFrame)

    self._hudFrame = hudFrame
    self._hudLabels = {}
end

function gui:RefreshHUD()
    for _, label in next, self._hudLabels do
        label:Destroy()
    end
    self._hudLabels = {}

    if not self.hudEnabled then
        return
    end

    local function makeLabel(name, order)
        local label = self:Create('TextLabel', {
            Name = name,
            BackgroundTransparency = 1,
            Size = UDim2.new(0, 200, 0, 20),
            Font = Enum.Font.GothamSemibold,
            RichText = true,
            Text = '',
            TextStrokeTransparency = 0,
            TextColor3 = Color3.fromRGB(255, 255, 255),
            TextSize = self.textSize,
            TextXAlignment = Enum.TextXAlignment.Right,
            LayoutOrder = order,
            Parent = self._hudFrame
        })

        self._hudLabels[name] = label
        return label
    end

    if self.drawCoords then makeLabel('Coords', 1) end
    if self.drawSpeed then makeLabel('Speed', 2) end
    if self.drawPing then makeLabel('Ping', 3) end
    if self.drawFPS then makeLabel('FPS', 4) end

    if self.drawCoords or self.drawSpeed or self.drawFPS or self.drawPing then
        if self._statsConn then
            self._statsConn:Disconnect()
        end

        self._statsConn = self.signals.statsUpdate:Connect(function(coords, speed, fps, ping)
            if self.drawCoords and self._hudLabels.Coords then
                local function fmt(n)
                    local rounded = math.round(n * 10) / 10
                    return (math.round(rounded) == rounded) and (tostring(rounded) .. '.0') or tostring(rounded)
                end

                self._hudLabels.Coords.Text = '<font color=\'rgb(190, 190, 190)\'>XYZ</font> <font color=\'rgb(255, 255, 255)\'>' .. fmt(coords.X) .. ', ' .. fmt(coords.Y) .. ', ' .. fmt(coords.Z) .. '</font>'
            end

            if self.drawSpeed and self._hudLabels.Speed then
                self._hudLabels.Speed.Text = '<font color=\'rgb(190, 190, 190)\'>Speed</font> <font color=\'rgb(255, 255, 255)\'>' .. tostring(speed) .. 'km/h</font>'
            end

            if self.drawFPS and self._hudLabels.FPS then
                self._hudLabels.FPS.Text = '<font color=\'rgb(190, 190, 190)\'>FPS</font> <font color=\'rgb(255, 255, 255)\'>' .. tostring(fps) .. '</font>'
            end

            if self.drawPing and self._hudLabels.Ping then
                self._hudLabels.Ping.Text = '<font color=\'rgb(190, 190, 190)\'>Ping</font> <font color=\'rgb(255, 255, 255)\'>' .. tostring(math.round(ping)) .. '</font>'
            end
        end)
    end
end

function gui:UpdateHUD()
    self:RefreshArrayList()
    self:DrawWatermark()
    self:RefreshHUD()
end

local notifSize = UDim2.new(0, 300, 0, 100)
local notifSlot = notifSize.Y.Offset + 5

function gui:Notify(title, text, time)
    title = title or 'Notification'
    text = text or ''
    time = time or 2

    local slot = 1
    while self.notifs[slot] do
        slot += 1
    end

    local targetY = -notifSlot * slot

    local toast = self:Create('Frame', {
        Name = 'Toast',
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.25,
        BorderSizePixel = 0,
        Position = UDim2.new(1, notifSize.X.Offset, 1, targetY),
        Size = notifSize,
        Parent = self.notifsBase
    })

    self.notifs[slot] = toast

    local topbar = self:Create('Frame', {
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Size = UDim2.new(0, notifSize.X.Offset, 0, notifSize.Y.Offset / 3.16),
        Parent = toast
    })

    local bottomBar = self:Create('Frame', {
        BackgroundColor3 = Color3.fromRGB(255, 255, 255),
        BackgroundTransparency = 0.6,
        BorderSizePixel = 0,
        Size = UDim2.new(0, notifSize.X.Offset, 0, 5),
        Position = UDim2.new(0.5, 0, 1, -5),
        AnchorPoint = Vector2.new(0.5, 0),
        Parent = toast
    })

    self:Create('TextLabel', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.026, 0, 0, 0),
        Size = UDim2.new(0, notifSize.X.Offset / 1.163, 0, notifSize.Y.Offset / 3.16),
        Font = Enum.Font.GothamSemibold,
        Text = title,
        RichText = true,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar
    })

    self:Create('TextLabel', {
        BackgroundTransparency = 1,
        Position = UDim2.new(0.026, 0, 0, topbar.Size.Y.Offset + 5),
        Size = UDim2.new(0, notifSize.X.Offset / 1.14, 0, notifSize.Y.Offset / 1.053),
        Font = Enum.Font.GothamSemibold,
        Text = text,
        RichText = true,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        TextYAlignment = Enum.TextYAlignment.Top,
        Parent = toast
    })

    local onUpdateColor = self.signals.updateColor:Connect(function()
        topbar.BackgroundColor3 = self:GetColor()
    end)

    toast:TweenPosition(
        UDim2.new(1, -(notifSize.X.Offset + 10), 1, targetY),
        Enum.EasingDirection.Out,
        Enum.EasingStyle.Sine,
        0.15,
        true
    )

    task.wait(0.15)

    bottomBar:TweenSize(
        UDim2.new(0, 0, 0, 5),
        Enum.EasingDirection.In,
        Enum.EasingStyle.Linear,
        time,
        true
    )

    task.wait(time)

    toast:TweenPosition(
        UDim2.new(1, notifSize.X.Offset, 1, targetY),
        Enum.EasingDirection.In,
        Enum.EasingStyle.Sine,
        0.15,
        true
    )

    task.wait(0.15)

    onUpdateColor:Disconnect()
    self.notifs[slot] = nil
    toast:Destroy()

    for slot, toast in next, self.notifs do
        toast:TweenPosition(
            UDim2.new(1, -(notifSize.X.Offset + 10), 1, -notifSlot * slot),
            Enum.EasingDirection.Out,
            Enum.EasingStyle.Sine,
            0.15,
            true
        )
    end
end

function gui:SaveConfig(name)
    name = name or 'default'

    local config = {}

    for id, v in next, self.objects do
        if v.type == 'Module' and not table.find(configIgnore, id) and not v.disableOnLeave then
            config[id] = { Enabled = v.api.enabled, Keybind = v.api.keybind, Type = v.type, Window = v.window }
        elseif v.type == 'Toggle' and not table.find(configIgnore, id) then
            config[id] = { Enabled = v.api.enabled, Type = v.type, Module = v.module, Window = v.window }
        elseif v.type == 'Slider' and not table.find(configIgnore, v.module) then
            config[id] = { Value = v.api.value == math.huge and 'inf' or v.api.value, Type = v.type, Module = v.module, Window = v.window }
        elseif v.type == 'Selector' and not table.find(configIgnore, v.module) then
            config[id] = { Value = v.api.value, Type = v.type, Module = v.module, Window = v.window }
        elseif v.type == 'Textbox' and not table.find(configIgnore, v.module) then
            config[id] = { Value = v.api.value, Type = v.type, Module = v.module, Window = v.window }
        end
    end

    local guiConfig = {
        hudEnabled = self.hudEnabled,
        colorTheme = self.colorTheme,
        rainbow = self.rainbow,
        rainbowSpeed = self.rainbowSpeed,
        clickSounds = self.clickSounds,
        arrayListEnabled = self.arrayListEnabled,
        listBackground = self.listBackground,
        listLines = self.listLines,
        drawWatermark = self.drawWatermark,
        watermarkLine = self.watermarkLine,
        watermarkBackground = self.watermarkBackground,
        drawCoords = self.drawCoords,
        drawSpeed = self.drawSpeed,
        drawFPS = self.drawFPS,
        drawPing = self.drawPing,
        font = Enum.Font.GothamSemibold.Name,
        textSize = self.textSize
    }

    local placeId = tostring(game.PlaceId)
    makefolder('Configs')
    makefolder('Configs/' .. placeId)

    local path = 'Configs/' .. placeId .. '/' .. name .. '.json'
    local guiPath = 'Configs/GUIconfig.json'

    if isfile(path) then delfile(path) end
    writefile(path, HttpService:JSONEncode(config))

    if isfile(guiPath) then delfile(guiPath) end
    writefile(guiPath, HttpService:JSONEncode(guiConfig))
end

function gui:LoadConfig(name)
    name = name or 'default'
    local placeId = tostring(game.PlaceId)
    local path = 'Configs/' .. placeId .. '/' .. name .. '.json'

    if not isfile(path) then
        return
    end

    local ok, config = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok then
        warn('[future] [gui.LoadConfig] failed to load config "' .. name .. '"')
        return
    end

    for id, v in next, self.objects do
        if v.type == 'Module' and not table.find(configIgnore, id) and v.api.enabled then
            v.api.Toggle(false)
        end

        if v.type == 'Toggle' and not table.find(configIgnore, id) and v.api.enabled then
            v.api.Toggle(false, true)
        end
    end

    for id, v in next, config do
        local obj = self.objects[id]
        if not obj then continue end

        local api = obj.api

        if v.Type == 'Module' and obj.window == v.Window and not table.find(configIgnore, id) then
            if v.Enabled then api.Toggle(true, false, false) end
            api.SetKeybind(v.Keybind)
        elseif v.Type == 'Toggle' and obj.module == v.Module and not table.find(configIgnore, id) then
            if v.Enabled then api.Toggle(true, true) end
        elseif v.Type == 'Slider' and obj.module == v.Module and not table.find(configIgnore, v.Module) then
            api.Set(tonumber(v.Value), true)
        elseif v.Type == 'Selector' and obj.module == v.Module and not table.find(configIgnore, v.Module) then
            api.Select(v.Value)
        elseif v.Type == 'Textbox' and obj.module == v.Module and not table.find(configIgnore, v.Module) then
            api.Set(v.Value)
        end
    end

    self:LoadGUIConfig()
end

function gui:LoadGUIConfig()
    local path = 'Configs/GUIconfig.json'
    if not isfile(path) then
        return
    end

    local ok, config = pcall(function()
        return HttpService:JSONDecode(readfile(path))
    end)

    if not ok then
        warn('[future] [gui.LoadGUIConfig] failed to load gui config')
        return
    end

    for k, v in next, config do
        if k == 'font' then
            Enum.Font.GothamSemibold = Enum.Font[v]
        else
            self[k] = v
        end
    end

    self:UpdateHUD()
end

function gui:CreateWindow(name)
    local api = {
        expanded = true,
        expand = function() end
    }

    local window = self:Create('Frame', {
        Name = name .. 'Window',
        BackgroundColor3 = Color3.fromRGB(10, 10, 10),
        BackgroundTransparency = 0.45,
        BorderSizePixel = 0,
        Position = UDim2.new(0, self.nextWindowPos, 0, 25),
        Size = UDim2.new(0, 176, 0, 222),
        Parent = self.clickUI
    })

    self.nextWindowPos = self.nextWindowPos + 179

    local topbar = self:Create('TextButton', {
        Name = 'WindowTopbar',
        Modal = true,
        BackgroundColor3 = self:GetColor(),
        BorderSizePixel = 0,
        Position = UDim2.new(-0.000213969834, 0, -0.00245500472, 0),
        Size = UDim2.new(0, 176, 0, 27),
        AutoButtonColor = false,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        Parent = window
    })

    self.signals.updateColor:Connect(function(color)
        topbar.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    self:Create('TextLabel', {
        Name = 'WindowTitle',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 6, 0.5, 0),
        Size = UDim2.new(0, 130, 0, 20),
        Font = Enum.Font.GothamSemibold,
        Text = name,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = topbar
    })

    local expandButton = self:Create('ImageButton', {
        Name = 'Expand',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -14, 0.5, 1),
        Size = UDim2.new(0, 20, 0, 19),
        ZIndex = 1,
        Image = 'rbxassetid://8904422926',
        ImageColor3 = Color3.fromRGB(0, 0, 0),
        ScaleType = Enum.ScaleType.Fit,
        Rotation = 0,
        Parent = topbar
    })

    local buttonContainer = self:Create('Frame', {
        Name = 'ButtonContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 48),
        Size = UDim2.new(0, 175, 0, 30),
        Parent = window
    })

    local layout = self:Create('UIListLayout', {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = buttonContainer
    })

    local nextModuleOrder = 0
    local function nextOrder()
        nextModuleOrder += 2
        return nextModuleOrder
    end

    function api.Update()
        window.Size = not api.expanded
            and UDim2.new(0, 176, 0, 35)
            or UDim2.new(0, 176, 0, layout.AbsoluteContentSize.Y + 37)
    end

    function api.Expand(bool)
        api.expanded = bool ~= nil and bool or not api.expanded
        buttonContainer.Visible = api.expanded
        api.Update()
        gui:PlayClickSound()
    end

    expandButton.MouseButton1Click:Connect(api.Expand)
    topbar.MouseButton2Click:Connect(api.Expand)
    gui:Dragify(window, topbar)

    self:Connect(layout:GetPropertyChangedSignal('AbsoluteContentSize'), api.Update)

    api.Update()

    self.objects[name .. 'Window'] = {
        api = api,
        instance = window,
        type = 'Window'
    }

    local methods = {}

    function methods:AddModule(args)
        return gui:AddModule(args, window, buttonContainer, api, nextOrder())
    end

    return methods
end

function gui:AddModule(args, window, parent, api, order)
    local api = {
        enabled = false,
        expanded = false,
        keybind = args.DefaultKeybind or nil,
        recording = false
    }

    local button = self:Create('TextButton', {
        Name = args.Name .. 'OptionsButton',
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = 0.85,
        BorderSizePixel = 0,
        AnchorPoint = Vector2.new(0.5, 0),
        Position = UDim2.new(0.5, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = false,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        LayoutOrder = order,
        Parent = parent
    })

    self.signals.updateColor:Connect(function(color)
        button.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    self:Create('TextLabel', {
        Name = 'Name',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.035, 0, 0.5, 0),
        Size = UDim2.new(0, 114, 0, 23),
        Font = Enum.Font.GothamSemibold,
        Text = args.Name,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = button
    })

    local gear = self:Create('ImageButton', {
        Name = 'Gear',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(1, -23, 0.5, 0),
        Size = UDim2.new(0, 19, 0, 19),
        Image = 'rbxassetid://8905804106',
        ImageColor3 = Color3.fromRGB(181, 181, 181),
        Parent = button
    })

    local childrenContainer = self:Create('Frame', {
        Name = args.Name .. 'ChildrenContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, 0, 48),
        Size = UDim2.new(0, 175, 0, 30),
        LayoutOrder = order + 1,
        Visible = false,
        Parent = parent
    })

    local childrenLayout = self:Create('UIListLayout', {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Padding = UDim.new(0, 1),
        Parent = childrenContainer
    })

    local moduleContainer = self:Create('Frame', {
        Name = 'ModuleContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.5, 0, -0.1, 48),
        Size = UDim2.new(0, 175, 0, 90),
        Parent = childrenContainer
    })

    local moduleLayout = self:Create('UIListLayout', {
        HorizontalAlignment = Enum.HorizontalAlignment.Center,
        SortOrder = Enum.SortOrder.LayoutOrder,
        Parent = moduleContainer
    })

    local keybindButton = self:Create('TextButton', {
        Name = 'Keybind',
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = true,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        BackgroundColor3 = self:GetColor(),
        Parent = childrenContainer
    })

    self.signals.updateColor:Connect(function(color)
        keybindButton.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    local keybindContainer = self:Create('Frame', {
        Name = 'KeybindContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 158, 0, 30),
        Parent = keybindButton
    })

    self:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = keybindContainer
    })

    local keybindLabel = self:Create('TextLabel', {
        Name = 'Name',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 76, 0, 23),
        Font = Enum.Font.GothamSemibold,
        RichText = true,
        Text = 'Keybind <font color=\'rgb(170, 170, 170)\'>NONE</font>',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = keybindContainer
    })

    keybindButton.MouseButton1Click:Connect(function()
        gui:PlayClickSound()

        if not api.recording then
            api.recording = true
            keybindLabel.Text = 'Press a Key...'
            keybindButton.BackgroundTransparency = 0
        else
            api.recording = false
            api.SetKeybind(api.keybind)
            keybindButton.BackgroundTransparency = 1
        end
    end)

    self:Connect(InputService.InputBegan, function(input)
        if api.recording and not InputService:GetFocusedTextBox() and input.KeyCode.Name ~= 'Unknown' then
            api.recording = false
            keybindButton.BackgroundTransparency = 1

            if input.KeyCode.Name == 'Escape' then
                moduleApi.SetKeybind(args.DefaultKeybind)
            elseif input.KeyCode.Name == moduleApi.keybind then
                moduleApi.SetKeybind(nil)
            else
                moduleApi.SetKeybind(input.KeyCode.Name)
            end

            return
        end

        if input.KeyCode.Name == api.keybind and not InputService:GetFocusedTextBox() then
            api.Toggle(nil, false, true, true)
        end
    end)

    function api.Update()
        moduleContainer.Size = not api.expanded
            and UDim2.new(0, 175, 0, 35)
            or UDim2.new(0, 175, 0, moduleLayout.AbsoluteContentSize.Y - 1)

        childrenContainer.Size = not api.expanded
            and UDim2.new(0, 175, 0, 35)
            or UDim2.new(0, 175, 0, childrenLayout.AbsoluteContentSize.Y)
    end

    function api.Expand(bool)
        api.expanded = bool ~= nil and bool or not api.expanded
        childrenContainer.Visible = api.expanded
        api.Update()
        gui:PlayClickSound()
    end

    function api.Toggle(bool, skipSound, isConfigLoad, viaKeybind)
        if isFunctionEmpty(args.Function) then
            gui:Notify(args.Name, 'This module has not been implemented yet.', 1.5)
            return
        end

        local doToggle = bool ~= nil and bool or not api.enabled
        button.BackgroundTransparency = doToggle and 0.35 or 0.85
        api.enabled = doToggle

        args.Function(doToggle)
        gui:UpdateHUD()

        if not skipSound then
            gui:PlayClickSound()
        end

        if viaKeybind and not table.find(configIgnore, button.Name) then
            local state = doToggle
                and '<font color=\'rgb(85, 255, 85)\'>enabled</font>'
                or '<font color=\'rgb(255, 85, 85)\'>disabled</font>'

            gui:Notify('Module toggled', args.Name .. ' has been ' .. state .. '.', 0.65)
        end
    end

    function api.SetKeybind(key)
        api.keybind = key or args.DefaultKeybind

        if keybindLabel then
            keybindLabel.Text = 'Keybind <font color=\'rgb(170, 170, 170)\'>' .. (key or 'NONE') .. '</font>'
        end

        if args.OnKeybound then
            args.OnKeybound(key)
        end
    end

    if args.Default ~= nil and args.Default then
        api.Toggle(args.Default, false, false)
    end

    button.MouseButton1Click:Connect(api.Toggle)
    button.MouseButton2Click:Connect(api.Expand)

    gear.MouseButton1Click:Connect(api.Expand)

    self:Connect(moduleLayout:GetPropertyChangedSignal('AbsoluteContentSize'), api.Update)
    self:Connect(childrenLayout:GetPropertyChangedSignal('AbsoluteContentSize'), api.Update)

    self.objects[button.Name] = {
        name = args.Name,
        api = api,
        instance = button,
        type = 'Module',
        window = window.Name,
        disableOnLeave = args.DisableOnLeave,
        arrayText = args.ArrayText
    }

    local methods = {}

    function methods:AddToggle(args)
        return gui:AddToggle(args, button, moduleContainer, window)
    end

    function methods:AddSlider(args)
        return gui:AddSlider(args, button, moduleContainer, window)
    end

    function methods:AddSelector(args)
        return gui:AddSelector(args, button, moduleContainer, window)
    end

    function methods:AddTextbox(args)
        return gui:AddTextbox(args, button, moduleContainer, window)
    end

    return methods
end

function gui:AddToggle(args, parent, container, window)
    local api = { enabled = false }

    local toggle = self:Create('TextButton', {
        Name = 'Toggle' .. args.Name,
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = false,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    self.signals.updateColor:Connect(function(color)
        toggle.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    self:Create('TextLabel', {
        Name = 'Name',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.035, 0, 0.5, 0),
        Size = UDim2.new(0, 114, 0, 23),
        Font = Enum.Font.GothamSemibold,
        Text = args.Name,
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = toggle
    })

    function api.Toggle(bool, skipSound)
        local doToggle = bool ~= nil and bool or not api.enabled
        toggle.BackgroundTransparency = doToggle and 0.35 or 1
        api.enabled = doToggle

        args.Function(doToggle)

        if not skipSound then
            gui:PlayClickSound()
        end
    end

    if args.Default then
        api.Toggle(args.Default, true)
    end

    toggle.MouseButton1Click:Connect(api.Toggle)

    self.objects[parent.Name .. args.Name .. 'Toggle'] = {
        api = api,
        instance = toggle,
        type = 'Toggle',
        module = parent.Name,
        window = window.Name
    }

    return api
end

function gui:AddSlider(args, parent, container, window)
    local api = { value = args.Default or args.Min }
    local min, max, roundVal = args.Min, args.Max, args.Round or 1

    local slider = self:Create('TextButton', {
        Name = args.Name .. 'Slider',
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = false,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        Parent = container
    })

    local fill = self:Create('Frame', {
        Name = 'SliderFill',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 50, 0, 30),
        Parent = slider
    })

    self.signals.updateColor:Connect(function(color)
        fill.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    local sliderContainer = self:Create('Frame', {
        Name = 'SliderContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 158, 0, 30),
        Parent = slider
    })

    self:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = sliderContainer
    })

    local nameLabel = self:Create('TextLabel', {
        Name = 'Name',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        RichText = true,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 61, 0, 23),
        Font = Enum.Font.GothamSemibold,
        Text = args.Name .. ' <font color=\'rgb(170, 170, 170)\'>' .. tostring(api.value) .. '</font>',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = sliderContainer
    })

    local inputButton = self:Create('TextButton', {
        Name = 'InputTextbox',
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = false,
        Text = '',
        TextSize = self.textSize,
        Visible = false,
        Parent = container
    })

    local realInput = self:Create('TextBox', {
        Name = 'RealTextbox',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.518, 0, 0.5, 0),
        Size = UDim2.new(0, 162, 0, 30),
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold,
        PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
        PlaceholderText = 'Input Value',
        Text = '',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = inputButton
    })

    realInput.FocusLost:Connect(function()
        if tonumber(realInput.Text) then
            api.Set(tonumber(realInput.Text), true)
        end

        realInput.Text = ''
        inputButton.Visible = false
        slider.Visible = true
    end)

    local function doSlide(input)
        local sizeX = math.clamp((input.Position.X - slider.AbsolutePosition.X) / slider.AbsoluteSize.X, 0, 1)
        fill.Size = UDim2.new(sizeX, 0, 1, 0)

        local value = math.floor((((max - min) * sizeX + min) * (10 ^ roundVal)) + 0.5) / (10 ^ roundVal)
        api.value = value

        nameLabel.Text = args.Name .. ' <font color=\'rgb(170, 170, 170)\'>' .. tostring(value) .. '</font>'

        if not args.OnInputEnded then
            args.Function(value)
        end
    end

    local sliding = false

    slider.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        if InputService:IsKeyDown(Enum.KeyCode.LeftShift) then
            inputButton.Visible = true
            slider.Visible = false

            realInput:CaptureFocus()
            return
        end

        sliding = true
        doSlide(input)
        gui:PlayClickSound()
    end)

    slider.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 then
            return
        end

        if args.OnInputEnded then
            args.Function(api.value)
        end

        sliding = false
    end)

    self:Connect(InputService.InputChanged, function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement and sliding then
            doSlide(input)
        end
    end)

    function api.Set(value, useOverMax)
        value = not useOverMax
            and math.floor((math.clamp(value, min, max) * (10 ^ roundVal)) + 0.5) / (10 ^ roundVal)
            or math.clamp(value, args.RealMin or -math.huge, args.RealMax or math.huge)

        api.value = value

        local displayVal = math.floor((math.clamp(value, min, max) * (10 ^ roundVal)) + 0.5) / (10 ^ roundVal)
        fill.Size = UDim2.new((displayVal - min) / (max - min), 0, 1, 0)

        nameLabel.Text = args.Name .. ' <font color=\'rgb(170, 170, 170)\'>' .. tostring(value) .. '</font>'
        args.Function(value)
    end

    api.Set(api.value)

    self.objects[parent.Name .. args.Name .. 'Slider'] = {
        api = api,
        instance = slider,
        type = 'Slider',
        module = parent.Name,
        window = window.Name
    }

    return api
end

function gui:AddSelector(args, parent, container, window)
    local api = { value = nil, list = {} }

    for _, v in next, args.List do
        table.insert(api.list, v)
    end

    api.value = args.Default or api.list[1]

    local function findByValue(val)
        for i, v in next, api.list do
            if tostring(v) == tostring(val) then
                return i
            end
        end
    end

    local function clampIndex(i)
        if i > #api.list then return 1 end
        if i < 1 then return #api.list end
        return i
    end

    local selector = self:Create('TextButton', {
        Name = args.Name .. 'Selector',
        BackgroundColor3 = self:GetColor(),
        BackgroundTransparency = 0.35,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        AutoButtonColor = true,
        Text = '',
        TextColor3 = Color3.fromRGB(0, 0, 0),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    self.signals.updateColor:Connect(function(color)
        selector.BackgroundColor3 = Color3.fromHSV(color.H, color.S, color.V)
    end)

    local selectorContainer = self:Create('Frame', {
        Name = 'SelectorContainer',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 158, 0, 30),
        Parent = selector
    })

    self:Create('UIListLayout', {
        FillDirection = Enum.FillDirection.Horizontal,
        SortOrder = Enum.SortOrder.LayoutOrder,
        VerticalAlignment = Enum.VerticalAlignment.Center,
        Parent = selectorContainer
    })

    local nameLabel = self:Create('TextLabel', {
        Name = 'Name',
        AnchorPoint = Vector2.new(0, 0.5),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0, 0, 0.5, 0),
        Size = UDim2.new(0, 76, 0, 23),
        Font = Enum.Font.GothamSemibold,
        RichText = true,
        Text = args.Name .. ' <font color=\'rgb(170, 170, 170)\'>' .. tostring(api.value) .. '</font>',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = selectorContainer
    })

    function api.Select(key)
        local idx = api.list[key] and key or findByValue(key)
        if not idx then return end
        api.value = api.list[idx]
        nameLabel.Text = args.Name .. ' <font color=\'rgb(170, 170, 170)\'>' .. tostring(api.value) .. '</font>'
        args.Function(api.value)
    end

    function api.SelectNext()
        local idx = findByValue(api.value)
        if idx then api.Select(clampIndex(idx + 1)) end
        gui:PlayClickSound()
    end

    function api.SelectPrevious()
        local idx = findByValue(api.value)
        if idx then api.Select(clampIndex(idx - 1)) end
        gui:PlayClickSound()
    end

    api.Select(api.value)

    selector.MouseButton1Click:Connect(api.SelectNext)
    selector.MouseButton2Click:Connect(api.SelectPrevious)

    self.objects[parent.Name .. args.Name .. 'Selector'] = {
        api = api,
        instance = selector,
        type = 'Selector',
        module = parent.Name,
        window = window.Name
    }

    return api
end

function gui:AddTextbox(args, parent, container, window)
    local api = { value = '' }

    local container = self:Create('Frame', {
        Name = args.Name .. 'Textbox',
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Position = UDim2.new(0.017, 0, 0, 0),
        Size = UDim2.new(0, 168, 0, 30),
        Parent = container
    })

    local input = self:Create('TextBox', {
        Name = 'RealTextbox',
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundTransparency = 1,
        Position = UDim2.new(0.518, 0, 0.5, 0),
        Size = UDim2.new(0, 162, 0, 30),
        ClearTextOnFocus = false,
        Font = Enum.Font.GothamSemibold,
        PlaceholderColor3 = Color3.fromRGB(170, 170, 170),
        PlaceholderText = args.Name,
        Text = '',
        TextColor3 = Color3.fromRGB(255, 255, 255),
        TextSize = self.textSize,
        TextTruncate = Enum.TextTruncate.AtEnd,
        TextXAlignment = Enum.TextXAlignment.Left,
        Parent = container
    })

    function api.Set(value, skipFunction)
        value = tostring(value)
        api.value = value
        input.Text = value
        if not skipFunction then
            args.Function(value)
        end
    end

    api.Set(args.Default or '', true)

    input.FocusLost:Connect(function()
        api.Set(input.Text)
    end)

    self.objects[parent.Name .. args.Name .. 'Textbox'] = {
        api = api,
        instance = container,
        type = 'Textbox',
        module = parent.Name,
        window = window.Name
    }

    return api
end

function gui:UpdateWindows()
    for _, v in next, self.objects do
        if v.type ~= 'Window' then
            continue
        end

        v.api.Update()
    end
end

function gui:SetDebugging(debugging)
    self.debugging = debugging
end

return gui
