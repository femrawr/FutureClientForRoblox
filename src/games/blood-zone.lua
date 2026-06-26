local cloneref = cloneref or function(instance)
    return instance
end

local ReplicatedStorage = cloneref(game:GetService('ReplicatedStorage'))
local SoundService = cloneref(game:GetService('SoundService'))
local Players = cloneref(game:GetService('Players'))

local Maid = fetchScript('classes/maid')

local player = fetchScript('utils/player')

local remotes = ReplicatedStorage.Remotes
local modules = ReplicatedStorage.Modules

local localPlayer = Players.LocalPlayer

local maid = Maid.new()

repeat
    task.wait()
until localPlayer:HasTag('HasLoadedData') and not localPlayer:HasTag('LoadingUser')

local recoilFunc
local shootLoopFunc
local shootHandlerFunc
local anticheatFunc
local crouchFunc

for _, v in next, getgc() do
    if typeof(v) ~= 'function' then
        continue
    end

    local name = debug.getinfo(v).name

    if name == 'DoRecoil' then
        recoilFunc = v
    elseif name == 'ShootLoop' then
        shootLoopFunc = v
    elseif name == 'ShootingAction' then
        shootHandlerFunc = v
    elseif name == 'Punishment' then
        anticheatFunc = v
    elseif name == 'CrouchAction' then
        crouchFunc = v
    end
end

do
    local redeemCodes

    local codeData = require(modules.Data.CodeData)
    local localData = require(modules.Client.LocalData)

    redeemCodes = future.misc:AddModule({
        Name = 'RedeemCodes',
        Function = function(callback)
            if callback then
                for _, v in next, codeData.Data do
                    if localData.Data.RedeemedCodes[v] then
                        continue
                    end

                    remotes.Requests.RedeemCode:InvokeServer(v)
                end

                future.gui:Notify('Redeem Codes', 'All codes have been redeemed!')
                redeemCodes.Toggle()
            end
        end
    })
end

do
    local infStamina
    local noJumpDelay

    local localCharacter = require(modules.Client.Game.LocalCharacter)

    local characterMods = future.movement:AddModule({
        Name = 'CharacterMods',
        Function = function(callback)
            if not callback then
                maid.charMods = nil
                return
            end

            maid.charMods = task.spawn(function()
                while task.wait() do
                    if infStamina.enabled then
                        localCharacter.Stamina = 100
                    end

                    if noJumpDelay.enabled then
                        localCharacter.JumpCooldown = false
                    end
                end
            end)
        end
    })

    infStamina = characterMods:AddToggle({
        Name = 'InfStamina',
        Default = true,
        Function = function() end
    })

    noJumpDelay = characterMods:AddToggle({
        Name = 'NoJumpDelay',
        Default = true,
        Function = function() end
    })
end

do
    local commonUtils = require(modules.Utility.Util)

    local oldRandomizeUnit

    future.combat:AddModule({
        Name = 'NoRecoil',
        Function = function(callback)
            if not callback then
                restorefunction(recoilFunc)
                return
            end

            hookfunction(recoilFunc, function()
                return nil
            end)
        end
    })

    future.combat:AddModule({
        Name = 'AlwaysAuto',
        Function = function(callback)
            if not callback then
                restorefunction(shootHandlerFunc)
                return
            end

            hookfunction(shootHandlerFunc, function(gun, _, input, _)
                if not gun.Equipped or gun.Tool.Parent ~= gun.CharacterModel then
                    gun.Shooting = false
                    return
                end

                gun.Shooting = input == Enum.UserInputState.Begin
                  if not gun.Shooting then return end

                if gun.Settings.CurrentAmmo.Value <= 0 then
                    SoundService.Client.AmmoOut:Play()
                    gun:AttemptAutoLoad()
                    return
                end

                shootLoopFunc(gun)
            end)
        end
    })

    future.combat:AddModule({
        Name = 'NoSpread',
        Function = function(callback)
            if not callback then
                restorefunction(commonUtils.RandomizeUnit)
                oldRandomizeUnit = nil
                return
            end

            oldRandomizeUnit = hookfunction(commonUtils.RandomizeUnit, function(...)
                local trace = debug.traceback()
                if not trace:find('WeaponClient.GunClient') then
                    return oldRandomizeUnit(...)
                end

                local direction = ({...})[1]
                return CFrame.lookAlong(Vector3.new(0, 0, 0), direction).LookVector
            end)
        end
    })
end

do
    local escaper = require(modules.Client.Game.Escaper)
    local realEscaper = debug.getupvalue(escaper.New, 1)

    future.misc:AddModule({
        Name = 'InstantEscape',
        Function = function(callback)
            if not callback then
                restorefunction(realEscaper.OnPress)
                return
            end

            hookfunction(realEscaper.OnPress, function(obj, _)
                obj.Progress = 100

                obj:Terminate()
                obj:Validate()
            end)
        end
    })
end

do
    future.exploits:AddModule({
        Name = 'ClientDisabler',
        Function = function(callback)
            if not callback then
                restorefunction(anticheatFunc)
                return
            end

            hookfunction(anticheatFunc, function(_, kind, ban)
                future.gui:Notify('Client Disabler', 'Anticheat ' .. (ban and 'ban' or 'kick') .. ' function blocked - ' .. kind)
                return nil
            end)
        end
    })
end

do
    future.misc:AddModule({
        Name = 'FakeKnocked',
        Function = function(callback)
            local root, hum = player.getRoot()
            if not root or not hum then return end

            root.Parent:SetAttribute('Downed', callback)

            hum.HipHeight = callback and -1.9 or 0
        end
    })
end

do
    local oldCrouch

    future.movement:AddModule({
        Name = 'NoCrouchSlow',
        Function = function(callback)
            if not callback then
                restorefunction(crouchFunc)
                oldCrouch = nil
                return
            end

            oldCrouch = hookfunction(crouchFunc, function(self, crouch)
                if self.Crouching == crouch then
                    return oldCrouch(self, crouch)
                end

                if crouch then
                    self:EmoteFinished()
                end

                self.Crouching = crouch
                self.Humanoid.HipHeight = crouch and -1.2 or 0
                self.Humanoid.WalkSpeed = 18
                self.Humanoid.JumpHeight = 7.2
            end)
        end
    })
end
