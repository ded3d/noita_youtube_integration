
YOUTUBE_INTEGRATION_VERSION = "{VERSION}"

---@type boolean
local initialized
---@type boolean
local enabled
---@type boolean, boolean
local is_dead, paused
---@type table
local Poll
---@type table
local YtLib
---@type ImGui
local ImGui

---@type integer
local requests
---@type boolean
local is_poll_running
---@type integer
local api_key_state
---@type string
local api_key
---@type integer
local video_id_state
---@type string
local video_id
---@type string
local chat_id

---@type boolean
local DEBUG
---@type boolean
local WINDOW_SHOWN
---@type integer, integer
local TICKS_MIN, TICKS_MAX
---@type boolean
local popup_shown
---@type string
local last_checked_id
---@type boolean
local clicked_once
---@type boolean
local clicked
---@type integer
local ticks_before_poll


local function main_loop()
    local ffi = require("ffi")
    local is_busy = YtLib.IsBusy()
    local _is_poll_running = YtLib.IsPollRunning()
    local last_id = ffi.string(YtLib.GetLastValidVideoId())
    if ticks_before_poll == 0 and enabled and not is_dead and not paused then
        is_poll_running = true
        ticks_before_poll = math.random(TICKS_MIN, TICKS_MAX)
        Poll.StartPoll(
            api_key,
            chat_id,
            ModSettingGet("youtube_integration.duration"),
            ModSettingGet("youtube_integration.period")
        )
    elseif enabled and ticks_before_poll == -1 then
        ticks_before_poll = math.random(TICKS_MIN, TICKS_MAX)
    elseif enabled and (not is_poll_running or not _is_poll_running) and not is_dead then
        ticks_before_poll = ticks_before_poll - 1
    elseif not enabled then
        ticks_before_poll = math.max(ticks_before_poll - 1, -1)
    end

    if is_poll_running and is_busy and not _is_poll_running then
        is_poll_running = false
        Poll.EndPoll()
    end

    if WINDOW_SHOWN and ImGui.Begin("YouTube Integration " .. YOUTUBE_INTEGRATION_VERSION) then
        ImGui.Text("INTEGRATION STATUS")
        ImGui.SameLine()
        if enabled then
            ImGui.TextColored(0., 1., 0., 1., "ACTIVE")
        else
            ImGui.TextDisabled("INACTIVE")
        end
        if DEBUG then
            ImGui.SameLine()
            ImGui.TextDisabled(chat_id)
        end
        ImGui.Spacing()

        ImGui.Text("API key")
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.TextDisabled("contained in key.txt")
            ImGui.EndTooltip()
        end
        ImGui.SameLine()
        if api_key_state == 1 then
            ImGui.TextColored(0., 1., 0., 1., "VALID")
        elseif is_busy then
            ImGui.TextDisabled("...")
        elseif api_key_state == -1 then
            ImGui.Text("NOT CHECKED")
        else
            ImGui.TextColored(0.5, 0.5, 0., 1., "INVALID")
        end

        _, video_id = ImGui.InputTextWithHint("", "Stream video_id", video_id)
        if ImGui.IsItemHovered() then
            ImGui.BeginTooltip()
            ImGui.TextDisabled("stream identifier\nwritten after watch?v=")
            ImGui.EndTooltip()
        end
        ImGui.SameLine()
        if video_id_state == 1 then
            ImGui.TextColored(0., 1., 0., 1., "VALID")
        elseif is_busy then
            ImGui.TextDisabled("...")
        elseif video_id_state == -1 then
            ImGui.Text("NOT CHECKED")
        else
            ImGui.TextColored(0.5, 0.5, 0., 1., "INVALID")
        end

        if ImGui.SmallButton("check") then
            requests = 4
            last_checked_id = video_id
            clicked_once = true
            clicked = true
        else
            clicked = false
        end

        if DEBUG then
            local _popup_toggle_label = "show"
            if popup_shown then
                _popup_toggle_label = "hide"
            end

            ImGui.Spacing()
            ImGui.SeparatorText("debug")

            ImGui.BeginDisabled(not enabled or is_poll_running)
            if ImGui.SmallButton("test poll") then
                is_poll_running = true
                Poll.StartPoll(
                    api_key,
                    chat_id,
                    ModSettingGet("youtube_integration.duration"),
                    ModSettingGet("youtube_integration.period")
                )
            end
            ImGui.EndDisabled()
            ImGui.SameLine()
            if ImGui.SmallButton(_popup_toggle_label) then
                popup_shown = not popup_shown
            end
            ImGui.SameLine()
            ImGui.TextDisabled(tostring(ticks_before_poll))
        end

        ImGui.End()
    end

    Poll.Popup(popup_shown or false)

    local ffi = require("ffi")
    is_busy = YtLib.IsBusy()
    local is_free = not is_busy and (requests > 0)

    if api_key_state ~= 1 and api_key_state ~= -2 then
        if YtLib.GetApiKeyCheck() then
            api_key_state = 1
        elseif requests > 0 then
            api_key_state = -1
        else
            api_key_state = 0
        end
    end

    if video_id == "" then
        video_id_state = -2
    elseif video_id ~= last_id and video_id ~= last_checked_id then
        video_id_state = -1
    elseif video_id ~= last_id and requests == 0 and last_id ~= "" then
        video_id_state = 0
    elseif video_id_state ~= 1 then
        if video_id == last_id then
            video_id_state = 1
            ModSettingSet("youtube_integration.video_id", video_id)
        elseif requests == 0 then
            video_id_state = -1
        else
            video_id_state = 0
        end
    end

    enabled = api_key_state == 1 and video_id_state == 1

    if enabled and chat_id == "" then
        local _chat_id = ffi.string(YtLib.GetChatId())
        if _chat_id ~= "" and _chat_id ~= "null" then
            chat_id = _chat_id
            ticks_before_poll = math.random(TICKS_MIN, TICKS_MAX)
        elseif not is_busy then
            YtLib.SendChatId(api_key, video_id)
        end
        return
    elseif not clicked_once and requests == 0 then
        return
    end

    if is_free and api_key_state ~= 1 and api_key_state ~= -2 then
        YtLib.SendApiKeyCheck(api_key)
        requests = requests - 1
    elseif is_free and api_key_state == 1 and video_id_state ~= 1 and video_id_state ~= -2 then
        YtLib.SendVideoIdCheck(api_key, video_id)
        requests = requests - 1
    elseif is_free and api_key_state == 1 and video_id_state == 1 then
        requests = 0
    end

    if not is_busy and requests > 0 then
        requests = requests - 1
    end
