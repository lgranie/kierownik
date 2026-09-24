--!nonstrict
-- Linkding bookmarks launcher provider for Noctalia v5.
-- Type /bookmarks in the launcher to search, browse by category, or update.
-- Settings are configured via plugin.toml (browser, token, serverUrl).

local database = {}
local usage = {}
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

local dataDir = nil

local function getDataPath(name)
    if not dataDir then
        local dir, err = noctalia.pluginDataDir()
        if not dir then
            noctalia.log("Linkding: pluginDataDir failed: " .. tostring(err))
            return name
        end
        dataDir = dir
    end
    return dataDir .. "/" .. name
end

local function writeData(name, tbl)
    local path = getDataPath(name)
    local ok, err = pcall(function()
        local encoded, encErr = noctalia.json.encode(tbl)
        if not encoded then
            noctalia.log("Linkding: json.encode failed (" .. name .. "): " .. tostring(encErr))
            return
        end
        local wrote, werr = noctalia.writeFile(path, encoded)
        if not wrote then
            noctalia.log("Linkding: writeFile failed (" .. name .. "): " .. tostring(werr))
        end
    end)
    if not ok then
        noctalia.log("Linkding: write failed (" .. name .. "): " .. tostring(err))
    end
end

local function updateCategories()
    local seen = { all = true }
    local list = { "all" }
    for _, entry in pairs(database) do
        if type(entry) == "table" and type(entry.tags) == "table" then
            for _, tag in ipairs(entry.tags) do
                if type(tag) == "string" and tag ~= "" and not seen[tag] then
                    seen[tag] = true
                    table.insert(list, tag)
                end
            end
        end
    end
    table.sort(list)
    -- keep "all" first
    local out = { "all" }
    for _, c in ipairs(list) do
        if c ~= "all" then table.insert(out, c) end
    end
    categories = out
    if selectedCategory ~= "all" and not seen[selectedCategory] then
        selectedCategory = "all"
    end
end

local function loadUsage()
    local data, err = noctalia.readFile(getDataPath("usage.json"))
    if data and data ~= "" then
        local parsed = noctalia.json.decode(data)
        if type(parsed) == "table" then
            for k, _ in pairs(parsed) do
                if tonumber(k) == nil then
                    noctalia.log("Linkding: usage.json uses old url keys, resetting")
                    usage = {}
                    return
                end
            end
            usage = parsed
        end
    end
end

local function loadDatabase()
    local data, err = noctalia.readFile(getDataPath("database.json"))
    if not data then
        noctalia.log("Linkding: No database.json found yet: " .. tostring(err))
        return false
    end
    if data ~= "" then
        local parsed = noctalia.json.decode(data)
        if type(parsed) == "table" then
            database = parsed
            loaded = true
            loading = false
            updateCategories()
            loadUsage()
            local count = 0
            for _ in pairs(database) do count = count + 1 end
            noctalia.log("Linkding: Database loaded (" .. count .. " entries)")
            return true
        else
            noctalia.log("Linkding: database.json parse failed")
        end
    end
    return false
end

