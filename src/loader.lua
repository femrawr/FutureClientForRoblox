local BASE_URL = 'https://raw.githubusercontent.com/femrawr/FutureClientForRoblox/refs/heads/main/'

local function fetchScript(name, bypass)
    if future_dev and isfolder('FutureClientForRoblox') then
        if bypass then
            local suc, res = pcall(readfile, 'FutureClientForRoblox/' .. name)
            if not suc then
                warn('[future] [loader.fetchScript] failed to read file "' .. name .. '" -', res)
                return nil
            end

            return res
        end

        local suc, res = pcall(readfile, 'FutureClientForRoblox/src/' .. name .. '.lua')
        if not suc then
            warn('[future] [loader.fetchScript] failed to read file "' .. name .. '" -', res)
            return nil
        end

        local func, err = loadstring(res)
        if err then
            warn('[future] [loader.fetchScript] failed to load "' .. name .. '" -', err)
            return nil
        end

        return func()
    end

    local suc, res = pcall(request, {
        Url = BASE_URL .. (bypass and name or 'src/' .. name .. '.lua'),
        Method = 'GET'
    })

    if not suc or not res.Success then
        warn('[future] [loader.fetchScript] failed to fetch "' .. name .. '" -', res.StatusMessage)
        return nil
    end

    if bypass then
        return res.Body
    end

    local func, err = loadstring(res.Body)
    if err then
        warn('[future] [loader.fetchScript] failed to load "' .. name .. '" -', err)
        return nil
    end

    return func()
end

getgenv().fetchScript = fetchScript

if not game:IsLoaded() then
    game.Loaded:Wait()
end

fetchScript('main')
