
---@param YtLib any
---@param ImGui ImGui
return function(YtLib, ImGui)

Poll = {}

dofile_once("data/scripts/streaming_integration/event_list.lua")

Poll.was_interrupted = false
Poll.current_keys = {}
Poll.current_events = {}
Poll.winner = {}
Poll.cursors = {
    [0] = "",
    [1] = "",
    [2] = "",
    [3] = "",
}

---@return table
local function _select_unique_keys()
    local selected = {}
    local i = 0
    while i < 4 do
        local index = math.random(#streaming_events)
        if not selected[index] then
            selected[index] = streaming_events[index]
            i = i + 1
        end
    end
    local result = {}
    i = 0
    for k in pairs(selected) do
        result[i] = k
        i = i + 1
    end
    return result
end

---@param api_key string
---@param chat_id string
---@param duration integer
---@param period integer
function Poll.StartPoll(api_key, chat_id, duration, period)
    Poll.winner = {}
    Poll.current_keys = _select_unique_keys()
    for i=0,3 do
        Poll.current_events[i] = streaming_events[Poll.current_keys[i]]
        Poll.cursors[i] = ""
    end
    Poll.was_interrupted = false
    YtLib.StartPoll(api_key, chat_id, duration, period)
end

function Poll.EndPoll()
    local results = {
        [0] = YtLib.GetPollResult()[0][0],
        [1] = YtLib.GetPollResult()[0][1],
        [2] = YtLib.GetPollResult()[0][2],
        [3] = YtLib.GetPollResult()[0][3],
    }
    local filtered = {}
    local max = math.max(results[0], results[1], results[2], results[3])
    for k,v in pairs(results) do
        if v == max then
            table.insert(filtered, k)
        end
    end
    local winner_index = filtered[math.random(#filtered)]
    Poll.winner = Poll.current_events[winner_index]
    Poll.cursors[winner_index] = ">"
    local coro = coroutine.create(function ()
        GamePrintImportant(
            GameTextGetTranslatedOrNot(Poll.winner.ui_name),
            GameTextGetTranslatedOrNot(Poll.winner.ui_description)
        )
        Poll.winner.action(Poll.winner)
    end)
    coroutine.resume(coro)
end

function Poll.Interrupt()
    Poll.was_interrupted = true
end

---@param shown boolean
function Poll.Popup(shown)
    if not shown and not YtLib.IsPollRunning() then
        return
    end

    if ImGui.Begin(
        "poll_window",
        true,
        ImGui.WindowFlags.NoTitleBar + ImGui.WindowFlags.NoScrollbar
    ) then
        local w = ImGui.GetWindowWidth()
        local h = ImGui.GetWindowHeight()
        local result = YtLib.GetPollResult()[0]

        if Poll.was_interrupted then
            ImGui.SetCursorPos(0.5 * w - 43, 0.5 * h - 9)
            ImGui.Text("interrupted")
            ImGui.End()
            return
        elseif not Poll.current_events[0] then
            ImGui.SetCursorPos(0.5 * w - 43, 0.5 * h - 9)
            ImGui.Text("not initialized")
            ImGui.End()
            return
        end

        for i=0,3 do
            ImGui.SetCursorPos(3, 0.2 * (i + 1) * h - 9)
            ImGui.TextDisabled(Poll.cursors[i])
            ImGui.SetCursorPos(12, 0.2 * (i + 1) * h - 9)
            ImGui.Text(string.format(
                "%i - %q",
                result[i], GameTextGetTranslatedOrNot(Poll.current_events[i]["ui_name"])
            ))
        end

        ImGui.End()
    end
end

return Poll

end