local function parseBookmarks(items)
    noctalia.log("Linkding: parseBookmarks called, items: " .. #items)
    local db = {}
    for i = 1, #items do
        local b = items[i]
        if type(b) ~= "table" then
            noctalia.log("Linkding: parseBookmarks: skipping non-table item at index " .. i)
        else
            local title = b.title
            if title then
                db[title] = {
                    id = b.id,
                    url = b.url or "",
                    tags = b.tag_names or {},
                    description = b.description or "",
                    favicon_url = b.favicon_url or "",
                    date_added = b.date_added or ""
                }
            end
        end
    end
    database = db
    loaded = true
    loading = false
    updateCategories()
    loadUsage()
    writeData("database.json", database)
    noctalia.log("Linkding: Parsed " .. tostring(#items) .. " bookmarks")
    return #items
end

local function fetchPage(tk, apiUrl, acc, onDone)
    local accepted = noctalia.http({
        url = apiUrl,
        headers = { "Authorization: Token " .. tk },
    }, function(res)
        if not res or not res.ok or res.status ~= 200 then
            noctalia.log("Linkding: HTTP request failed (ok=" .. tostring(res and res.ok)
                .. ", status=" .. tostring(res and res.status) .. ")")
            onDone(nil)
            return
        end
        local page = noctalia.json.decode(res.body or "")
        if type(page) ~= "table" or type(page.results) ~= "table" then
            noctalia.log("Linkding: fetchPage: bad response format")
            onDone(nil)
            return
        end
        for i = 1, #page.results do table.insert(acc, page.results[i]) end
        if type(page.next) == "string" and page.next ~= "" then
            noctalia.log("Linkding: Fetching next page")
            fetchPage(tk, page.next, acc, onDone)
        else
            onDone(acc)
        end
    end)
    if not accepted then
        noctalia.log("Linkding: noctalia.http request not accepted")
        onDone(nil)
    end
end

local function updateBookmarks(tk, url, onDone)
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
    local base = url:gsub("/+$", "")
    local apiUrl = base .. "/api/bookmarks/?format=json"
    noctalia.log("Linkding: Fetching from " .. apiUrl)
    fetchPage(tk, apiUrl, {}, function(items)
        loading = false
        if not items then
            noctalia.notifyError("Linkding", "Failed to fetch bookmarks")
            if onDone then onDone(false) end
            return
        end
        local count = parseBookmarks(items)
        noctalia.notify("Linkding", "Bookmarks updated: " .. tostring(count) .. " items")
        if onDone then onDone(true) end
    end)
end

local function formatBookmark(title, entry, score)
    return {
        id = title,
        title = title,
        subtitle = entry.description or "",
        glyph = "link",
        score = score,
    }
end

local function fuzzyField(query, text)
    if not text or text == "" then return 0 end
    return noctalia.fuzzyScore(query, text)
        or noctalia.fuzzyScore(query:lower(), text:lower())
        or 0
end

local function scoreBookmark(title, entry, query)
    if not query or query == "" then
        return 0
    end

    local baseScore = fuzzyField(query, title)
    if baseScore == 0 then return nil end

    return baseScore
end

function onQuery(query)
    currentQuery = query or ""
    local text = noctalia.string.trim(currentQuery) or ""
    local settings = getSettings()
    noctalia.log("Linkding: onQuery text=" .. text .. ", loaded=" .. tostring(loaded))

    if text:lower() == "update" then
        noctalia.log("Linkding: Update requested")
        local q = currentQuery
        updateBookmarks(settings.token, settings.serverUrl, function(success)
            if not success then return end
            launcher.setResults(q, {
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

    if text == "" then
        selectedCategory = "all"
    end

    -- Resolve category filter: explicit drill-in selection, or query matching a tag.
    local activeCategory = selectedCategory
    if activeCategory == "all" then
        for _, c in ipairs(categories) do
            if c ~= "all" and text:lower() == c:lower() then
                activeCategory = c
                break
            end
        end
    end

    local keys
    if activeCategory == "all" then
        keys = {}
        for k, _ in pairs(database) do table.insert(keys, k) end
    else
        keys = {}
        for title, entry in pairs(database) do
            if entry.tags then
                for _, tag in ipairs(entry.tags) do
                    if tag == activeCategory then
                        table.insert(keys, title)
                        break
                    end
                end
            end
        end
    end

    local scoredList = {}
    local results = {}
    if text == "" then
        for _, c in ipairs(categories) do
            if c ~= "all" then
                table.insert(scoredList, {
                    isCat = true,
                    title = c,
                    result = { id = "category:" .. c, title = c, subtitle = "Browse category", glyph = "tag", score = 999999 }
                })
            end
        end
        for i = 1, #keys do
            local title = keys[i]
            local entry = database[title]
            local sc = scoreBookmark(title, entry, "")
            table.insert(scoredList, {
                isCat = false,
                title = title,
                score = sc,
                result = formatBookmark(title, entry, sc)
            })
        end
        table.sort(scoredList, function(a, b)
            if a.isCat ~= b.isCat then return a.isCat end
            if a.score ~= b.score then return a.score > b.score end
            return a.title < b.title
        end)
        for i = 1, math.min(#scoredList, 100) do
            table.insert(results, scoredList[i].result)
        end
    else
    for i = 1, #keys do
        local title = keys[i]
        local entry = database[title]
        local sc = scoreBookmark(title, entry, text)
        if sc then
            table.insert(scoredList, {
                title = title,
                score = sc,
                result = formatBookmark(title, entry, sc)
            })
        end
    end
    table.sort(scoredList, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        return a.title < b.title
    end)
    for i = 1, math.min(#scoredList, 50) do
        table.insert(results, scoredList[i].result)
    end
    end

    if #results == 0 then
        table.insert(results, { id = "", title = "No results", subtitle = "No bookmarks found", glyph = "mood-empty" })
    end

    launcher.setResults(currentQuery, results)
end

function onActivate(id)
    if id == "" and (noctalia.string.trim(currentQuery) or ""):lower() == "update" then return end

    local settings = getSettings()
    local entry = database[id]
    if entry then
        local uKey = tostring(entry.id)
        local uInfo = usage[uKey] or { count = 0, last = 0 }
        uInfo.count = uInfo.count + 1
        uInfo.last = os.time()
        usage[uKey] = uInfo
        writeData("usage.json", usage)

        local url = entry.url or ""
        local cmd = { settings.browser }
        if entry.tags then
            for _, tag in ipairs(entry.tags) do
                if tag == "app" then url = "--app=" .. url break end
            end
        end
        table.insert(cmd, url)
        noctalia.runAsync(cmd)
        return
    end

    local category = id:match("^category:(.+)$")
    if category then
        selectedCategory = category
        launcher.setQuery(category .. " ")
        return
    end
end
