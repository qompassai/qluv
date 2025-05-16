#!/usr/bin/env lua
local json = require("dkjson")
local http = require("socket.http")
local ltn12 = require("ltn12")
local io = require("io")
local os = require("os")
local string = require("string")
local table = require("table")
local ORGANIZATION = "qompassai"
local CATEGORIES = {"equator", "nautilus", "sojourn", "waveRunner"}
local PROGRAMMING_LANGUAGES = {
    "python", "rust", "mojo", "zig", "c", "c++", "javaScript", "typeScript",
    "java", "go", "ruby", "php", "swift", "lua", "kotlin", "r", "julia", "dart"
}
local function get_repo_url()
    local handle = io.popen("git config --get remote.origin.url")
    if not handle then
        io.stderr:write("Error: Failed to execute git command\n")
        os.exit(1)
    end
    local result = handle:read("*a")
    local success, close_msg = handle:close()
    if not success then
        io.stderr:write("Warning: Failed to properly close command handle: " .. (close_msg or "unknown error") .. "\n")
    end
    result = string.gsub(result, "%s+$", "")
    if result == "" then
        io.stderr:write("Error: Not a git repository or no remote 'origin' set\n")
        os.exit(1)
    end
    return result
end
local function extract_repo_info(url)
    local patterns = {
        "git@github%.com:([^/]+)/([^%.]+)%.git",
        "https://github%.com/([^/]+)/([^%.]+)(?:%.git)?",
        "git://github%.com/([^/]+)/([^%.]+)%.git"
    }
    for _, pattern in ipairs(patterns) do
        local owner, repo = string.match(url, pattern)
        if owner and repo then
            return owner, repo
        end
    end
    io.stderr:write("Error: Could not parse GitHub URL: " .. url .. "\n")
    os.exit(1)
end
local function get_repo_metadata(owner, repo)
    local url = string.format("https://api.github.com/repos/%s/%s", owner, repo)
    local response_body = {}
    local _, code = http.request{
        url = url,
        headers = { ["Accept"] = "application/vnd.github.mercy-preview+json" },
        sink = ltn12.sink.table(response_body)
    }
    if code ~= 200 then
        io.stderr:write(string.format("Error: Failed to fetch repository data: %d\n", code))
        os.exit(1)
    end
    local body = table.concat(response_body)
    local success, metadata = pcall(json.decode, body)
    if not success then
        io.stderr:write("Error: Failed to parse repository data as JSON\n")
        os.exit(1)
    end
    return metadata
end
local function detect_programming_language(metadata)
    local name = metadata["name"] or ""
    local description = metadata["description"] or ""
    local topics = metadata["topics"] or {}

    for _, lang in ipairs(PROGRAMMING_LANGUAGES) do
        if string.find(string.lower(name), string.lower(lang), 1, true) then
            return lang
        end
    end
    for _, topic in ipairs(topics) do
        for _, lang in ipairs(PROGRAMMING_LANGUAGES) do
            if string.lower(topic) == string.lower(lang) then
                return lang
            end
        end
    end
    for _, lang in ipairs(PROGRAMMING_LANGUAGES) do
        if string.find(string.lower(description), string.lower(lang), 1, true) then
            return lang
        end
    end
    io.write("Warning: Could not automatically detect programming language.\n")
    io.write("Please enter the programming language (or press Enter for generic): ")
    local input = io.read()
    if input == "" then
        return "Programming"
    else
        return input
    end
end
local function detect_category(metadata)
    local name = metadata["name"] or ""
    local topics = metadata["topics"] or {}
    for _, topic in ipairs(topics) do
        for _, category in ipairs(CATEGORIES) do
            if string.lower(topic) == string.lower(category) then
                return category
            end
        end
    end
    for _, category in ipairs(CATEGORIES) do
        if string.find(string.lower(name), string.lower(category), 1, true) then
            return category
        end
    end
    io.write("Warning: Could not automatically detect project category.\n")
    io.write("Available categories: " .. table.concat(CATEGORIES, ", ") .. "\n")
    io.write("Please enter the category: ")
    local input = io.read()
    for _, category in ipairs(CATEGORIES) do
        if input == category then
            return category
        end
    end
    io.write("Invalid category. Using default: Equator\n")
    return "Equator"
end

local function update_metadata_template(template_path, metadata, language, category)
    local file = io.open(template_path, "r")
    if not file then
        io.stderr:write("Error: Template file not found: " .. template_path .. "\n")
        os.exit(1)
    end
    local content = file:read("*a")
    file:close()
    local success, data = pcall(json.decode, content)
    if not success then
        io.stderr:write("Error: Failed to parse template as JSON\n")
        os.exit(1)
    end
    
    data["title"] = category .. ": " .. language
    
    if metadata["description"] then
        data["description"] = metadata["description"]
    else
        data["description"] = string.format("Educational Content on the %s Programming Language", language)
    end
    local keywords = {}
    if metadata["topics"] then
        for _, v in ipairs(metadata["topics"]) do
            table.insert(keywords, v)
        end
    end
    local function contains_case_insensitive(tbl, val)
        val = string.lower(val)
        for _, v in ipairs(tbl) do
            if string.lower(v) == val then
                return true
            end
        end
        return false
    end
    if not contains_case_insensitive(keywords, category) then
        table.insert(keywords, category)
    end
    if not contains_case_insensitive(keywords, language) then
        table.insert(keywords, language)
    end
    if not contains_case_insensitive(keywords, "AI") then
        table.insert(keywords, "AI")
    end
    if not contains_case_insensitive(keywords, "Education") then
        table.insert(keywords, "Education")
    end
    data["keywords"] = keywords
    if data["related_identifiers"] then
        for _, related in ipairs(data["related_identifiers"]) do
            if related["relation"] == "isSupplementTo" then
                related["identifier"] = metadata["html_url"]
            end
        end
    end
    local output_path = "CITATION.cff"
    local outfile = io.open(output_path, "w")
    if not outfile then
        io.stderr:write("Error: Could not write to " .. output_path .. "\n")
        os.exit(1)
    end
    local success_encode, result = pcall(json.encode, data, { indent = true })
    if not success_encode then
        io.stderr:write("Error: Failed to encode metadata to JSON\n")
        os.exit(1)
    end
    outfile:write(result)
    outfile:close()
    print("Metadata written to " .. output_path)
    print(string.format("\nConsider updating GitHub topics with:\ngh repo edit %s --add-topic %s",
        metadata["full_name"], table.concat(keywords, ",")))
end
local function main()
    local repo_url = get_repo_url()
    local owner, repo = extract_repo_info(repo_url)
    print(string.format("Repository: %s/%s", owner, repo))
    if string.lower(owner) ~= string.lower(ORGANIZATION) then
        print(string.format("Note: Using organization %s instead of %s", ORGANIZATION, owner))
        owner = ORGANIZATION
    end
    local metadata = get_repo_metadata(owner, repo)
    local language = detect_programming_language(metadata)
    local category = detect_category(metadata)
    print(string.format("Detected Language: %s", language))
    print(string.format("Detected Category: %s", category))
    local template_path = "metadata_template.json"
    update_metadata_template(template_path, metadata, language, category)
    if metadata["topics"] then
        local current_topics = table.concat(metadata["topics"], ",")
        print(string.format("\nCurrent topics: %s", current_topics))
    end
end
main()
