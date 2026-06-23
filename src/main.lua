local cloneref = cloneref or function(instance)
    return instance
end

local HttpService = cloneref(game:GetService('HttpService'))
local Players = cloneref(game:GetService('Players'))

local localPlayer = Players.LocalPlayer

local startLoadAt = tick();

local future = {}
getgenv().future = future

local gui = fetchScript('gui')
gui:Start()

future.combat = gui:CreateWindow('Combat')
future.exploits = gui:CreateWindow('Exploits')
future.misc = gui:CreateWindow('Miscellaneous')
future.movement = gui:CreateWindow('Movement')
future.render = gui:CreateWindow('Render')
future.world = gui:CreateWindow('World')

future.gui = gui

do
    local other = gui:CreateWindow('Other')

    other:AddModule({
        Name = 'ClickSounds',
        Default = true,
        Function = function(callback)
            gui.clickSounds = callback
        end
    })

    other:AddModule({
        Name = 'ArrayList',
        Default = true,
        Function = function(callback)
            gui.arrayListEnabled = callback
            gui.signals.hudUpdate:Fire()
        end
    })
end

fetchScript('games/universal')

local gameList = fetchScript('games.json', true)

local suc, res = pcall(HttpService.JSONDecode, HttpService, gameList)
if not suc then
    gui:Notify('Future Client', 'Failed to load game list', 6)
end

local scriptName = res[tostring(game.PlaceId)]
if scriptName then
    fetchScript('games/' .. scriptName)
end

gui:Notify(
    'Future Client',
    'Finished loading in ' .. string.format('%.02f seconds', tick() - startLoadAt) .. '\nPress Right Control to toggle the UI',
    6
)

local executed = false

gui:Connect(localPlayer.OnTeleport, function(state)
    if executed or state ~= Enum.TeleportState.InProgress then
        return
    end

    executed = true

    queueonteleport([[
        if future_dev then
            getgenv().future_dev = true
        end

        loadstring(game:HttpGet('https://raw.githubusercontent.com/femrawr/FutureClientForRoblox/refs/heads/main/src/loader.lua', true))()
    ]])
end)
