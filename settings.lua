dofile("data/scripts/lib/mod_settings.lua")

local mod_id = "youtube_integration"

mod_settings = {
    {
        id = "debug",
        ui_name = "DEBUG",
        value_default = false,
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        ui_fn = mod_setting_vertical_spacing,
        not_setting = true,
    },
    {
        id = "shown",
        ui_name = "Properties window",
        value_default = "shown",
        values = { {"shown", "shown"}, {"hidden", "hidden"} },
        scope = MOD_SETTING_SCOPE_RUNTIME,
    },
    {
        ui_fn = mod_setting_vertical_spacing,
        not_setting = true,
    },
    {
        category_id = "poll_settings",
        ui_name = "POLL SETTINGS",
        settings = {
            {
                id = "period",
                ui_name = "Period",
                value_min = 750,
                value_max = 10000,
                value_default = 5000,
                value_display_formatting = " $0 ms",
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "duration",
                ui_name = "Duration",
                value_min = 6,
                value_max = 60,
                value_default = 10,
                value_display_formatting = " $0 s",
                scope = MOD_SETTING_SCOPE_RUNTIME,
            },
            {
                id = "frequency",
                ui_name = "Poll frequency",
                value_default = "medium",
                values = {
                    {"high", "high"}, -- [120; 630]
                    {"medium", "medium"}, -- [473; 1183]
                    {"low", "low"} -- [630; 2520]
                },
                scope = MOD_SETTING_SCOPE_RUNTIME,
            }
        }
    }
}

function ModSettingsUpdate( init_scope )
    mod_settings_update( mod_id, mod_settings, init_scope )
end

function ModSettingsGuiCount()
    return mod_settings_gui_count( mod_id, mod_settings )
end

function ModSettingsGui( gui, in_main_menu )
    mod_settings_gui( mod_id, mod_settings, gui, in_main_menu )
end

