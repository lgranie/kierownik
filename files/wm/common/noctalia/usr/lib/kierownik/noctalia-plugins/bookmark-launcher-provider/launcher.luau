--!nonstrict
-- Linkding bookmarks launcher provider for Noctalia v5.
-- Type /bookmarks in the launcher to search, browse by category, or update.
-- Settings are configured via plugin.toml (browser, token, serverUrl).

local database = {}
local loaded = false
local loading = false
local categories = { "all" }
local selectedCategory = "all"
local currentQuery = ""

local function getSettings()
    return {
        browser = noctalia.getConfig("browser") or "brave-browser",
        token = noctalia.getConfig("token") or "",
        serverUrl = noctalia.getConfig("serverUrl") or "",
    }
end

local function updateCategories()
    categories = { "all" }
    local keys = {}
    for k, _ in pairs(database) do table.insert(keys, k) end
    for i = 1, #keys do
        local entry = database[keys[i]]
        if entry and entry.tags then
            for j = 1, #entry.tags do
                local tag = entry.tags[j]
                if tag and tag ~= "all" then
                    local found = false
                    for _, c in ipairs(categories) do
                        if c == tag then found = true break end
                    end
                    if not found then table.insert(categories, tag) end
                end
            end
        end
    end
end

local function writeDatabase()
    local ok, err = pcall(function()
        local parts = { "{" }
        local first = true
        for k, v in pairs(database) do
            if not first then table.insert(parts, ",") end
            first = false
            table.insert(parts, "\"" .. k:gsub("\"", "\\\"") .. "\":{")
            table.insert(parts, "\"url\":\"" .. (v.url or ""):gsub("\"", "\\\"") .. "\"")
            table.insert(parts, ",\"tags\":[")
            for ti, tv in ipairs(v.tags or {}) do
                if ti > 1 then table.insert(parts, ",") end
                table.insert(parts, "\"" .. tv:gsub("\"", "\\\"") .. "\"")
            end
            table.insert(parts, "]")
            table.insert(parts, ",\"description\":\"" .. (v.description or ""):gsub("\"", "\\\"") .. "\"")
            table.insert(parts, ",\"favicon_url\":\"" .. (v.favicon_url or ""):gsub("\"", "\\\"") .. "\"")
            table.insert(parts, "}")
        end
        table.insert(parts, "}")
        noctalia.writeFile("database.json", table.concat(parts))
    end)
    if not ok then
        noctalia.log("Linkding: writeDatabase failed: " .. tostring(err))
    end
end

