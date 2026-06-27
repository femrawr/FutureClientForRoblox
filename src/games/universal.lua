local cloneref = cloneref or function(instance)
    return instance
end

local RunService = cloneref(game:GetService('RunService'))
local InputService = cloneref(game:GetService('UserInputService'))
local Players = cloneref(game:GetService('Players'))
local Lighting = cloneref(game:GetService('Lighting'))

local Maid = fetchScript('classes/maid')

local playerUtils = fetchScript('utils/player')

local localPlayer = Players.LocalPlayer

local maid = Maid.new()

do
    local mode
    local speed
    local airOnly

    local spinbot = future.movement:AddModule({
        Name = 'SpinBot',
        Function = function(callback)
            if not callback then
                maid.spinbot = nil
                return
            end

            maid.spinbot = RunService.Stepped:Connect(function()
                local root, hum = playerUtils.getRoot()
                if not root then return end

                if airOnly.enabled and hum and hum.FloorMaterial ~= Enum.Material.Air then
                    return
                end

                if mode.value == 'Velocity' then
                    local oldVelocity = root.AssemblyAngularVelocity
                    root.AssemblyAngularVelocity = Vector3.new(oldVelocity.X, speed.value, oldVelocity.Z)
                else
                    local spin = (tick() * speed.value * 10) % 360
                    root.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, math.rad(spin), 0)
                end
            end)
        end
    })

    mode = spinbot:AddSelector({
        Name = 'Mode',
        List = { 'CFrame', 'Velocity' },
        Default = 'CFrame',
        Function = function() end
    })

    speed = spinbot:AddSlider({
        Name = 'Speed',
        Min = 1,
        Max = 360,
        Default = 90,
        Function = function() end
    })

    airOnly = spinbot:AddToggle({
        Name = 'AirOnly',
        Default = false,
        Function = function() end
    })
end

do
    local range
    local smoothness
    local aiming
    local selection
    local part
    local circle
    local mouse
    local ignoreFriends
    local healthCheck
    local teamCheck
    local invisCheck
    local shieldCheck
    local wallCheck
    local focusTarget
    local prediction
    local predictionMode

    local fovCircle = future.gui:Create('Circle', {
        Transparency = 1,
        Color = future.gui:GetColor(),
        Radius = 100,
        Thickness = 1,
        Visible = false
    })

    local aimbot = future.combat:AddModule({
        Name = 'Aimbot',
        Function = function(callback)
            if not callback then
                maid.aimbot = nil
                fovCircle.Visible = false
                return
            end

            maid.aimbot = RunService.RenderStepped:Connect(function()
                local mousePos = InputService:GetMouseLocation()

                fovCircle.Visible = circle.enabled and selection.value == 'Mouse'
                fovCircle.Radius = range.value
                fovCircle.Position = mousePos

                local mouseDown = InputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2)
                if not mouseDown and mouse.enabled then return end

                local target = playerUtils[selection.value == 'Mouse' and 'getCloseToMouse' or 'getCloseToRoot'](range.value, {
                    health = healthCheck.enabled,
                    team = teamCheck.enabled,
                    invis = invisCheck.enabled,
                    shield = shieldCheck.enabled,
                    wall = wallCheck.enabled
                })

                if not target then return end

                local character = target.Character
                if not character then return end

                local camera = workspace.CurrentCamera
                if not camera then return end

                local targetPart = part.value == 'Closest'
                    and playerUtils.getPartCloseToMouse(character, mousePos)
                    or character:FindFirstChild(part.value == 'Head' and 'Head' or 'HumanoidRootPart')

                if not targetPart then return end

                if aiming.value == 'Mouse' then
                    local vector, visible = camera:WorldToViewportPoint(targetPart.Position)
                    if not visible then return end

                    vector = Vector2.new(vector.X, vector.Y)

                    local final = (vector - mousePos) / smoothness.value
                    mousemoverel(final.X, final.Y)
                else
                    camera.CFrame = camera.CFrame:Lerp(
                        CFrame.lookAt(camera.CFrame.Position, targetPart.Position),
                        1 / smoothness.value
                    )
                end
            end)
        end,
        ArrayText = function()
            return part.value
        end
    })

    range = aimbot:AddSlider({
        Name = 'Range',
        Min = 20,
        Max = 500,
        Default = 250,
        Function = function() end
    })

    smoothness = aimbot:AddSlider({
        Name = 'Smoothness',
        Min = 1,
        Max = 20,
        Default = 1,
        Function = function() end
    })

    aiming = aimbot:AddSelector({
        Name = 'AimWith',
        List = { 'Mouse', 'Camera' },
        Default = 'Mouse',
        Function = function() end
    })

    selection = aimbot:AddSelector({
        Name = 'Selection',
        List = { 'Mouse', 'Position' },
        Default = 'Mouse',
        Function = function() end
    })

    part = aimbot:AddSelector({
        Name = 'Target',
        List = { 'Head', 'Root', 'Closest' },
        Default = 'Head',
        Function = function(val)
            if not aimbot.enabled then
                return
            end

            aimbot.Toggle(nil, true)
            aimbot.Toggle(nil, true)
        end
    })

    circle = aimbot:AddToggle({
        Name = 'DrawCircle',
        Default = true,
        Function = function() end
    })

    mouse = aimbot:AddToggle({
        Name = 'RequireRightClick',
        Default = true,
        Function = function() end
    })

    ignoreFriends = aimbot:AddToggle({
        Name = 'IgnoreFriends',
        Default = false,
        Function = function() end
    })

    healthCheck = aimbot:AddToggle({
        Name = 'IgnoreDead',
        Default = false,
        Function = function() end
    })

    teamCheck = aimbot:AddToggle({
        Name = 'IgnoreTeam',
        Default = false,
        Function = function() end
    })

    invisCheck = aimbot:AddToggle({
        Name = 'IgnoreInvisibles',
        Default = false,
        Function = function() end
    })

    shieldCheck = aimbot:AddToggle({
        Name = 'IgnoreShieldeds',
        Default = false,
        Function = function() end
    })

    wallCheck = aimbot:AddToggle({
        Name = 'IgnoreBehindWalls',
        Default = false,
        Function = function() end
    })

    focusTarget = aimbot:AddToggle({
        Name = 'FocusTarget',
        Default = false,
        Function = function() end
    })

    prediction = aimbot:AddToggle({
        Name = 'Prediction',
        Default = false,
        Function = function() end
    })

    predictionMode = aimbot:AddSelector({
        Name = 'PredictionMode',
        List = { 'MoveDirection', 'Velocity' },
        Default = 'MoveDirection',
        Function = function() end
    })
