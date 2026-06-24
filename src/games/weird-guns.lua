local cloneref = cloneref or function(instance)
    return instance
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local Players = cloneref(game:GetService('Players'))

local Maid = fetchScript('classes/maid')

local localPlayer = Players.LocalPlayer

local remoteHandler = require(ReplicatedStorage.Shared.Remotes)
local removeEvents = require(ReplicatedStorage.Shared.Remotes.RL).EVS

local maid = Maid.new()

local respawnFunc

for _, v in next, getgc() do
    if typeof(v) ~= 'function' then
        continue
    end

    local name = debug.getinfo(v).name

    if name == 'request_spawn' then
        respawnFunc = v
    end
end

do
    local radarRemote = remoteHandler.get_event(removeEvents.RADAR_REVEAL)

    future.render:AddModule({
        Name = 'SpamRadar',
        Function = function(callback)
            if not callback then
                maid.radarSpam = nil
                return
            end

            maid.radarSpam = task.spawn(function()
                while task.wait() do
                    radarRemote:FireServer(Players:GetPlayers())
                end
            end)
        end
    })
end

do
    future.misc:AddModule({
        Name = 'AutoRespawn',
        Function = function(callback)
            if not callback then
                maid.autoRespawn = nil
                return
            end

            maid.autoRespawn = localPlayer.PlayerGui.DeathCamera
                :GetPropertyChangedSignal('Enabled')
                :Connect(respawnFunc)
        end
    })
end
