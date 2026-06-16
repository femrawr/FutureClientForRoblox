local Signal = fetchScript('classes/signal')

local Maid = {}

function Maid.new()
    return setmetatable({
        _tasks = {}
    }, Maid)
end

function Maid.__index(self, index)
    if Maid[index] then
        return Maid[index]
    else
        return self._tasks[index]
    end
end

function Maid:__newindex(index, newTask)
    if Maid[index] ~= nil then
        return warn('[future] [maid.__newindex] ' .. index .. ' already exists')
    end

    local tasks = self._tasks
    local oldTask = tasks[index]

    if oldTask == newTask then
        return
    end

    tasks[index] = newTask

    if not oldTask then
        return
    end

    if typeof(oldTask) == 'function' then
        oldTask()
    elseif typeof(oldTask) == 'RBXScriptConnection' then
        oldTask:Disconnect()
    elseif typeof(oldTask) == 'table' then
        table.clear(taskData)
    elseif Signal.isSignal(oldTask) then
        oldTask:Destroy()
    elseif typeof(oldTask) == 'thread' then
        task.cancel(oldTask)
    elseif oldTask.Destroy then
        oldTask:Destroy()
    end
end

function Maid:GiveTask(task)
    if not task then
        return warn('[future] [maid.GiveTask] task cannot be false or nil')
    end

    local taskId = #self._tasks + 1
    self[taskId] = task

    return taskId
end

function Maid:DoCleaning()
    local tasks = self._tasks

    for index, task in next, tasks do
        if typeof(task) ~= 'RBXScriptConnection' then
            continue
        end

        tasks[index] = nil
        task:Disconnect()
    end

    local index, taskData = next(tasks)
    while taskData ~= nil do
        tasks[index] = nil

        if typeof(taskData) == 'function' then
            taskData()
        elseif typeof(taskData) == 'RBXScriptConnection' then
            taskData:Disconnect()
        elseif Signal.isSignal(taskData) then
            taskData:Destroy()
        elseif typeof(taskData) == 'table' then
            table.clear(taskData)
        elseif typeof(taskData) == 'thread' then
            task.cancel(taskData)
        elseif taskData.Destroy then
            taskData:Destroy()
        end

        index, taskData = next(tasks)
    end
end

return Maid