end

do
    local range
    local ignoreTeam
    local useTeamColor

    local esp = future.render:AddModule({
        Name = 'ESP',
        Function = function(callback)

        end
    })

    range = esp:AddSlider({
        Name = 'Range',
        Min = 10,
        Max = 1000,
        Default = 1000,
        Function = function(val)
            if val == 1000 then
                val = math.huge
            end
        end
    })

    ignoreTeam = esp:AddToggle({
        Name = 'IgnoreTeam',
        Default = true,
        Function = function() end
    })

    useTeamColor = esp:AddToggle({
        Name = 'UseTeamColor',
        Default = true,
        Function = function() end
    })
end

do
    local fov

    local oldFOV

    local fovChanger = future.render:AddModule({
        Name = 'FOVModifier',
        Function = function(callback)
            if not callback then
                maid.fov = nil

                local camera = workspace.CurrentCamera
                if oldFOV and camera then
                    camera.FieldOfView = oldFOV
                end

                return
            end

            maid.fov = RunService.RenderStepped:Connect(function()
                local camera = workspace.CurrentCamera
                if not camera then return end

                if not oldFOV then
                    oldFOV = camera.FieldOfView
                    print(oldFOV)
                end

                camera.FieldOfView = fov.value
            end)
        end
    })

    fov = fovChanger:AddSlider({
        Name = 'FOV',
        Min = 1,
        Max = 120,
        Default = 90,
        Function = function() end
    })
end