end 


---@return string?
local function load_header()
    local hfile = io.open("mods/youtube_integration/lib/yt_wrapper.h", "r")
    if not hfile then
        return
    end
    local content = hfile:read("*a")
    hfile:close()
    return content
end

---@return string?
local function load_api_key()
    local file = io.open("mods/youtube_integration/key.txt", "r")
    if not file then
        return
    end
    local content = file:read("*l")
    file:close()
    return content
end

---@param boolean
function update_settings(randomize_ticks)
    DEBUG = ModSettingGet("youtube_integration.debug")
    WINDOW_SHOWN = ModSettingGet("youtube_integration.shown") == "shown"
    local freq = ModSettingGet("youtube_integration.frequency")
    if freq == "high" then
        TICKS_MIN = 120
        TICKS_MAX = 630
    elseif freq == "medium" then
        TICKS_MIN = 473
        TICKS_MAX = 1183
    else
        TICKS_MIN = 630
        TICKS_MAX = 2520
    end
    if randomize_ticks then
        ticks_before_poll = math.random(TICKS_MIN, TICKS_MAX)
    end
end


function OnModInit()
    if not require then
        print_error("Looks like the `request_no_api_restrictions` flag in mod.xml is off")
        initialized = false
        return
    elseif not load_imgui then
        print_error("Could not find \"NoitaDearImGui: Main\" mod")
        initialized = false
        return
    end
    
    local build_check = io.open("mods/youtube_integration/lib/yt_wrapper.dll", "r")
    if build_check == nil then
        print_error("Looks like the mod was not built")
        initialized = false
        return
    end
    build_check:close()

    local ffi = require("ffi")
    ImGui = load_imgui({ version = "1.7", mod = "youtube_integration" })
    ffi.cdef(load_header())
    YtLib = ffi.load("mods/youtube_integration/lib/yt_wrapper.dll")
    YtLib.Init(YOUTUBE_INTEGRATION_VERSION)
    Poll = dofile_once("mods/youtube_integration/lib/poll.lua")(YtLib, ImGui)

    requests = 4
    api_key = load_api_key() or ""
    if api_key == "YOUR_API_KEY_GOES_HERE" or api_key == "" then
        api_key_state = -2
    else
        api_key_state = -1
    end
    video_id_state = -1
    video_id = ModSettingGet("youtube_integration.video_id") or ""
    chat_id = ""

    update_settings(false)
    paused = false
    is_dead = false
    is_poll_running = false
    popup_shown = false
    clicked_once = false
    clicked = false
    ticks_before_poll = -1
    last_checked_id = ""
    enabled = false
    initialized = true
end


function OnPlayerDied()
    if not initialized then
        return
    end
    is_dead = true
    enabled = false
    WINDOW_SHOWN = false
    ImGui.CloseCurrentPopup()
    popup_shown = false
    ticks_before_poll = -1
end

function OnPausedChanged(is_paused, is_inventory_pause)
    if not initialized then
        return
    end
    paused = is_paused or is_inventory_pause
    update_settings(api_key_state == 1 and video_id_state == 1)
end

function OnWorldPostUpdate()
    if not initialized or is_dead or paused then
        return
    end
    main_loop()
end
