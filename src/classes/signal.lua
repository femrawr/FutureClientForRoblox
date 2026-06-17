local cloneref = cloneref or function(instance)
    return instance
end

local Signal = {}
Signal.__index = Signal

function Signal.new()
    local self = setmetatable({}, Signal)
    self._bindableEvent = cloneref(Instance.new('BindableEvent'))
    self._argData = nil
    self._argCount = nil

    return self
end

function Signal.isSignal(object)
    return typeof(object) == 'table' and getmetatable(object) == Signal
end

function Signal:Fire(...)
    self._argData = {...}
    self._argCount = select('#', ...)
    self._bindableEvent:Fire()

    self._argData = nil
    self._argCount = nil
end

function Signal:Connect(handler)
    if not self._bindableEvent then
        return warn('[future] [signal.Connect] failed to find event')
    end

    if typeof(handler) ~= 'function' then
        return warn('[future] [signal.Connect] expected function type for handler, got ' .. typeof(handler))
    end

    return self._bindableEvent.Event:Connect(function()
        handler(unpack(self._argData, 1, self._argCount))
    end)
end

function Signal:Wait()
    self._bindableEvent.Event:Wait()

    if not self._argData then
        return warn('[future] [signal.Wait] argument data not found')
    end

    return unpack(self._argData, 1, self._argCount)
end

function Signal:Destroy()
    if self._bindableEvent then
        self._bindableEvent:Destroy()
        self._bindableEvent = nil
    end

    self._argData = nil
    self._argCount = nil
end

return Signal