do
    local mode
    local speed
    local noDrift

    local vertical = 0

    local flight = future.movement:AddModule({
        Name = 'Flight',
        Function = function(callback)
            if not callback then
                maid.fly = nil
                maid.flyMover = nil
                return
            end

            maid.fly = RunService.Stepped:Connect(function(dt)
                local root, hum = playerUtils.getRoot()
                if not root or not hum then return end

                if InputService:IsKeyDown(Enum.KeyCode.LeftControl) and not InputService:GetFocusedTextBox() then
                    vertical = -1
                elseif InputService:IsKeyDown(Enum.KeyCode.Space) and not InputService:GetFocusedTextBox() then
                    vertical = 1
                else
                    vertical = 0
                end

                local realSpeed = speed.value * (mode.value == 'Velocity' and 2 or 0.005)
                local moveDirection = Vector3.new(hum.MoveDirection.X, vertical, hum.MoveDirection.Z)

                if noDrift.enabled then
                    maid.flyMover = maid.flyMover or cloneref(Instance.new('BodyVelocity'))
                    maid.flyMover.MaxForce = Vector3.one * math.huge
                    maid.flyMover.Velocity = Vector3.new(hum.MoveDirection.X, vertical, hum.MoveDirection.Z) * realSpeed
                    maid.flyMover.Parent = root
                else
                    if maid.flyMover then maid.flyMover = nil end
                end

                if mode.value == 'Velocity' then
                    root.AssemblyLinearVelocity = moveDirection * realSpeed
                else
                    root.AssemblyLinearVelocity = Vector3.zero
                    root.CFrame += moveDirection * realSpeed * dt
                end
            end)
        end
    })

    mode = flight:AddSelector({
        Name = 'Mode',
        List = { 'Velocity', 'CFrame' },
        Default = 'Velocity',
        Function = function() end
    })

    speed = flight:AddSlider({
        Name = 'Speed',
        Min = 1,
        Max = 360,
        Default = 90,
        Function = function() end
    })

    noDrift = flight:AddToggle({
        Name = 'NoDrift',
        Default = false,
        Function = function() end
    })
end

do
    local pakour = future.movement:AddModule({
        Name = 'Pakour',
        Function = function(callback)

        end
    })
end

do
    local connections = {}

    future.misc:AddModule({
        Name = 'AntiAFK',
        Function = function(callback)
            if not callback then
                for _, v in connections do
                    pcall(v.Enable, v)
                end

                table.clear(connections)
                return
            end

            for _, v in next, getconnections(localPlayer.Idled) do
                if not v.Function then
                    continue
                end

                table.insert(connections, v)
                pcall(v.Disable, v)
            end
        end
    })
end

do
    local cleanup = {
        Brightness = nil,
        GlobalShadows = nil,
        ClockTime = nil
    }

    future.render:AddModule({
        Name = 'Fullbright',
        Function = function(callback)
            if not callback then
                maid.brightness = nil

                for i, v in next, cleanup do
                    Lighting[i] = v
                    v = nil
                end

                return
            end

            for i in next, cleanup do
                cleanup[i] = Lighting[i]
            end

            maid.brightness = RunService.RenderStepped:Connect(function()
                Lighting.Brightness = 2
                Lighting.GlobalShadows = false
                Lighting.ClockTime = 14
            end)
        end
    })
end

do
    local midClick = future.misc:AddModule({
        Name = 'MiddleClick',
        Function = function(callback)

        end
    })
end

do
    local noFall = future.movement:AddModule({
        Name = 'NoFall',
        Function = function(callback)

        end
    })
end

do
    local mode
    local speed

    local goFast = future.movement:AddModule({
        Name = 'Speed',
        Function = function(callback)
            if not callback then
                maid.speed = nil
                return
            end

            maid.speed = RunService.Stepped:Connect(function(dt)
                local root, hum = playerUtils.getRoot()
                if not root or not hum then return end

                local realSpeed = speed.value * (mode.value == 'Velocity' and 2 or 0.005)

                if mode.value == 'Velocity' then
                    local oldVelocity = root.AssemblyLinearVelocity

                    root.AssemblyLinearVelocity = Vector3.new(
                        hum.MoveDirection.X * realSpeed,
                        oldVelocity.Y,
                        hum.MoveDirection.Z * realSpeed
                    )
                else
                    root.CFrame += hum.MoveDirection * realSpeed * dt
                end
            end)
        end
    })

    mode = goFast:AddSelector({
        Name = 'Mode',
        List = { 'Velocity', 'CFrame' },
        Default = 'Velocity',
        Function = function() end
    })

    speed = goFast:AddSlider({
        Name = 'Speed',
        Min = 1,
        Max = 500,
        Default = 90,
        Function = function() end
    })
end

do
    local intensity

    local antiAim = future.misc:AddModule({
        Name = 'AntiAim',
        Function = function(callback)

        end
    })

    intensity = antiAim:AddSlider({
        Name = 'Intensity',
        Min = 1,
        Max = 100,
        Default = 50,
        Function = function() end
    })
