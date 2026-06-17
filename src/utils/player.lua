local cloneref = cloneref or function(instance)
    return instance
end

local InputService = cloneref(game:GetService('UserInputService'))
local Players = cloneref(game:GetService('Players'))

local Maid = fetchScript('classes/maid')

local localPlayer = Players.LocalPlayer
local camera = workspace.CurrentCamera

local player = {
    maid = Maid.new()
}

function player.getRoot(player)
    local character = (player or localPlayer).Character
    if not character then return end

    local root = character:FindFirstChild('HumanoidRootPart')
    local hum = character:FindFirstChildOfClass('Humanoid')

    return root, hum
end

function player.getCloseToMouse(quota, checks)
    checks = checks or {}

    local myRoot = player.getRoot()
    if not myRoot then return end

    local closest, distance = nil, quota

    for _, v in next, Players:GetPlayers() do
        if v == localPlayer then
            continue
        end

        local otherRoot, otherHum = player.getRoot(v)
        if not otherRoot or not otherHum then continue end

        if checks.health and otherHum.Health <= 0 then continue end
        if checks.team and v.Team == localPlayer.Team then continue end
        if checks.invis and otherRoot.Transparency == 1 then continue end
        if checks.shield and otherRoot.Parent:FindFirstChildWhichIsA('ForceField') then continue end

        if checks.wall and player.isBeingObstructed(myRoot.Position, otherRoot, { myRoot.Parent, camera }) then
            continue
        end

        local screenPos, onScreen = camera:WorldToViewportPoint(otherRoot.Position)
        if not onScreen then continue end

        local mousePos = InputService:GetMouseLocation()

        local difference = (Vector2.new(screenPos.X, screenPos.Y) - mousePos).Magnitude
        if difference >= distance then continue end

        distance = difference
        closest = v
    end

    return closest
end


function player.getCloseToRoot(quota, checks)
    checks = checks or {}

    local myRoot = player.getRoot()
    if not myRoot then return end

    local closest, distance = nil, quota

    for _, v in next, Players:GetPlayers() do
        if v == localPlayer then
            continue
        end

        local otherRoot, otherHum = player.getRoot(v)
        if not otherRoot or not otherHum then continue end

        if checks.health and otherHum.Health <= 0 then continue end
        if checks.team and v.Team == localPlayer.Team then continue end
        if checks.invis and otherRoot.Transparency == 1 then continue end
        if checks.shield and otherRoot.Parent:FindFirstChildWhichIsA('ForceField') then continue end

        if checks.wall and player.isBeingObstructed(myRoot.Position, otherRoot, {myRoot.Parent, camera}) then
            continue
        end

        local difference = (myRoot.Position - v.Character.PrimaryPart.Position).Magnitude
        if difference >= distance then continue end

        distance = difference
        closest = v
    end

    return closest
end

function player.isBeingObstructed(origin, target, ignores)
    origin = typeof(origin) == 'Vector3' and origin or origin.Position
    ignores = typeof(ignores) == 'table' and ignores or { ignores }

    local targetPart = typeof(target) == 'Instance' and target or nil
    local targetPos = typeof(target) == 'Vector3' and target or target.Position

    target = typeof(target) == 'Vector3' and target or target.Position
    ignores = typeof(ignores) == 'table' and ignores or { ignores }

    local direction = targetPos - origin

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = ignores

    local ray = workspace:Raycast(origin, direction, params)
    return ray ~= nil and ray.Instance ~= targetPart
end

function player.start()
    player.maid:GiveTask(workspace:GetPropertyChangedSignal('CurrentCamera'):Connect(function()
        camera = workspace.CurrentCamera or workspace:FindFirstChildWhichIsA('Camera')
    end))
end

function player.unload()
    player.maid:DoCleaning()
end

return player