local function loadDatabase()
    local data, err = noctalia.readFile("database.json")
    if not data then
        noctalia.log("Linkding: No database.json found yet")
        return false
    end
    if data ~= "" then
        local parsed = noctalia.json.decode(data)
        if type(parsed) == "table" then
            database = parsed
            loaded = true
            loading = false
            updateCategories()
            noctalia.log("Linkding: Database loaded (" .. #database .. " entries)")
            return true
        else
            noctalia.log("Linkding: database.json parse failed")
        end
    end
    return false
end

local function parseBookmarks(jsonSource)
    noctalia.log("Linkding: parseBookmarks called, body length: " .. #jsonSource)
    local result = noctalia.json.decode(jsonSource)
    if type(result) ~= "table" or not result.results then
        noctalia.log("Linkding: parseBookmarks: bad response format")
        return 0
    end
    local db = {}
    for i = 1, #result.results do
        local b = result.results[i]
        local title = b.title
        if title then
            db[title] = {
                url = b.url or "",
                tags = b.tag_names or {},
                description = b.description or "",
                favicon_url = b.favicon_url or ""
            }
        end
    end
    database = db
    loaded = true
    loading = false
    updateCategories()
    writeDatabase()
    noctalia.log("Linkding: Parsed " .. tostring(#result.results) .. " bookmarks")
    return #result.results or 0
end

local function updateBookmarks(tk, url, currentQ, onDone)
    noctalia.log("Linkding: updateBookmarks called, token_len=" .. #tk .. ", url=" .. url)
    if not tk or tk == "" then
        noctalia.notify("Linkding", "Token is missing — set it in Settings")
        if onDone then onDone(false) end
        return
    end
    if not url or url == "" then
        noctalia.notify("Linkding", "Server URL is missing — set it in Settings")
        if onDone then onDone(false) end
        return
    end
    loading = true
    local apiUrl = url .. "/api/bookmarks/?format=json"
    noctalia.log("Linkding: Fetching from " .. apiUrl)
    local cmd = { "curl", "-s", "--max-time", "10", "-X", "GET",
        "-H", "User-Agent: Mozilla/5.0",
        "-H", "Authorization: Token " .. tk,
        apiUrl }
    local ok, err = pcall(function()
        noctalia.runAsync(cmd, function(res)
            noctalia.log("Linkding: HTTP callback, exitCode=" .. tostring(res.exitCode))
            loading = false
            if res.exitCode ~= 0 then
                noctalia.notifyError("Linkding", "curl failed (exit " .. tostring(res.exitCode) .. ")")
                noctalia.log("Linkding: curl stderr: " .. tostring(res.stderr or "none"))
                if onDone then onDone(false) end
                return
            end
            local count = parseBookmarks(res.stdout or "")
            noctalia.notify("Linkding", "Bookmarks updated: " .. tostring(count) .. " items")
            if onDone then onDone(true) end
        end)
    end)
    if not ok then
        noctalia.log("Linkding: noctalia.runAsync failed: " .. tostring(err))
        loading = false
        noctalia.notifyError("Linkding", "HTTP request failed to start")
        if onDone then onDone(false) end
    end
end

local function formatBookmark(title, entry, browserCmd)
    local url = entry.url or ""
    local cmd = { browserCmd or "brave-browser" }
    if entry.tags then
        for _, tag in ipairs(entry.tags) do
            if tag == "app" then url = "--app=" .. url break end
        end
    end
    table.insert(cmd, url)
    return {
        id = title,
        title = title,
        subtitle = entry.description or "",
        glyph = "link",
        onActivate = function()
            noctalia.runAsync(cmd)
            launcher.close()
        end,
    }
end

function onQuery(query)
    currentQuery = query or ""
    local text = noctalia.string.trim(currentQuery) or ""
    local settings = getSettings()
    noctalia.log("Linkding: onQuery text=" .. text .. ", loaded=" .. tostring(loaded))

    if text == "update" then
        noctalia.log("Linkding: Update requested")
        updateBookmarks(settings.token, settings.serverUrl, currentQuery, function(success)
            if not success then return end
            launcher.setResults(currentQuery, {
                { id = "", title = "Bookmarks updated", subtitle = "Database refreshed", glyph = "check-circle" }
            })
        end)
        return
    end

    if not loaded then
        local ok = loadDatabase()
        if not ok then
            launcher.setResults(currentQuery, {
                { id = "", title = "Database not loaded", subtitle = "Type /bookmarks update to fetch bookmarks", glyph = "alert-circle" }
            })
            return
        end
    end

    if loading then
        launcher.setResults(currentQuery, {
            { id = "", title = "Loading...", subtitle = "Loading bookmarks database", glyph = "refresh" }
        })
        return
    end

    local keys
    if selectedCategory == "all" then
        keys = {}
        for k, _ in pairs(database) do table.insert(keys, k) end
    else
        keys = {}
        for title, entry in pairs(database) do
            if entry.tags then
                for _, tag in ipairs(entry.tags) do
                    if tag == selectedCategory then
                        table.insert(keys, title)
                        break
                    end
                end
            end
        end
    end

    local results = {}
    local settings = getSettings()
    if text == "" then
        for i = 1, math.min(#keys, 100) do
            table.insert(results, formatBookmark(keys[i], database[keys[i]], settings.browser))
        end
    else
        local lowerQuery = text:lower()
        local count = 0
        for i = 1, #keys do
            if count >= 50 then break end
            local title = keys[i]
            if title:lower():find(lowerQuery, 1, true) then
                table.insert(results, formatBookmark(title, database[keys[i]], settings.browser))
                count = count + 1
            end
        end
    end

    if #results == 0 then
        table.insert(results, { id = "", title = "No results", subtitle = "No bookmarks found", glyph = "mood-empty" })
    end

    launcher.setResults(currentQuery, results)
end

function onActivate(id)
    if id == "" and noctalia.string.trim(currentQuery) == "update" then return end

    local settings = getSettings()
    local entry = database[id]
    if entry then
        local url = entry.url or ""
        local cmd = { settings.browser }
        if entry.tags then
            for _, tag in ipairs(entry.tags) do
                if tag == "app" then url = "--app=" .. url break end
            end
        end
        table.insert(cmd, url)
        noctalia.runAsync(cmd)
        launcher.close()
        return
    end

    local category = id:match("^category:(.+)$")
    if category then
        selectedCategory = category
        launcher.setQuery(category .. " ")
        return
    end
end