end

do
    local speed
    local instant

    local step = future.movement:AddModule({
        Name = 'Step',
        Function = function(callback)

        end
    })

    speed = step:AddSlider({
        Name = 'Speed',
        Min = 1,
        Max = 100,
        Default = 50,
        Function = function() end
    })

    instant = step:AddToggle({
        Name = 'Instant',
        Default = true,
        Function = function() end
    })
end

do
    local fps
    local noRender

    local oldFPS = nil

    local unfocusedFPS = future.misc:AddModule({
        Name = 'UnfocusedFPS',
        Function = function(callback)
            if not callback then
                maid.unfocusedFPS = nil
                oldFPS = nil

                RunService:Set3dRenderingEnabled(true)
                return
            end

            maid.unfocusedFPS = task.spawn(function()
                while task.wait() do
                    if iswindowactive then
                        if oldFPS then
                            setfpscap(oldFPS)
                            oldFPS = nil
                        end

                        if noRender.value then
                            RunService:Set3dRenderingEnabled(true)
                        end

                        continue
                    end

                    if not oldFPS then
                        oldFPS = getfpscap()
                    end

                    setfpscap(fps.value)

                    if noRender.enabled then
                        RunService:Set3dRenderingEnabled(false)
                    end
                end
            end)
        end
    })

    fps = unfocusedFPS:AddSlider({
        Name = 'FPSCap',
        Min = 1,
        Max = 120,
        Default = 10,
        Function = function() end
    })

    noRender = unfocusedFPS:AddToggle({
        Name = 'NoRender',
        Default = true,
        Function = function() end
    })
end

do
    local serverHop = future.misc:AddModule({
        Name = 'ServerHop',
        Function = function(callback)

        end
    })
end

do
    local jesus = future.movement:AddModule({
        Name = 'Jesus',
        Function = function(callback)

        end
    })
end

do
    local transparency

    local transitioned = {}

    local xray = future.world:AddModule({
        Name = 'Wallhack',
        Function = function(callback)
            if not callback then

                return
            end


        end
    })

    transparency = xray:AddSlider({
        Name = 'Transparency',
        Min = 1,
        Max = 100,
        Default = 90,
        Function = function() end
    })
end

do
    local speed
    local instant

    local fastFall = future.movement:AddModule({
        Name = 'FastFall',
        Function = function(callback)

        end
    })

    speed = fastFall:AddSlider({
        Name = 'Speed',
        Min = 1,
        Max = 100,
        Default = 50,
        Function = function() end
    })

    instant = fastFall:AddToggle({
        Name = 'Instant',
        Default = false,
        Function = function() end
    })
end

do
    local fakePlayer

    local mode
    local username
    local target
    local fakeList

    local cleanup = {}

    local function cloneDescendants(from, to)
        for _, v in next, from:GetChildren() do
            local clone = v:Clone()
            clone.Parent = to
        end
    end

    fakePlayer = future.misc:AddModule({
        Name = 'FakePlayer',
        Function = function(callback)
            if not callback then
                for _, v in next, cleanup do
                    if not v then continue end
                    pcall(v.Destroy, v)
                end

                return
            end

            local root = playerUtils.getRoot()
            if not root then
                fakePlayer.Toggle()
                return
            end

            if mode.value == 'Spawn' then
                local fakeChar = future.gui:Create('Model', {
                    Parent = workspace
                })

                table.insert(cleanup, fakeChar)

                fakeChar:PivotTo(root.CFrame)
                cloneDescendants(root.Parent, fakeChar)

                local fakeHum = fakeChar:FindFirstChildOfClass('Humanoid')
                if fakeHum and username.value then
                    fakeHum.DisplayName = username.value
                end
            elseif mode.value == 'Transform' then

            else

            end
        end
    })

    mode = fakePlayer:AddSelector({
        Name = 'Mode',
        List = { 'Spawn', 'Transform', 'TransformOther' },
        Default = 'Spawn',
        Function = function() end
    })

    username = fakePlayer:AddTextbox({
        Name = 'Name',
        Default = '',
        Function = function() end
    })

    target = fakePlayer:AddTextbox({
        Name = 'ServerTarget',
        Default = '',
        Function = function() end
    })

    fakeList = fakePlayer:AddToggle({
        Name = 'FakePlayerList',
        Default = true,
        Function = function() end
    })
end
