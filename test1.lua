hitgroup_names = {
    "generic",
    "head",
    "chest",
    "stomach",
    "left arm",
    "right arm",
    "left leg",
    "right leg",
    "neck",
    "?",
    "gear"
}

UI = {}
local TabSystem = {}
TabSystem.__index = TabSystem

function TabSystem.new(tab_name, container_name, tabs_list)
    local self = setmetatable({}, TabSystem)
    self.tabs = {}
    self.elements = {}
    self.callbacks = {}
    self.updating = false
    self.tab_selector = ui.new_combobox(tab_name, container_name, "Tab selection", unpack(tabs_list))

    for _, tab_name in ipairs(tabs_list) do
        self.tabs[tab_name] = {}
        self.elements[tab_name] = {}
    end

    ui.set_callback(
        self.tab_selector,
        function()
            if not self.updating then
                self:update_visibility()
            end
        end
    )

    return self
end
function ref_try(paths)
    for i = 1, #paths do
        local sec = paths[i]
        local ok, a, b, c = pcall(ui.reference, sec[1], sec[2], sec[3])
        if ok and a ~= nil then
            if c ~= nil then
                return {a, b, c}
            elseif b ~= nil then
                return {a, b}
            else
                return {a}
            end
        end
    end
    return {}
end

function ref_hotkey(paths)
    local r = ref_try(paths)
    for i = 1, #r do
        local ok, v = pcall(ui.get, r[i])
        if ok and type(v) == "boolean" then
            if #r >= 2 then
                return r[2]
            else
                return r[1]
            end
        end
    end
    return r[1]
end

function hotkey_on(hk)
    if not hk then
        return false
    end
    local ok, v = pcall(ui.get, hk)
    return ok and v == true
end

function ref_on_pair(r)
    if not r or #r == 0 then
        return false
    end
    local on = true

    local ok1, v1 = pcall(ui.get, r[1])
    if ok1 and type(v1) == "boolean" then
        on = on and v1
    end

    if #r >= 2 then
        local ok2, v2 = pcall(ui.get, r[2])
        if ok2 and type(v2) == "boolean" then
            on = on and v2
        end
    end
    return on
end
function TabSystem:add_checkbox(tab_name, menu_tab, container, name, default)
    local element = ui.new_checkbox(menu_tab, container, name)
    if default ~= nil then
        ui.set(element, default)
    end
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_slider(tab_name, menu_tab, container, name, min, max, default, show_tooltip, suffix)
    local element =
        ui.new_slider(menu_tab, container, name, min, max, default or min, show_tooltip or false, suffix or "")
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_combobox(tab_name, menu_tab, container, name, ...)
    local element = ui.new_combobox(menu_tab, container, name, ...)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_multiselect(tab_name, menu_tab, container, name, ...)
    local element = ui.new_multiselect(menu_tab, container, name, ...)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_button(tab_name, menu_tab, container, name, callback)
    local element = ui.new_button(menu_tab, container, name, callback)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_hotkey(tab_name, menu_tab, container, name, inline)
    local element = ui.new_hotkey(menu_tab, container, name, inline or false)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_label(tab_name, menu_tab, container, text)
    local element = ui.new_label(menu_tab, container, text)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_color_picker(tab_name, menu_tab, container, name, r, g, b, a)
    local element = ui.new_color_picker(menu_tab, container, name, r or 255, g or 255, b or 255, a or 255)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_textbox(tab_name, menu_tab, container, name)
    local element = ui.new_textbox(menu_tab, container, name)
    table.insert(self.elements[tab_name], element)
    return element
end

function TabSystem:add_conditional(tab_name, element, condition_callback)
    if not self.callbacks[tab_name] then
        self.callbacks[tab_name] = {}
    end
    table.insert(self.callbacks[tab_name], {element = element, condition = condition_callback})
end

function TabSystem:update_visibility()
    if self.updating then
        return
    end
    self.updating = true

    local current_tab = ui.get(self.tab_selector)

    for tab_name, elements in pairs(self.elements) do
        local is_visible = (tab_name == current_tab)

        for _, element in ipairs(elements) do
            ui.set_visible(element, is_visible)
        end

        if is_visible and self.callbacks[tab_name] then
            for _, callback_data in ipairs(self.callbacks[tab_name]) do
                local condition_result = callback_data.condition()
                ui.set_visible(callback_data.element, condition_result)
            end
        end
    end

    self.updating = false
end
local my_tabs = TabSystem.new("LUA", "B", {"Rage", "Visuals", "Misc", "Settings"})

last_hg_str = {}

MAX_YAW_DELTAS = 16
MAX_TIME_DELTAS = 16
MAX_YAW_PROGRESSION = 16
MAX_RECENT_ANGLES = 20
_grad_labels = {}
function screen()
    return client.screen_size()
end
function for_target(ent_index, func)
    if not ent_index or ent_index == 0 then
        return
    end
    if not entity.is_alive(ent_index) then
        return
    end
    func(ent_index)
end

vec3 = require("vector")

function to_hex(r, g, b, a)
    return "\a" .. string.format("%02X%02X%02X%02X", r, g, b, a or 255)
end

function lerp(a, b, t)
    return a + (b - a) * t
end

function breathe(offset, speed)
    local t = globals.realtime() * (speed or 1)
    return math.abs(math.sin(t + (offset or 0)))
end

client.set_event_callback(
    "paint_ui",
    function()
        if not ui.is_menu_open() then
            return
        end
        for _, lbl in ipairs(_grad_labels) do
            local txt, out = lbl.text, ""
            if #txt > 1 then
                for i = 1, #txt do
                    local t = (i - 1) / (#txt - 1)
                    local br = breathe(t, 1.2)
                    local cg = lerp(150, 255, br)
                    local cb = lerp(200, 255, br)
                    out = out .. to_hex(0, cg, cb) .. txt:sub(i, i)
                end
            else
                out = txt
            end
            ui.set(lbl.ref, out)
        end
    end
)
warmup =
    my_tabs:add_button(
    "Misc",
    "LUA",
    "B",
    "Warmup",
    function()
        client.exec(
            "sv_cheats 1; bot_kick; mp_freezetime 0; mp_roundtime 999; mp_buy_anywhere 1; mp_free_armor 2; mp_buytime 100000; mp_startmoney 64000; bot_stop 1; bot_add_t; mp_respawn_on_death_ct 1; mp_roundtime_defuse 999; mp_respawn_on_death_t 1; mp_Restartgame 1; sv_regeneration_force_on 1; sv_infinite_ammo 1; bot_add_t"
        )
    end
)
local function link_ui(name, ref)
    _G[name] = ref
end

do
    local vector = require("vector")
    local trace = require("gamesense/trace")
    local bit = require("bit")
    UI.AIPeek = UI.AIPeek or {}

    UI.AIPeek.enable = my_tabs:add_checkbox("Rage", "LUA", "B", "AI Peek")
    UI.AIPeek.hotkey = my_tabs:add_hotkey("Rage", "LUA", "B", "Hotkey", true)
    UI.AIPeek.strat = my_tabs:add_combobox("Rage", "LUA", "B", "Strategy", "Closest", "Safest")
    UI.AIPeek.allow_jump = my_tabs:add_checkbox("Rage", "LUA", "B", "Allow jump", true)
    UI.AIPeek.jump_hp = my_tabs:add_slider("Rage", "LUA", "B", "Jump if enemy HP ≤", 1, 100, 60)
    UI.AIPeek.r_max = my_tabs:add_slider("Rage", "LUA", "B", "Max radius", 30, 1500, 300, true, "u")
    UI.AIPeek.r_step = my_tabs:add_slider("Rage", "LUA", "B", "Radius step", 10, 60, 20, true, "u")
    UI.AIPeek.seg = my_tabs:add_slider("Rage", "LUA", "B", "Segments (ring)", 6, 32, 16)
    UI.AIPeek.travel = my_tabs:add_slider("Rage", "LUA", "B", "Max travel (u)", 10, 1500, 50)
    UI.AIPeek.edge = my_tabs:add_checkbox("Rage", "LUA", "B", "Edge check (no fall)", true)
    UI.AIPeek.m_dmg = my_tabs:add_slider("Rage", "LUA", "B", "Min damage", 1, 130, 30)
    UI.AIPeek.lost_ticks = my_tabs:add_slider("Rage", "LUA", "B", "Lost ticks", 5, 60, 30)
    UI.AIPeek.dbg = my_tabs:add_checkbox("Rage", "LUA", "B", "Debug draw")

    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.hotkey,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.strat,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.allow_jump,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.jump_hp,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.r_max,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.r_step,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.seg,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.travel,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.edge,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.m_dmg,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.lost_ticks,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )
    my_tabs:add_conditional(
        "Rage",
        UI.AIPeek.dbg,
        function()
            return ui.get(UI.AIPeek.enable)
        end
    )

    ui.set_callback(
        UI.AIPeek.enable,
        function()
            my_tabs:update_visibility()
        end
    )
    link_ui("aienable", UI.AIPeek.enable)
    link_ui("hotkey", UI.AIPeek.hotkey)
    link_ui("strat", UI.AIPeek.strat)
    link_ui("allow_jump", UI.AIPeek.allow_jump)
    link_ui("jump_hp", UI.AIPeek.jump_hp)
    link_ui("r_max", UI.AIPeek.r_max)
    link_ui("r_step", UI.AIPeek.r_step)
    link_ui("seg", UI.AIPeek.seg)
    link_ui("travel", UI.AIPeek.travel)
    link_ui("edge", UI.AIPeek.edge)
    link_ui("m_dmg", UI.AIPeek.m_dmg)
    link_ui("lost_ticks", UI.AIPeek.lost_ticks)
    link_ui("dbg", UI.AIPeek.dbg)

    local hb_list = {2, 4, 5, 3}
    local hull_min, hull_max = vector(-16, -16, 0), vector(16, 16, 72)
    local eye_z = {stand = 64, jump = 78}
    local air_ref = ui.reference("MISC", "Movement", "Air strafe")

    local function dist_2d(a, b)
        return ((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2) ^ 0.5
    end

    local function yaw_angle(dx, dy)
        return math.deg(math.atan2(dy, dx))
    end

    local function ground_present(p)
        if not ui.get(edge) then
            return true
        end
        local tr = trace.line(p + vector(0, 0, 5), p - vector(0, 0, 128), nil, MASK_SOLID_BRUSHONLY)
        return tr.fraction < 0.99
    end

    local function closest_enemy(lp)
        local ox, oy = entity.get_origin(lp)
        local best, bd = nil, 1e9
        for _, e in ipairs(entity.get_players(true)) do
            if entity.is_alive(e) then
                local ex, ey = entity.get_origin(e)
                if ex then
                    local d = (ox - ex) ^ 2 + (oy - ey) ^ 2
                    if d < bd then
                        best, bd = e, d
                    end
                end
            end
        end
        return best
    end

    local function hull_clear(lp, dst)
        local s = vector(entity.get_origin(lp)) + vector(0, 0, 32)
        local tr = trace.hull(s, dst + vector(0, 0, 32), hull_min, hull_max, lp)
        return tr and tr.fraction == 1
    end

    local function gun_ready(lp)
        local w = entity.get_player_weapon(lp)
        if not w then
            return false
        end
        local t = globals.curtime()
        return t >= (entity.get_prop(lp, "m_flNextAttack") or 0) and
            t >= (entity.get_prop(w, "m_flNextPrimaryAttack") or 0)
    end

    local function bullet_dmg(lp, en, pos, hb)
        local ex, ey, ez = entity.hitbox_position(en, hb)
        if not ex then
            return 0
        end
        local _, d = client.trace_bullet(lp, pos.x, pos.y, pos.z, ex, ey, ez)
        return d or 0
    end

    local function choose_pose(lp, en, p, min_dmg)
        if not hull_clear(lp, p) or not ground_present(p) then
            return
        end
        for _, hb in ipairs(hb_list) do
            if bullet_dmg(lp, en, vector(p.x, p.y, p.z + eye_z.stand), hb) >= min_dmg then
                return "stand"
            end
        end
        if ui.get(allow_jump) and (entity.get_prop(en, "m_iHealth") or 100) <= ui.get(jump_hp) then
            for _, hb in ipairs(hb_list) do
                if bullet_dmg(lp, en, vector(p.x, p.y, p.z + eye_z.jump), hb) >= min_dmg then
                    return "jump"
                end
            end
        end
    end

    local function safe_dist(lp, en, start, p)
        local dir = p - start
        dir.z = 0
        local len = dir:length()
        if len == 0 then
            return 0
        end
        dir = dir / len
        local ex, ey, ez = client.eye_position(en)
        for w = 0, len, 5 do
            local pos = start + dir * w + vector(0, 0, 64)
            if client.trace_line(en, ex, ey, ez, pos.x, pos.y, pos.z) > 1 then
                return w
            end
        end
        return len
    end

    local _state = {}

    local function init(lp)
        local x, y, z = entity.get_origin(lp)
        _state = {
            active = true,
            wait = true,
            ret = false,
            start = vector(x, y, z),
            goal = nil,
            pose = "stand",
            lost = 0,
            air = nil,
            pts = nil
        }
    end

    client.set_event_callback(
        "run_command",
        function()
            if not ui.get(aienable) then
                _state.active = false
                return
            end
            local lp = entity.get_local_player()
            if not lp or not entity.is_alive(lp) or not ui.get(hotkey) then
                _state.active = false
                return
            end

            if not _state.active then
                init(lp)
            end
            if _state.wait and not gun_ready(lp) then
                return
            end
            _state.wait = false

            local en = closest_enemy(lp)
            if not en then
                _state.goal, _state.ret = nil, false
                return
            end

            local min_dmg = ui.get(m_dmg)
            if _state.goal and choose_pose(lp, en, _state.goal, min_dmg) then
                _state.lost = 0
            elseif _state.goal then
                _state.lost = _state.lost + 1
                if _state.lost > ui.get(lost_ticks) then
                    _state.goal, _state.ret = nil, true
                end
            end

            if _state.goal or _state.ret then
                return
            end

            local seg_n, r_max, r_step_n = ui.get(seg), ui.get(r_max), ui.get(r_step)
            local travel_n = ui.get(travel)
            local best, metric = nil, (ui.get(strat) == "Closest" and 1e9 or -1)

            for r = r_step_n, math.min(r_max, travel_n), r_step_n do
                for i = 0, seg_n - 1 do
                    local a = i / seg_n * 2 * math.pi
                    local p = vector(_state.start.x + r * math.cos(a), _state.start.y + r * math.sin(a), _state.start.z)
                    local pose = choose_pose(lp, en, p, min_dmg)
                    if ui.get(dbg) then
                        local why =
                            (pose and "ok") or (not hull_clear(lp, p) and "wall") or (not ground_present(p) and "fall") or
                            "low"
                        _state.pts = _state.pts or {}
                        table.insert(_state.pts, {p, why})
                    end
                    if pose then
                        local m = (ui.get(strat) == "Closest" and r) or safe_dist(lp, en, _state.start, p)
                        local cond =
                            (ui.get(strat) == "Closest" and m < metric) or (ui.get(strat) == "Safest" and m > metric)
                        if cond then
                            best, metric, _state.pose = p, m, pose
                        end
                    end
                end
            end

            if best then
                _state.goal, _state.ret, _state.lost = best, false, 0
            else
                _state.ret = true
            end
        end
    )

    client.set_event_callback(
        "aim_fire",
        function(e)
            if _state.active then
                _state.ret = true
                _state.goal = nil
            end
        end
    )

    client.set_event_callback(
        "run_command",
        function(cmd)
            if not _state.active then
                return
            end
            local lp = entity.get_local_player()
            if not lp or not entity.is_alive(lp) then
                return
            end

            local fl = entity.get_prop(lp, "m_fFlags") or 1
            if _state.air and bit.band(fl, 1) == 0 then
                ui.set(air_ref, _state.air)
                _state.air = nil
            end

            local tgt = (_state.ret and _state.start) or _state.goal
            if not tgt then
                cmd.forwardmove, cmd.sidemove = 0, 0
                return
            end

            local cur = vector(entity.get_origin(lp))
            local d = dist_2d(cur, tgt)
            if d < 0.75 then
                cmd.forwardmove, cmd.sidemove = 0, 0
                if _state.ret then
                    _state.active = false
                end
                return
            end

            cmd.in_jump = 0
            if _state.pose == "jump" and _state.goal and ui.get(allow_jump) and bit.band(fl, 1) == 1 and d < 30 then
                cmd.in_jump = 1
                if not _state.air then
                    _state.air = ui.get(air_ref)
                    ui.set(air_ref, false)
                end
            end

            cmd.forwardmove = _state.ret and math.min(d * 60, 450) or 450
            cmd.sidemove = 0
            cmd.move_yaw = yaw_angle(tgt.x - cur.x, tgt.y - cur.y)
        end
    )

    client.set_event_callback(
        "paint",
        function()
            if not ui.get(aienable) or not ui.get(dbg) then
                return
            end

            if _state.pts then
                for _, v in ipairs(_state.pts) do
                    local p, why = v[1], v[2]
                    local col = (why == "ok" and {0, 255, 0}) or (why == "wall" and {255, 0, 0}) or {255, 255, 255}
                    local sx, sy = renderer.world_to_screen(p.x, p.y, p.z)
                    if sx then
                        renderer.circle_outline(sx, sy, 6, table.unpack(col), 200)
                    end
                end
            end

            if _state.goal then
                local p, state_z = _state.goal, _state.goal.z + 64
                local cs = {
                    {p.x - 20, p.y - 20, state_z},
                    {p.x + 20, p.y - 20, state_z},
                    {p.x + 20, p.y + 20, state_z},
                    {p.x - 20, p.y + 20, state_z}
                }
                local s = {}
                for i = 1, 4 do
                    s[i] = {renderer.world_to_screen(unpack(cs[i]))}
                end
                if s[1][1] then
                    for i = 1, 4 do
                        local j = i % 4 + 1
                        renderer.line(s[i][1], s[i][2], s[j][1], s[j][2], 255, 0, 0, 255)
                    end
                end
            end
        end
    )

    client.set_event_callback(
        "shutdown",
        function()
            _state = {}
        end
    )
end

UI.Logs = UI.Logs or {}
UI.Logs.enable = my_tabs:add_checkbox("Visuals", "LUA", "B", "Enable logs")
UI.Logs.log_types = my_tabs:add_multiselect("Visuals", "LUA", "B", "Log types", "Hits", "Misses")
ui.set(UI.Logs.log_types, {"Hits", "Misses"})

UI.Logs.osl_enable = my_tabs:add_checkbox("Visuals", "LUA", "B", "On-screen logs", true)
UI.Logs.log_mode = my_tabs:add_combobox("Visuals", "LUA", "B", "Log display mode", "Cards", "Minimalistic")
UI.Logs.osl_style =
    my_tabs:add_combobox(
    "Visuals",
    "LUA",
    "B",
    "OSL style",
    "Black",
    "Liquid Glass",
    "Neon",
    "Sunset",
    "Ocean",
    "Forest",
    "Candy",
    "Nord",
    "Dracula",
    "Tokyo Night",
    "Catppuccin",
    "Gruvbox"
)
UI.Logs.oneline_font = my_tabs:add_combobox("Visuals", "LUA", "B", "Minimalistic font", "Normal", "Bold")
UI.Logs.osl_glow = my_tabs:add_checkbox("Visuals", "LUA", "B", "Card glow", true)
UI.Logs.osl_advanced = my_tabs:add_checkbox("Visuals", "LUA", "B", "Advanced", true)

UI.Logs.osl_glow_intensity = my_tabs:add_slider("Visuals", "LUA", "B", "Glow intensity", 0, 200, 100, true, "%")
UI.Logs.osl_center_x = my_tabs:add_slider("Visuals", "LUA", "B", "OSL Center X", 0, 4000, 0, true, "px")
UI.Logs.osl_center_y = my_tabs:add_slider("Visuals", "LUA", "B", "Center Y", 0, 2000, 900, true, "px")
UI.Logs.osl_width = my_tabs:add_slider("Visuals", "LUA", "B", "Width", 240, 640, 440, true, "px")
UI.Logs.osl_life = my_tabs:add_slider("Visuals", "LUA", "B", "Lifetime", 1, 8, 3, true, "s")
UI.Logs.osl_max = my_tabs:add_slider("Visuals", "LUA", "B", "Max lines", 1, 10, 4, true, "")
UI.Logs.osl_op = my_tabs:add_slider("Visuals", "LUA", "B", "BG opacity", 40, 255, 160, true, "a")
UI.Logs.osl_gap = my_tabs:add_slider("Visuals", "LUA", "B", "Gap", 2, 24, 10, true, "px")

my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_enable,
    function()
        return ui.get(UI.Logs.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.log_types,
    function()
        return ui.get(UI.Logs.enable)
    end
)

my_tabs:add_conditional(
    "Visuals",
    UI.Logs.log_mode,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.oneline_font,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_style,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_glow,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_advanced,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable)
    end
)

my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_glow_intensity,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_width,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_life,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_max,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_op,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_gap,
    function()
        return ui.get(UI.Logs.enable) and ui.get(UI.Logs.osl_enable) and ui.get(UI.Logs.osl_advanced)
    end
)

my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_center_x,
    function()
        return false
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.Logs.osl_center_y,
    function()
        return false
    end
)

ui.set_callback(
    UI.Logs.enable,
    function()
        my_tabs:update_visibility()
    end
)
ui.set_callback(
    UI.Logs.osl_enable,
    function()
        my_tabs:update_visibility()
    end
)
ui.set_callback(
    UI.Logs.osl_advanced,
    function()
        my_tabs:update_visibility()
    end
)
_G.logs_enable = UI.Logs.enable
_G.log_types = UI.Logs.log_types
_G.osl_enable = UI.Logs.osl_enable
_G.log_mode = UI.Logs.log_mode
_G.osl_style = UI.Logs.osl_style
_G.oneline_font = UI.Logs.oneline_font
_G.osl_glow = UI.Logs.osl_glow
_G.osl_advanced = UI.Logs.osl_advanced
_G.osl_glow_intensity = UI.Logs.osl_glow_intensity
_G.osl_center_x = UI.Logs.osl_center_x
_G.osl_center_y = UI.Logs.osl_center_y
_G.osl_width = UI.Logs.osl_width
_G.osl_life = UI.Logs.osl_life
_G.osl_max = UI.Logs.osl_max
_G.osl_op = UI.Logs.osl_op
_G.osl_gap = UI.Logs.osl_gap

local function log_enabled(kind)
    local sel = ui.get(log_types) or {}
    for i = 1, #sel do
        if sel[i] == kind then
            return true
        end
    end
    return false
end
local function ticks_to_ms(t)
    return math.floor(t * globals.tickinterval() * 1000 + 0.5)
end
local function snap(x)
    return math.floor(x + 0.5)
end
local function easeOutCubic(t)
    t = 1 - t
    return 1 - t * t * t
end
local function easeOutQuad(t)
    return 1 - (1 - t) * (1 - t)
end
local function ellipsize(text, max_w, flags)
    if not text or text == "" then
        return ""
    end
    if renderer.measure_text(flags or "", text) <= max_w then
        return text
    end
    local t = text
    while #t > 0 and renderer.measure_text(flags or "", t .. "…") > max_w do
        t = t:sub(1, -2)
    end
    return (t == "" and "…") or (t .. "…")
end
local function draw_round(x, y, w, h, r, col)
    x, y, w, h = snap(x), snap(y), snap(w), snap(h)
    if renderer.rec then
        renderer.rec(x, y, w, h, r, col)
    else
        renderer.rectangle(x, y + r, w, h - r * 2, col[1], col[2], col[3], col[4])
        renderer.rectangle(x + r, y, w - r * 2, r, col[1], col[2], col[3], col[4])
        renderer.rectangle(x + r, y + h - r, w - r * 2, r, col[1], col[2], col[3], col[4])
        renderer.circle(x + r, y + r, col[1], col[2], col[3], col[4], r, 180, 0.25)
        renderer.circle(x - r + w, y + r, col[1], col[2], col[3], col[4], r, 90, 0.25)
        renderer.circle(x - r + w, y - r + h, col[1], col[2], col[3], col[4], r, 0, 0.25)
        renderer.circle(x + r, y - r + h, col[1], col[2], col[3], col[4], r, -90, 0.25)
    end
end

local ONEL = ONEL or {}
local function draw_glow(x, y, w, h, r, intensity, col)
    if not ui.get(osl_glow) then
        return
    end

    local user_intensity = ui.get(osl_glow_intensity) / 100
    intensity = intensity * user_intensity

    local layers = 4
    for i = 1, layers do
        local offset = i * 2.5
        local alpha = math.floor(intensity * (30 / i))
        if alpha > 0 then
            local glow_col = {col[1], col[2], col[3], alpha}
            draw_round(x - offset, y - offset, w + offset * 2, h + offset * 2, r + offset, glow_col)
        end
    end
end

local OSL = {}
local line_h = 18
local pad_x, pad_y = 14, 10
local radius_black, radius_glass = 14, 18
local in_time, out_time = 0.22, 0.24

local function theme(style, bgA)
    bgA = math.max(0, math.min(255, math.floor((bgA or 0) + 0.5)))
    if style == "Liquid Glass" then
        return {
            base = {68, 78, 102, math.floor(bgA * 0.70)},
            mist = {255, 255, 255, math.floor(bgA * 0.06)},
            dot_hit = {130, 255, 200, 230},
            dot_miss = {255, 110, 130, 230},
            glow_hit = {130, 255, 200},
            glow_miss = {255, 110, 130},
            radius = 18
        }
    elseif style == "Neon" then
        return {
            base = {10, 10, 15, bgA},
            mist = {255, 0, 255, math.floor(bgA * 0.08)},
            dot_hit = {0, 255, 200, 240},
            dot_miss = {255, 0, 180, 240},
            glow_hit = {0, 255, 200},
            glow_miss = {255, 0, 180},
            radius = 16
        }
    elseif style == "Sunset" then
        return {
            base = {40, 20, 35, bgA},
            mist = {255, 150, 100, math.floor(bgA * 0.10)},
            dot_hit = {255, 200, 100, 235},
            dot_miss = {255, 80, 120, 235},
            glow_hit = {255, 200, 100},
            glow_miss = {255, 80, 120},
            radius = 16
        }
    elseif style == "Ocean" then
        return {
            base = {15, 30, 45, bgA},
            mist = {100, 200, 255, math.floor(bgA * 0.08)},
            dot_hit = {100, 255, 220, 235},
            dot_miss = {255, 100, 150, 235},
            glow_hit = {100, 255, 220},
            glow_miss = {255, 100, 150},
            radius = 16
        }
    elseif style == "Forest" then
        return {
            base = {20, 30, 25, bgA},
            mist = {150, 255, 150, math.floor(bgA * 0.07)},
            dot_hit = {150, 255, 150, 235},
            dot_miss = {255, 150, 100, 235},
            glow_hit = {150, 255, 150},
            glow_miss = {255, 150, 100},
            radius = 16
        }
    elseif style == "Candy" then
        return {
            base = {40, 25, 40, bgA},
            mist = {255, 150, 200, math.floor(bgA * 0.09)},
            dot_hit = {150, 255, 220, 235},
            dot_miss = {255, 100, 200, 235},
            glow_hit = {150, 255, 220},
            glow_miss = {255, 100, 200},
            radius = 17
        }
    elseif style == "Nord" then
        return {
            base = {46, 52, 64, bgA},
            mist = {216, 222, 233, math.floor(bgA * 0.06)},
            dot_hit = {163, 190, 140, 235},
            dot_miss = {191, 97, 106, 235},
            glow_hit = {163, 190, 140},
            glow_miss = {191, 97, 106},
            radius = 15
        }
    elseif style == "Dracula" then
        return {
            base = {40, 42, 54, bgA},
            mist = {189, 147, 249, math.floor(bgA * 0.08)},
            dot_hit = {80, 250, 123, 235},
            dot_miss = {255, 121, 198, 235},
            glow_hit = {80, 250, 123},
            glow_miss = {255, 121, 198},
            radius = 16
        }
    elseif style == "Tokyo Night" then
        return {
            base = {26, 27, 38, bgA},
            mist = {122, 162, 247, math.floor(bgA * 0.07)},
            dot_hit = {158, 206, 106, 235},
            dot_miss = {247, 118, 142, 235},
            glow_hit = {158, 206, 106},
            glow_miss = {247, 118, 142},
            radius = 15
        }
    elseif style == "Catppuccin" then
        return {
            base = {30, 30, 46, bgA},
            mist = {137, 180, 250, math.floor(bgA * 0.07)},
            dot_hit = {166, 227, 161, 235},
            dot_miss = {243, 139, 168, 235},
            glow_hit = {166, 227, 161},
            glow_miss = {243, 139, 168},
            radius = 15
        }
    elseif style == "Gruvbox" then
        return {
            base = {40, 40, 40, bgA},
            mist = {213, 196, 161, math.floor(bgA * 0.08)},
            dot_hit = {184, 187, 38, 235},
            dot_miss = {251, 73, 52, 235},
            glow_hit = {184, 187, 38},
            glow_miss = {251, 73, 52},
            radius = 15
        }
    else
        return {
            base = {12, 12, 14, bgA},
            mist = nil,
            dot_hit = {40, 200, 120, 235},
            dot_miss = {230, 70, 80, 235},
            glow_hit = {40, 200, 120},
            glow_miss = {230, 70, 80},
            radius = 14
        }
    end
end

local function osl_push_card(kind, title, subtitle)
    if not ui.get(osl_enable) then
        return
    end
    local DOT_W = 18
    local t = title or ""
    local s = subtitle or ""
    local life = ui.get(osl_life)
    local sw, sh = client.screen_size()
    local base_w = ui.get(osl_width)
    local min_w = math.floor(base_w * 0.6 + 0.5)
    local max_w = math.floor(base_w * 3.0 + 0.5)

    local function measure_multiline(text, font, max_width)
        if text == "" then
            return 0
        end
        local max_line_w = 0
        local current = ""
        for word in text:gmatch("%S+") do
            local test = (current == "" and word) or (current .. " " .. word)
            local w = renderer.measure_text(font, test)
            if w > max_width then
                local cw = renderer.measure_text(font, current)
                if cw > max_line_w then
                    max_line_w = cw
                end
                current = word
            else
                current = test
            end
        end
        if current ~= "" then
            local cw = renderer.measure_text(font, current)
            if cw > max_line_w then
                max_line_w = cw
            end
        end
        return max_line_w
    end

    local tw = renderer.measure_text("b", t) or 0
    local sw2 = measure_multiline(s, "", max_w - pad_x * 2 - DOT_W)

    local content_w = math.max(tw, sw2)
    local needed_w = math.ceil(content_w + pad_x * 2 + DOT_W)
    local w = math.max(min_w, math.min(max_w, needed_w))

    local h = 2 * pad_y + line_h + ((s ~= "" and (line_h - 2)) or 0)

    local cx0 = ui.get(osl_center_x) or (sw / 2)
    local cy0 = ui.get(osl_center_y) or math.floor(sh * 0.55 + 0.5)

    local card = {
        kind = kind,
        title = t,
        sub = s,
        t = 0,
        life = life,
        state = "in",
        w = w,
        h = h,
        cx = cx0,
        cy = cy0,
        in_off = 26,
        out_off = 18,
        glow_intensity = 1.2
    }

    table.insert(OSL, 1, card)
    local mx = ui.get(osl_max)
    while #OSL > mx do
        table.remove(OSL)
    end
end

local function oneline_push(text)
    if not ui.get(osl_enable) then
        return
    end
    local life = ui.get(osl_life) or 4
    table.insert(ONEL, 1, {t = 0, life = life, text = tostring(text or "")})
    while #ONEL > (ui.get(osl_max) or 6) do
        table.remove(ONEL)
    end
end

local function draw_oneline(dt)
    if not ui.get(osl_enable) then
        return
    end

    if log_mode then
        local m = tostring(ui.get(log_mode) or "")
        if m ~= "Minimalistic" and m ~= "One-line" and m ~= "oneline" then
            return
        end
    elseif OSL_MODE and OSL_MODE ~= "oneline" then
        return
    end

    local sw, sh = client.screen_size()
    local y = ui.get(osl_center_y) or math.floor(sh * 0.55 + 0.5)
    local gap = ui.get(osl_gap) or 6

    local pad_x, pad_y = 12, 6
    local radius = 8

    for i = #ONEL, 1, -1 do
        local e = ONEL[i]
        e.t = e.t + dt
        local k = e.t / e.life
        if k >= 1 then
            table.remove(ONEL, i)
        else
            local alpha
            if e.t < 0.15 then
                alpha = math.floor((e.t / 0.15) * 255)
            elseif e.t > e.life - 0.25 then
                alpha = math.floor((1 - (e.t - (e.life - 0.25)) / 0.25) * 255)
            else
                alpha = 255
            end

            local text = e.text
            local tw, th = renderer.measure_text(nil, text)

            local bg_w, bg_h = tw + pad_x * 2, th + pad_y * 2

            local x = math.floor((sw - bg_w) * 0.5 + 0.5)

            draw_round(x - 3, y - 3, bg_w + 6, bg_h + 6, radius + 2, {0, 0, 0, math.floor(alpha * 0.12)})
            draw_round(x - 1, y - 1, bg_w + 2, bg_h + 2, radius + 1, {0, 0, 0, math.floor(alpha * 0.22)})

            draw_round(x, y, bg_w, bg_h, radius, {12, 12, 12, math.floor(alpha * 0.78)})

            renderer.text(x + pad_x, y + pad_y, 235, 235, 235, alpha, nil, 0, text)

            y = y + bg_h + gap
        end
    end
end

local function draw_glass(x, y, w, h, th)
    th = th or {base = {12, 12, 14, 160}, radius = 14}

    local bx, by, bw, bh = math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5)
    draw_round(bx, by, bw, bh, th.radius, th.base)

    if th.mist then
        local ix, iy, iw, ih = bx + 2, by + 2, math.max(0, bw - 4), math.max(0, bh - 4)

        draw_round(ix, iy, iw, ih, math.max(0, th.radius - 2), th.mist)

        local steps = 4
        local step_h = math.floor(ih / steps + 0.5)
        for i = 0, steps - 1 do
            local ay = iy + i * step_h
            local ah = (i == steps - 1) and (iy + ih - ay) or step_h
            if ah > 0 then
                local a = math.max(0, th.mist[4] - i * 3)
                renderer.rectangle(ay and ix or ix, ay, iw, ah, 255, 255, 255, a)
            end
        end
    end
end

local function osl_update_and_draw(dt)
    if not ui.get(osl_enable) then
        return
    end
    local DOT_W = 18
    local sw, sh = client.screen_size()
    local gap = ui.get(osl_gap)
    local y_cursor = ui.get(osl_center_y)

    for i = #OSL, 1, -1 do
        local c = OSL[i]
        c.t = c.t + dt

        do
            local tw = renderer.measure_text("b", c.title or "") or 0
            local sw2 = (c.sub ~= "" and renderer.measure_text("", c.sub) or 0)
            local content_w = math.max(tw, sw2)

            local base_w = ui.get(osl_width)
            local min_w = math.floor(base_w * 0.6 + 0.5)
            local max_w = math.floor(base_w * 3.0 + 0.5)

            local needed_w = math.ceil(content_w + pad_x * 2 + DOT_W)
            c.w = math.max(min_w, math.min(max_w, needed_w))
        end
        local a, slide, scale = 1, 0, 1
        if c.state == "in" then
            local k = math.min(1, c.t / in_time)
            a = k
            slide = (1 - easeOutCubic(k)) * c.in_off
            scale = 0.96 + 0.04 * k
            c.glow_intensity = 1.2 * k
            if k >= 1 then
                c.state = "hold"
                c.t = 0
            end
        elseif c.state == "hold" then
            c.glow_intensity = 0.6 + math.sin(globals.realtime() * 2.5) * 0.2
            if c.t >= c.life then
                c.state = "out"
                c.t = 0
            end
        else
            local k = math.min(1, c.t / out_time)
            a = 1 - k
            slide = easeOutQuad(k) * c.out_off
            scale = 1 - 0.04 * k
            c.glow_intensity = 0.6 * (1 - k)
        end

        local w = c.w * scale
        local h = c.h * scale
        local x = c.cx - w / 2
        local y = y_cursor - h / 2 + slide

        local bgA = math.floor((ui.get(osl_op) or 160) * a + 0.5)
        local thm = theme(ui.get(osl_style), bgA)

        local glow_col = (c.kind == "hit") and thm.glow_hit or thm.glow_miss
        draw_glow(x, y, w, h, thm.radius, c.glow_intensity, glow_col)

        local th = theme(ui.get(osl_style) or "Black", bgA)
        draw_glass(x, y, w, h, th)

        local d = (c.kind == "hit") and thm.dot_hit or thm.dot_miss
        local dot_x = snap(x + 10)
        local dot_y = snap(y + h / 2)

        if ui.get(osl_glow) then
            local dot_glow_intensity = c.glow_intensity * 0.8
            for j = 1, 3 do
                local dot_offset = j * 1.5
                local dot_alpha = math.floor(dot_glow_intensity * (60 / j) * a)
                if dot_alpha > 0 then
                    renderer.circle(dot_x, dot_y, d[1], d[2], d[3], dot_alpha, 3 + dot_offset, 360, 1)
                end
            end
        end

        renderer.circle(dot_x, dot_y, d[1], d[2], d[3], math.min(255, d[4]), 3, 360, 1)

        local tx = snap(x + pad_x + 8)
        local ty = snap(y + pad_y - 1)
        local title_w = w - (pad_x * 2 + 16)
        local tA = math.floor(255 * a + 0.5)
        local clipped_title = ellipsize(c.title, title_w, "b")
        renderer.text(tx, ty, 255, 255, 255, tA, "b", 0, clipped_title)
        if c.sub ~= "" then
            renderer.text(
                tx,
                ty + line_h - 2,
                205,
                210,
                220,
                math.floor(220 * a + 0.5),
                "",
                0,
                ellipsize(c.sub, title_w, "")
            )
        end

        y_cursor = y_cursor + (h + gap)

        if c.state == "out" and c.t >= out_time then
            table.remove(OSL, i)
        end
    end
end

local ICON = {
    hit = "⮞",
    miss = "⮞"
}

local COL = {
    hit = {120, 255, 180},
    miss = {255, 100, 130},
    dim = {200, 200, 210}
}

local function fmt_field(name, val)
    if not val or val == "" then
        return ""
    end
    return string.format("%s: %s", name, val)
end

local function fmt_percent(val)
    return string.format("%.1f%%", tonumber(val) or 0)
end

local function fmt_ms(t)
    return string.format("%dms", math.floor(t or 0))
end

local function fmt_bt(ticks, ms)
    return string.format("%dt/%s", ticks or 0, fmt_ms(ms))
end
local function fmt_time()
    local H, M, S = client.system_time()
    return ("%02d:%02d:%02d"):format(H, M, S)
end

local function clean_name(n)
    n = tostring(n or "?")
    if #n > 18 then
        n = n:sub(1, 16) .. "…"
    end
    return n
end

local function sleek_log(kind, name, dmg, extra)
    local icon = ICON[kind] or "•"
    local header = "exponential"

    local r, g, b
    if kind == "evade" then
        local cr, cg, cb, ca = ui.get(evaded_col)
        r, g, b = cr or 120, cg or 220, cb or 120
    else
        local color = COL[kind] or {255, 255, 255}
        r, g, b = color[1], color[2], color[3]
    end

    local tag = (kind == "evade") and "evaded" or kind:lower()

    local prefix = string.format("[%s] %s %s", header, icon, tag)
    local line = string.format("%s %s", prefix, name)

    if kind == "hit" and dmg and dmg > 0 then
        line = line .. string.format(" • %ddmg", dmg)
    end
    if extra and extra ~= "" then
        line = line .. " • " .. extra
    end

    client.color_log(r, g, b, line)
end

function push_log(kind, title, subtitle, name_for_minimal, dmg_for_minimal, extra_for_minimal)
    if ui.get(log_mode) == "Cards" then
        osl_push_card(kind, title, subtitle)
        return
    end

    local tag = (kind == "hit") and "hit" or (kind == "evade" and "evaded" or "miss")
    local header = "exponential"

    local extra = extra_for_minimal or ""
    local sub = subtitle or ""
    sub = sub:gsub("%s*|%s*", " • ")
    if extra:find("%f[%a]hb[%s:]", 1) then
        sub = sub:gsub("(%s*•%s*hb%s*[^•]+)", "", 1)
    end
    sub = sub:gsub("%s*•%s*•%s*", " • "):gsub("^%s*•%s*", ""):gsub("%s*•%s*$", "")

    local parts = {"[" .. header .. "]", tag}

    if kind == "evade" then
        if name_for_minimal and name_for_minimal ~= "" then
            table.insert(parts, "shot from " .. name_for_minimal)
        end
        if extra ~= "" then
            table.insert(parts, extra)
        end
        if sub ~= "" then
            table.insert(parts, sub)
        end
    elseif kind == "miss" then
        if name_for_minimal and name_for_minimal ~= "" then
            table.insert(parts, name_for_minimal)
        end
        if extra ~= "" then
            table.insert(parts, extra)
        end
        if sub ~= "" then
            table.insert(parts, sub)
        end
    else
        if name_for_minimal and name_for_minimal ~= "" then
            table.insert(parts, name_for_minimal)
        end
        if (dmg_for_minimal or 0) > 0 then
            table.insert(parts, (dmg_for_minimal .. " dmg"))
        end
        if extra ~= "" then
            table.insert(parts, extra)
        end
        if sub ~= "" then
            table.insert(parts, sub)
        end
    end

    local text = table.concat(parts, " • ")
    oneline_push(text)
end
local visible_now = {}
local visible_since = {}
local _hb_cache = {}

local function get_hb(ent)
    local c = _hb_cache[ent]
    local t = globals.realtime()
    if c and t - c.t < 0.1 then
        return c.x, c.y, c.z
    end
    local x, y, z = entity.hitbox_position(ent, 0)
    if not x then
        x, y, z = entity.hitbox_position(ent, 3)
    end
    if not x then
        local ox, oy, oz = entity.get_origin(ent)
        if not ox then
            return nil
        end
        x, y, z = ox, oy, oz + 50
    end
    _hb_cache[ent] = {x = x, y = y, z = z, t = t}
    return x, y, z
end

client.set_event_callback(
    "run_command",
    function(cmd)
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then
            return
        end
        local ex, ey, ez = client.eye_position()
        if not ex then
            return
        end

        local now = globals.realtime()
        local enemies = entity.get_players(true)

        for _, e in ipairs(enemies) do
            if entity.is_alive(e) and not entity.is_dormant(e) then
                local x, y, z = get_hb(e)
                if x then
                    local ent_hit, dmg = client.trace_bullet(lp, ex, ey, ez, x, y, z)
                    local hittable = (ent_hit == e and (dmg or 0) > 0)
                    local prev = visible_now[e]

                    if hittable and not prev then
                        visible_since[e] = now
                    elseif not hittable and prev then
                        visible_since[e] = nil
                    end
                    visible_now[e] = hittable
                end
            end
        end
    end
)
local shot_info = {}
client.set_event_callback(
    "aim_fire",
    function(e)
        if not ui.get(logs_enable) then
            return
        end

        local tgt = e.target
        local now = globals.realtime()

        shot_info[e.id] = {
            back_t = (e.backtrack) or 0,
            back_t2 = globals.tickcount() - e.tick,
            pred_dmg = e.damage or 0,
            yaw_shot = select(2, client.camera_angles()),
            tick_shot = e.tick or globals.tickcount(),
            time_shot = now,
            vis_since_at_shot = (tgt and visible_since[tgt]) or now
        }
    end
)

client.set_event_callback(
    "round_start",
    function()
        visible_now = {}
        visible_since = {}
        _hb_cache = {}
    end
)
client.set_event_callback(
    "aim_miss",
    function(e)
        if not ui.get(logs_enable) or not log_enabled("Misses") then
            return
        end
        local info = shot_info[e.id]
        shot_info[e.id] = nil
        if not info then
            return
        end

        local flags = ""
        if e.teleported then
            flags = flags .. "T"
        end
        if e.interpolated then
            flags = flags .. "I"
        end
        if e.extrapolated then
            flags = flags .. "E"
        end
        if e.boosted then
            flags = flags .. "B"
        end
        if e.high_priority then
            flags = flags .. "H"
        end
        if flags == "" then
            flags = "-"
        end

        local bt_ticks = (info.back_t > 0 and info.back_t - 1) or (globals.tickcount() - info.tick_shot - 1)
        local bt_ms = ticks_to_ms(bt_ticks)
        local tgt = e.target
        local ox, oy, oz = entity.get_origin(tgt)
        local lp = entity.get_local_player()
        local lx, ly, lz = entity.get_origin(lp)
        local dist = math.sqrt((ox - lx) ^ 2 + (oy - ly) ^ 2 + (oz - lz) ^ 2)

        local hb = e.hitgroup or 0
        local bx, by = (function()
            local x, y = entity.hitbox_position(tgt, hb)
            return x or 0, y or 0
        end)()
        local yaw_to = math.deg(math.atan2(by - oy, bx - ox))
        local ang_off = math.floor(math.abs(((info.yaw_shot - yaw_to + 540) % 360) - 180) + 0.5)

        local title = ("miss %s due to %s"):format(entity.get_player_name(tgt), e.reason)
        local body =
            ("pred:%d | hc:%.1f%% | flags:%s | bt:%dt (%dms) | hb:%s"):format(
            info.pred_dmg or 0,
            e.hit_chance or 0,
            flags,
            bt_ticks,
            bt_ms,
            hitgroup_names[hb + 1] or "?"
        )
        local nice_name = clean_name(entity.get_player_name(tgt))
        local delay_ms = 0
        if info.vis_since_at_shot and info.time_shot and info.vis_since_at_shot < info.time_shot then
            delay_ms = math.floor((info.time_shot - info.vis_since_at_shot) * 1000 + 0.5)
        end

        local extra =
            string.format(
            "reason %s • hc %s • hb %s • bt %dt/%dms • f %s • delay %dms",
            e.reason,
            fmt_percent(e.hit_chance or 0),
            hitgroup_names[(e.hitgroup or 0) + 1] or "?",
            bt_ticks,
            bt_ms,
            flags,
            delay_ms
        )
        sleek_log("miss", nice_name, 0, extra)

        push_log(
            "miss",
            title,
            body,
            clean_name(entity.get_player_name(tgt)),
            0,
            string.format("reason %s • hb %s", e.reason, hitgroup_names[(e.hitgroup or 0) + 1] or "?")
        )
    end
)

client.set_event_callback(
    "aim_hit",
    function(e)
        if not ui.get(logs_enable) or not log_enabled("Hits") then
            return
        end
        local info = shot_info[e.id]
        shot_info[e.id] = nil
        if not info then
            return
        end

        local bt_ticks = (info.back_t > 0 and info.back_t - 1) or (globals.tickcount() - info.tick_shot - 1)
        local bt_ms = ticks_to_ms(bt_ticks)
        local tgt = e.target

        local flags = ""
        if e.teleported then
            flags = flags .. "T"
        end
        if e.interpolated then
            flags = flags .. "I"
        end
        if e.extrapolated then
            flags = flags .. "E"
        end
        if e.boosted then
            flags = flags .. "B"
        end
        if e.high_priority then
            flags = flags .. "H"
        end
        if flags == "" then
            flags = "-"
        end

        local hbname = hitgroup_names[(e.hitgroup or 0) + 1] or tostring(e.hitgroup or "?")
        if rawget(_G, "last_hg_str") then
            last_hg_str[tgt] = hbname
        end

        local title = ("hit %s for %ddmg"):format(entity.get_player_name(tgt), e.damage or 0)
        local body =
            ("pred:%d | hc:%.1f%% | flags:%s | bt:%dt (%dms) | remaining:%d | hb:%s"):format(
            info.pred_dmg or 0,
            e.hit_chance or 0,
            flags,
            bt_ticks,
            bt_ms,
            entity.get_prop(tgt, "m_iHealth") or 0,
            hbname
        )
        local nice_name = clean_name(entity.get_player_name(tgt))
        local delay_ms = 0
        if info.vis_since_at_shot and info.time_shot and info.vis_since_at_shot < info.time_shot then
            delay_ms = math.floor((info.time_shot - info.vis_since_at_shot) * 1000 + 0.5)
        end
        local extra =
            string.format(
            "hc %s • hb %s • bt %dt/%dms • f %s • delay %dms",
            fmt_percent(e.hit_chance or 0),
            hbname,
            bt_ticks,
            bt_ms,
            flags,
            delay_ms
        )
        sleek_log("hit", nice_name, e.damage or 0, extra)

        push_log(
            "hit",
            title,
            body,
            clean_name(entity.get_player_name(tgt)),
            e.damage or 0,
            string.format("hb %s", hbname)
        )
    end
)

client.set_event_callback(
    "round_start",
    function()
    end
)

client.set_event_callback(
    "paint",
    function()
        local dt = globals.frametime()
        osl_update_and_draw(dt)
        draw_oneline(dt)
    end
)
local set_console = my_tabs:add_checkbox("Misc", "LUA", "B", "Console filter")

ui.set_callback(
    set_console,
    function()
        if ui.get(set_console) then
            cvar.developer:set_int(0)
            cvar.con_filter_enable:set_int(1)
            cvar.con_filter_text:set_string("IrWL5106TZZKNFPz4P4Gl3pSN?J370f5hi373ZjPg%VOVh6lN")
            client.exec("con_filter_enable 1")
        else
            cvar.con_filter_enable:set_int(0)
            cvar.con_filter_text:set_string("")
            client.exec("con_filter_enable 0")
        end
    end
)
UI.BuyBot = UI.BuyBot or {}
UI.BuyBot.enable = my_tabs:add_checkbox("Misc", "LUA", "b", "Enable BuyBot")
UI.BuyBot.primary =
    my_tabs:add_combobox("Misc", "LUA", "b", "Primary", "Scout", "AWP", "Auto", "AK/M4", "Famas/Galil", "None")
UI.BuyBot.secondary =
    my_tabs:add_combobox("Misc", "LUA", "b", "Secondary", "Deagle/R8", "Five-Seven/Tec", "P250", "Duals", "None")
UI.BuyBot.armor = my_tabs:add_combobox("Misc", "LUA", "b", "Armor", "Full", "Helmet Only", "None")
UI.BuyBot.nades =
    my_tabs:add_multiselect("Misc", "LUA", "b", "Nades", "HE", "Flash", "Smoke", "Molotov", "Incendiary", "Decoy")
UI.BuyBot.kits = my_tabs:add_checkbox("Misc", "LUA", "b", "Defuse Kit", true)
UI.BuyBot.taser = my_tabs:add_checkbox("Misc", "LUA", "b", "Taser (Zeus)", true)
UI.BuyBot.buy_del = my_tabs:add_slider("Misc", "LUA", "b", "Buy delay (ms)", 0, 2000, 0, true, "ms")

my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.primary,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.secondary,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.armor,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.nades,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.kits,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.taser,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)
my_tabs:add_conditional(
    "Misc",
    UI.BuyBot.buy_del,
    function()
        return ui.get(UI.BuyBot.enable)
    end
)

ui.set_callback(
    UI.BuyBot.enable,
    function()
        my_tabs:update_visibility()
    end
)

_G.buybot_enable = UI.BuyBot.enable
_G.primary = UI.BuyBot.primary
_G.secondary = UI.BuyBot.secondary
_G.armor = UI.BuyBot.armor
_G.nades = UI.BuyBot.nades
_G.kits = UI.BuyBot.kits
_G.taser = UI.BuyBot.taser
_G.buy_del = UI.BuyBot.buy_del

local weapon_map = {
    ["Scout"] = "buy ssg08;",
    ["AWP"] = "buy awp;",
    ["Auto"] = "buy scar20;buy g3sg1;",
    ["AK/M4"] = "buy ak47;buy m4a1;",
    ["Famas/Galil"] = "buy famas;buy galilar;",
    ["Deagle/R8"] = "buy deagle;buy revolver;",
    ["Five-Seven/Tec"] = "buy tec9;buy fiveseven;",
    ["P250"] = "buy p250;",
    ["Duals"] = "buy elite;",
    ["Full"] = "buy vesthelm;",
    ["Helmet Only"] = "buy vest;",
    HE = "buy hegrenade;",
    Flash = "buy flashbang;",
    Smoke = "buy smokegrenade;",
    Molotov = "buy molotov;",
    Incendiary = "buy incgrenade;",
    Decoy = "buy decoy;",
    Kit = "buy defuser;",
    Taser = "buy taser;"
}

function do_buy()
    if not ui.get(buybot_enable) then
        return
    end
    local cmd = ""
    local p, s = ui.get(primary), ui.get(secondary)
    if p and p ~= "None" then
        cmd = cmd .. (weapon_map[p] or "")
    end
    if s and s ~= "None" then
        cmd = cmd .. (weapon_map[s] or "")
    end
    local a = ui.get(armor)
    if a and a ~= "None" then
        cmd = cmd .. (weapon_map[a] or "")
    end
    for _, v in ipairs(ui.get(nades) or {}) do
        cmd = cmd .. (weapon_map[v] or "")
    end
    if ui.get(kits) then
        cmd = cmd .. weapon_map.Kit
    end
    if ui.get(taser) then
        cmd = cmd .. weapon_map.Taser
    end
    if #cmd > 0 then
        client.delay_call(
            (ui.get(buy_del) or 0) / 1000,
            function()
                client.exec(cmd)
            end
        )
    end
end

client.set_event_callback("round_start", do_buy)
last_hc = {}
last_static = {}
last_vel = {}

client.set_event_callback(
    "aim_fire",
    function(e)
        if e.target then
            last_hc[e.target] = e.hit_chance or 0
            local vx = entity.get_prop(e.target, "m_vecVelocity[0]") or 0
            local vy = entity.get_prop(e.target, "m_vecVelocity[1]") or 0
            last_vel[e.target] = math.sqrt(vx * vx + vy * vy)
            last_static[e.target] = (last_vel[e.target] < 5)
        end
    end
)

local aa_stats = {}

client.set_event_callback(
    "aim_fire",
    function(e)
        if e.target then
            aa_stats[e.target] =
                aa_stats[e.target] or {shots = 0, misses = 0, hits = 0, last_reason = "?", last_hc = 0, yaw_hist = {}}
            local info = aa_stats[e.target]
            info.shots = info.shots + 1
            local yaw_now = entity.get_prop(e.target, "m_angEyeAngles[1]") or 0
            table.insert(info.yaw_hist, yaw_now)
            if #info.yaw_hist > 7 then
                table.remove(info.yaw_hist, 1)
            end
            info.last_hc = e.hit_chance or 0
        end
    end
)

client.set_event_callback(
    "aim_hit",
    function(e)
        local s = aa_stats[e.target]
        if s then
            s.hits = s.hits + 1
        end
    end
)

client.set_event_callback(
    "aim_miss",
    function(e)
        local s = aa_stats[e.target]
        if s then
            s.misses = s.misses + 1
            s.last_reason = e.reason or "?"
        end
    end
)

do
    local stats_group = my_tabs:add_label("Misc", "LUA", "a", "Статистика за сессию:")
    local kills_lbl = my_tabs:add_label("Misc", "LUA", "a", "Kills: 0")
    local deaths_lbl = my_tabs:add_label("Misc", "LUA", "a", "Deaths: 0")
    local kd_lbl = my_tabs:add_label("Misc", "LUA", "a", "K/D: 0")
    local hs_lbl = my_tabs:add_label("Misc", "LUA", "a", "HS%: 0")
    local shots_lbl = my_tabs:add_label("Misc", "LUA", "a", "Total shots: 0")
    local hit_lbl = my_tabs:add_label("Misc", "LUA", "a", "Hits: 0")
    local miss_lbl = my_tabs:add_label("Misc", "LUA", "a", "Miss: 0")
    local acc_lbl = my_tabs:add_label("Misc", "LUA", "a", "Accuracy: 0%")
    local reset_btn =
        my_tabs:add_button(
        "Misc",
        "LUA",
        "B",
        "Reset Session Stats",
        function()
            kills, deaths, headshots, shots, hits, misses = 0, 0, 0, 0, 0, 0
        end
    )

    local kills, deaths, headshots, shots, hits, misses = 0, 0, 0, 0, 0, 0

    client.set_event_callback(
        "player_death",
        function(e)
            local me = entity.get_local_player()
            if not me then
                return
            end
            if client.userid_to_entindex(e.attacker) == me then
                kills = kills + 1
                if e.headshot == 1 then
                    headshots = headshots + 1
                end
            end
            if client.userid_to_entindex(e.userid) == me then
                deaths = deaths + 1
            end
        end
    )

    client.set_event_callback(
        "aim_fire",
        function(e)
            if e.target then
                shots = shots + 1
            end
        end
    )

    client.set_event_callback(
        "aim_hit",
        function(e)
            hits = hits + 1
        end
    )

    client.set_event_callback(
        "aim_miss",
        function(e)
            if e.reason == "death" then
                return
            end
            misses = misses + 1
        end
    )

    client.set_event_callback(
        "paint_ui",
        function()
            local kd = deaths > 0 and string.format("%.2f", kills / deaths) or kills
            local hsrate = kills > 0 and string.format("%.1f", (headshots / kills) * 100) or "0"
            local acc = (shots > 0) and string.format("%.1f", (hits / shots) * 100) or "0"
            ui.set(kills_lbl, "Kills: " .. kills)
            ui.set(deaths_lbl, "Deaths: " .. deaths)
            ui.set(kd_lbl, "K/D: " .. kd)
            ui.set(hs_lbl, "HS%: " .. hsrate)
            ui.set(shots_lbl, "Total shots: " .. shots)
            ui.set(hit_lbl, "Hits: " .. hits)
            ui.set(miss_lbl, "Miss: " .. misses)
            ui.set(acc_lbl, "Accuracy: " .. acc .. "%")
        end
    )
end

client.set_event_callback(
    "aim_fire",
    function()
        client.exec("r_cleardecals")
    end
)

local ffi = require("ffi")
local bit = require("bit")
local vector = require("vector")

ffi.cdef [[
    typedef struct {
        char pad_0x0000[0x18];
        float m_flFeetSpeedForwardsOrSideways;
        float m_flFeetSpeedUnknownForwardOrSideways;
        float m_flUnknown2;
        char pad_0x0024[0x4];
        float m_flDuckAmount;
        char pad_0x002C[0x4];
        float m_flFeetWeightedSpeed;
        char pad_0x0034[0x4];
        float m_flUnknown3;
        float m_flSpeedAsPortionOfWalkTopSpeed;
        float m_flSpeedAsPortionOfCrouchTopSpeed;
        char pad_0x0044[0x4];
        float m_flUnknownFraction;
        char pad_0x004C[0x4];
        float m_flUnknownFraction2;
        char pad_0x0054[0x4C];
        float m_flEyeYaw;
        float m_flEyePitch;
        float m_flGoalFeetYaw;
        float m_flCurrentFeetYaw;
        float m_flCurrentTorsoYaw;
        float m_flUnknownVelocityLean;
        char pad_0x00B0[0x4];
        float m_flLeanAmount;
        char pad_0x00B8[0x4];
        float m_flFeetCycle;
        float m_flFeetYawRate;
        char pad_0x00C4[0x4];
        float m_fDuckAmount;
        char pad_0x00CC[0x4];
        float m_vOriginX;
        float m_vOriginY;
        float m_vOriginZ;
        float m_vLastOriginX;
        float m_vLastOriginY;
        float m_vLastOriginZ;
        float m_vVelocityX;
        float m_vVelocityY;
        char pad_0x00F0[0x4];
        float m_flUnknownFloat1;
        char pad_0x00F8[0x8];
        float m_flUnknownFloat2;
        float m_flUnknownFloat3;
        float m_flUnknown;
        float m_flSpeed2D;
        float m_flUpVelocity;
        float m_flSpeedNormalized;
        float m_flFeetSpeedForwardsOrSideways2;
        float m_flFeetSpeedUnknownForwardOrSideways2;
        float m_flTimeSinceStartedMoving;
        float m_flTimeSinceStoppedMoving;
        unsigned char m_bOnGround;
        unsigned char m_bInHitGroundAnimation;
        char pad_0x012A[0x2];
        float m_flLastOriginZ;
        float m_flHeadHeightOrOffsetFromHittingGroundAnimation;
        float m_flStopToFullRunningFraction;
        char pad_0x0138[0x4];
        float m_flMagicFraction;
        char pad_0x0140[0x3C];
        float m_flWorldForce;
        char pad_0x0180[0x5D];
        unsigned char m_bStrafe;
        char pad_0x01DE[0x18];
        float m_flVelocitySubtractX;
        float m_flVelocitySubtractY;
        float m_flVelocitySubtractZ;
    } CCSGOAnimState;

    typedef struct {
        char pad_0x0000[0x18];
        uint32_t m_nSequence;
        float m_flPrevCycle;
        float m_flWeight;
        float m_flWeightDeltaRate;
        float m_flPlaybackRate;
        float m_flCycle;
        void* m_pOwner;
        char pad_0x0038[0x4];
    } CAnimationLayer;
]]

local CONFIG = {
    UPDATE_RATE = 1,
    CLEANUP_INTERVAL = 64,
    MAX_HISTORY = 12,
    CACHE_LIFETIME = 5.0,
    CONFIDENCE_THRESHOLD = 0.25,
    LEARNING_RATE = 0.15,
    CONFIDENCE_DECAY = 0.93,
    ADAPTATION_RATE = 0.2,
    JITTER_MIN_DELTA = 1,
    JITTER_MIN_VARIANCE = 80,
    SPIN_MIN_ROTATION = 140,
    SPIN_CONSISTENCY = 0.75,
    DEFENSIVE_DELTA = 100,
    MAX_DESYNC = 60,
    MIN_DESYNC = -60,
    BRUTEFORCE_THRESHOLD = 3,
    FALLBACK_ANGLES = {0, 58, -58, 45, -45, 30, -30, 25, -25, 15, -15},
    WEIGHTS = {
        velocity = 0.15,
        animation = 0.35,
        pattern = 0.30,
        history = 0.20
    }
}

local Math = {}

local math_abs = math.abs
local math_sqrt = math.sqrt
local math_sin = math.sin
local math_cos = math.cos
local math_atan2 = math.atan2
local math_deg = math.deg
local math_rad = math.rad
local math_min = math.min
local math_max = math.max
local math_floor = math.floor

function Math.normalize_angle(angle)
    if not angle then
        return 0
    end
    angle = angle % 360
    if angle > 180 then
        angle = angle - 360
    elseif angle < -180 then
        angle = angle + 360
    end
    return angle
end

function Math.angle_delta(a, b)
    return math_abs(Math.normalize_angle(a - b))
end

function Math.angle_delta_signed(a, b)
    return Math.normalize_angle(a - b)
end

function Math.clamp(val, min, max)
    if not val then
        return min
    end
    return math_min(math_max(val, min), max)
end

function Math.lerp(a, b, t)
    return a + (b - a) * Math.clamp(t, 0, 1)
end

function Math.distance_2d(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return math_sqrt(dx * dx + dy * dy)
end

function Math.ema(current, new_val, alpha)
    if not current then
        return new_val
    end
    return alpha * new_val + (1 - alpha) * current
end

function Math.calculate_variance(values)
    if not values or #values < 2 then
        return 0
    end

    local sum = 0
    local count = 0

    for i = 1, #values do
        if values[i] then
            sum = sum + values[i]
            count = count + 1
        end
    end

    if count == 0 then
        return 0
    end

    local mean = sum / count
    local variance = 0

    for i = 1, #values do
        if values[i] then
            local diff = values[i] - mean
            variance = variance + diff * diff
        end
    end

    return variance / count
end

function Math.calculate_mean(values)
    if not values or #values == 0 then
        return 0
    end

    local sum = 0
    local count = 0

    for i = 1, #values do
        if values[i] then
            sum = sum + values[i]
            count = count + 1
        end
    end

    return count > 0 and sum / count or 0
end

local FFI = {}

local entity_list_ptr = ffi.cast("void***", client.create_interface("client.dll", "VClientEntityList003"))
local get_client_entity = ffi.cast("void*(__thiscall*)(void*, int)", entity_list_ptr[0][3])

function FFI.get_entity_ptr(ent_index)
    if not ent_index or ent_index == 0 then
        return nil
    end
    local ptr = get_client_entity(entity_list_ptr, ent_index)
    if ptr == nil or ptr == ffi.NULL then
        return nil
    end
    return ptr
end

function FFI.get_anim_state(ent_index)
    local entity_ptr = FFI.get_entity_ptr(ent_index)
    if not entity_ptr then
        return nil
    end

    local anim_state_ptr = ffi.cast("CCSGOAnimState**", ffi.cast("uintptr_t", entity_ptr) + 0x9960)[0]
    if anim_state_ptr == nil or anim_state_ptr == ffi.NULL then
        return nil
    end

    return anim_state_ptr
end

function FFI.get_anim_layer(ent_index, layer_index)
    local entity_ptr = FFI.get_entity_ptr(ent_index)
    if not entity_ptr then
        return nil
    end

    local layers = ffi.cast("CAnimationLayer*", ffi.cast("uintptr_t", entity_ptr) + 0x2990)
    if layers == nil or layers == ffi.NULL then
        return nil
    end

    return layers[layer_index]
end

local function create_angle_record(tick, time, yaw, pitch, goal_feet)
    return {
        t = tick,
        tm = time,
        y = yaw,
        p = pitch,
        gf = goal_feet
    }
end

local function create_velocity_record(tick, speed_2d, vx, vy)
    return {
        t = tick,
        s = speed_2d,
        vx = vx,
        vy = vy
    }
end

local PatternDetector = {}

function PatternDetector.detect_jitter(angle_history)
    if #angle_history < 4 then
        return false, 0, 0
    end

    local deltas = {}
    for i = 1, math_min(8, #angle_history - 1) do
        local curr = angle_history[i]
        local prev = angle_history[i + 1]
        if curr and prev then
            table.insert(deltas, Math.angle_delta(curr.y, prev.y))
        end
    end

    if #deltas < 3 then
        return false, 0, 0
    end

    local mean = Math.calculate_mean(deltas)
    local variance = Math.calculate_variance(deltas)

    local is_jitter = mean > CONFIG.JITTER_MIN_DELTA and variance > CONFIG.JITTER_MIN_VARIANCE

    return is_jitter, mean, variance
end

function PatternDetector.detect_spin(angle_history)
    if #angle_history < 4 then
        return false, 0, 0
    end

    local rotations = {}
    local positive, negative = 0, 0

    for i = 1, math_min(8, #angle_history - 1) do
        local curr = angle_history[i]
        local prev = angle_history[i + 1]
        if curr and prev then
            local delta = Math.angle_delta_signed(curr.y, prev.y)
            table.insert(rotations, math_abs(delta))
            if delta > 0 then
                positive = positive + 1
            else
                negative = negative + 1
            end
        end
    end

    if #rotations < 3 then
        return false, 0, 0
    end

    local total_rotation = 0
    for _, rot in ipairs(rotations) do
        total_rotation = total_rotation + rot
    end

    local consistency = math_max(positive, negative) / #rotations
    local is_spin = consistency > CONFIG.SPIN_CONSISTENCY and total_rotation > CONFIG.SPIN_MIN_ROTATION

    local direction = positive > negative and 1 or -1
    local speed = total_rotation / #rotations

    return is_spin, direction, speed
end

function PatternDetector.detect_defensive(angle_history)
    if #angle_history < 2 then
        return false, 0
    end

    local curr = angle_history[1]
    local prev = angle_history[2]

    if not curr or not prev then
        return false, 0
    end

    local delta = Math.angle_delta(curr.y, prev.y)
    local is_defensive = delta > CONFIG.DEFENSIVE_DELTA

    return is_defensive, curr.y
end

function PatternDetector.detect_side_from_animation(anim_state, body_yaw, lean)
    if not anim_state then
        return 0
    end

    local delta = Math.normalize_angle(anim_state.m_flGoalFeetYaw - anim_state.m_flEyeYaw)

    if delta > CONFIG.MAX_DESYNC * 0.5 then
        return 1
    elseif delta < CONFIG.MIN_DESYNC * 0.5 then
        return -1
    end

    if body_yaw > 0.55 or lean > 0.15 then
        return 1
    elseif body_yaw < 0.45 or lean < -0.15 then
        return -1
    end

    return 0
end

function PatternDetector.analyze_patterns(player_data, anim_state, body_yaw, lean)
    local jitter, jitter_amp, jitter_var = PatternDetector.detect_jitter(player_data.angle_history)
    local spin, spin_dir, spin_speed = PatternDetector.detect_spin(player_data.angle_history)
    local defensive, def_angle = PatternDetector.detect_defensive(player_data.angle_history)
    local side = PatternDetector.detect_side_from_animation(anim_state, body_yaw, lean)

    local pattern_type = "static"
    local pattern_confidence = 0.3

    if defensive then
        pattern_type = "defensive"
        pattern_confidence = 0.9
    elseif jitter then
        pattern_type = "jitter"
        pattern_confidence = Math.clamp(jitter_var / 200, 0.4, 0.85)
    elseif spin then
        pattern_type = "spin"
        pattern_confidence = 0.8
    end

    return {
        type = pattern_type,
        confidence = pattern_confidence,
        side = side,
        jitter = {active = jitter, amplitude = jitter_amp},
        spin = {active = spin, direction = spin_dir, speed = spin_speed},
        defensive = {active = defensive, angle = def_angle}
    }
end

local Predictor = {}

function Predictor.predict_from_velocity(velocity_history, current_yaw)
    if #velocity_history < 2 then
        return current_yaw, 0.1
    end

    local curr = velocity_history[1]
    local prev = velocity_history[2]

    if not curr or not prev then
        return current_yaw, 0.1
    end

    local vel_delta_x = curr.vx - prev.vx
    local vel_delta_y = curr.vy - prev.vy

    if math_abs(vel_delta_x) < 0.5 and math_abs(vel_delta_y) < 0.5 then
        return current_yaw, 0.1
    end

    local vel_angle = math_deg(math_atan2(vel_delta_y, vel_delta_x))
    local predicted = current_yaw + vel_angle * 0.15

    local confidence = Math.clamp(curr.s / 250, 0.1, 0.4)

    return Math.normalize_angle(predicted), confidence
end

function Predictor.predict_from_animation(anim_state, angle_history)
    if not anim_state or #angle_history < 2 then
        return anim_state and anim_state.m_flGoalFeetYaw or 0, 0.2
    end

    local goal_feet = anim_state.m_flGoalFeetYaw
    local yaw_rate = anim_state.m_flFeetYawRate or 0

    local predicted = goal_feet + yaw_rate * 0.25

    if anim_state.m_flSpeed2D > 10 then
        local curr = angle_history[1]
        local prev = angle_history[2]
        if curr and prev then
            local delta = Math.angle_delta_signed(curr.gf, prev.gf)
            predicted = predicted + delta * 0.3
        end
    end

    local confidence = 0.35
    if anim_state.m_flSpeed2D > 50 then
        confidence = confidence + 0.15
    end

    return Math.normalize_angle(predicted), confidence
end

function Predictor.predict_from_pattern(pattern_info, current_angle, realtime)
    local pattern = pattern_info.type
    local predicted = current_angle

    if pattern == "jitter" and pattern_info.jitter.active then
        local amp = pattern_info.jitter.amplitude or 30
        local freq = 2.5
        local time_factor = math_sin(realtime * freq * 2 * 3.14159)
        predicted = current_angle + amp * time_factor * pattern_info.side * 0.6
    elseif pattern == "spin" and pattern_info.spin.active then
        local speed = pattern_info.spin.speed or 180
        local direction = pattern_info.spin.direction or 1
        predicted = current_angle + direction * speed * 0.015625
    elseif pattern == "defensive" and pattern_info.defensive.active then
        predicted = current_angle + pattern_info.side * CONFIG.MAX_DESYNC * 0.8
    end

    return Math.normalize_angle(predicted), pattern_info.confidence
end

function Predictor.predict_from_history(learning_data, movement_state, side, pattern_type)
    if not learning_data or not learning_data[movement_state] then
        return 0, 0.1
    end

    local state_data = learning_data[movement_state]
    if not state_data[side] or not state_data[side][pattern_type] then
        return 0, 0.1
    end

    local bias_entry = state_data[side][pattern_type]
    return bias_entry.value or 0, bias_entry.confidence or 0.1
end

function Predictor.multi_factor_prediction(player_data, anim_state, pattern_info, current_angle)
    local vel_pred, vel_conf = Predictor.predict_from_velocity(player_data.velocity_history, current_angle)
    local anim_pred, anim_conf = Predictor.predict_from_animation(anim_state, player_data.angle_history)
    local pattern_pred, pattern_conf = Predictor.predict_from_pattern(pattern_info, current_angle, globals.realtime())
    local hist_pred, hist_conf =
        Predictor.predict_from_history(
        player_data.learning,
        player_data.movement_state,
        pattern_info.side,
        pattern_info.type
    )

    local predictions = {
        {value = vel_pred, conf = vel_conf, base_weight = CONFIG.WEIGHTS.velocity},
        {value = anim_pred, conf = anim_conf, base_weight = CONFIG.WEIGHTS.animation},
        {value = pattern_pred, conf = pattern_conf, base_weight = CONFIG.WEIGHTS.pattern},
        {value = hist_pred, conf = hist_conf, base_weight = CONFIG.WEIGHTS.history}
    }

    local total_weight = 0
    local weighted_sum = 0
    local total_confidence = 0

    for _, pred in ipairs(predictions) do
        local weight = pred.base_weight * pred.conf
        weighted_sum = weighted_sum + pred.value * weight
        total_weight = total_weight + weight
        total_confidence = total_confidence + pred.conf
    end

    if total_weight == 0 then
        return current_angle, 0.2, "fallback"
    end

    local final_prediction = weighted_sum / total_weight
    local final_confidence = total_confidence / #predictions

    return Math.normalize_angle(final_prediction), final_confidence, "multi_factor"
end

local Learning = {}

function Learning.init_bias_entry()
    return {
        value = 0,
        confidence = 0.5,
        samples = 0,
        hits = 0,
        misses = 0,
        last_update = 0
    }
end

function Learning.update_bias(player_data, was_hit, shot_angle, base_angle)
    local state = player_data.movement_state or "standing"
    local side = player_data.last_side or 0
    local pattern = player_data.last_pattern or "static"

    if not player_data.learning then
        player_data.learning = {}
    end
    if not player_data.learning[state] then
        player_data.learning[state] = {}
    end
    if not player_data.learning[state][side] then
        player_data.learning[state][side] = {}
    end
    if not player_data.learning[state][side][pattern] then
        player_data.learning[state][side][pattern] = Learning.init_bias_entry()
    end

    local entry = player_data.learning[state][side][pattern]
    entry.samples = entry.samples + 1
    entry.last_update = globals.realtime()

    if was_hit then
        entry.hits = entry.hits + 1

        local angle_offset = Math.normalize_angle(shot_angle - base_angle)
        entry.value = Math.ema(entry.value, angle_offset, CONFIG.LEARNING_RATE)

        entry.confidence = math_min(1.0, entry.confidence + CONFIG.LEARNING_RATE * 0.3)
    else
        entry.misses = entry.misses + 1

        entry.confidence = math_max(0.05, entry.confidence * CONFIG.CONFIDENCE_DECAY)
    end
end

function Learning.get_best_fallback(player_data)
    if not player_data.learning then
        return nil, 0.1
    end

    local best_bias = nil
    local best_conf = 0

    for state, state_data in pairs(player_data.learning) do
        for side, side_data in pairs(state_data) do
            for pattern, entry in pairs(side_data) do
                if entry.confidence > best_conf and entry.samples > 2 then
                    best_conf = entry.confidence
                    best_bias = entry.value
                end
            end
        end
    end

    return best_bias, best_conf
end

local Bruteforce = {}

function Bruteforce.get_next_angle(player_data, base_angle)
    local miss_count = player_data.miss_streak or 0

    if miss_count >= CONFIG.BRUTEFORCE_THRESHOLD then
        local index = ((miss_count - CONFIG.BRUTEFORCE_THRESHOLD) % #CONFIG.FALLBACK_ANGLES) + 1
        local offset = CONFIG.FALLBACK_ANGLES[index]

        local side = (miss_count % 2 == 0) and 1 or -1

        return Math.normalize_angle(base_angle + offset * side), "bruteforce"
    end

    return base_angle, "none"
end

local PlayerData = {}
local player_database = {}

function PlayerData.init(ent_index)
    if player_database[ent_index] then
        return player_database[ent_index]
    end

    player_database[ent_index] = {
        angle_history = {},
        velocity_history = {},
        shots_fired = 0,
        shots_hit = 0,
        hit_streak = 0,
        miss_streak = 0,
        learning = {},
        movement_state = "standing",
        last_side = 0,
        last_pattern = "static",
        last_update = globals.realtime(),
        last_resolved_yaw = 0,
        last_resolved_method = "none",
        last_confidence = 0.5
    }

    return player_database[ent_index]
end

function PlayerData.update_history(player_data, tick, time, yaw, pitch, goal_feet, speed_2d, vx, vy)
    table.insert(player_data.angle_history, 1, create_angle_record(tick, time, yaw, pitch, goal_feet))
    if #player_data.angle_history > CONFIG.MAX_HISTORY then
        player_data.angle_history[CONFIG.MAX_HISTORY + 1] = nil
    end

    table.insert(player_data.velocity_history, 1, create_velocity_record(tick, speed_2d, vx, vy))
    if #player_data.velocity_history > CONFIG.MAX_HISTORY then
        player_data.velocity_history[CONFIG.MAX_HISTORY + 1] = nil
    end

    player_data.last_update = time
end

function PlayerData.cleanup()
    local current_time = globals.realtime()
    local to_remove = {}

    for ent_index, data in pairs(player_database) do
        if
            not entity.is_alive(ent_index) or entity.is_dormant(ent_index) or
                current_time - data.last_update > CONFIG.CACHE_LIFETIME
         then
            table.insert(to_remove, ent_index)
        end
    end

    for _, idx in ipairs(to_remove) do
        player_database[idx] = nil
    end
end

local Resolver = {}

function Resolver.extract_entity_data(ent_index)
    local ox, oy, oz = entity.get_origin(ent_index)
    if not ox then
        return nil
    end

    local eye_yaw = entity.get_prop(ent_index, "m_angEyeAngles[1]") or 0
    local eye_pitch = entity.get_prop(ent_index, "m_angEyeAngles[0]") or 0

    local vx = entity.get_prop(ent_index, "m_vecVelocity[0]") or 0
    local vy = entity.get_prop(ent_index, "m_vecVelocity[1]") or 0
    local vz = entity.get_prop(ent_index, "m_vecVelocity[2]") or 0

    local speed_2d = math_sqrt(vx * vx + vy * vy)
    local flags = entity.get_prop(ent_index, "m_fFlags") or 0
    local duck = entity.get_prop(ent_index, "m_flDuckAmount") or 0

    local body_yaw = entity.get_prop(ent_index, "m_flPoseParameter", 11) or 0.5

    local anim_state = FFI.get_anim_state(ent_index)
    local goal_feet = anim_state and anim_state.m_flGoalFeetYaw or eye_yaw
    local lean = anim_state and anim_state.m_flLeanAmount or 0

    local movement_state = "standing"
    if bit.band(flags, 1) == 0 then
        movement_state = "air"
    elseif duck > 0.1 and speed_2d > 50 then
        movement_state = "crouch_move"
    elseif duck > 0.1 then
        movement_state = "crouch"
    elseif speed_2d > 180 then
        movement_state = "running"
    elseif speed_2d > 50 then
        movement_state = "walking"
    elseif speed_2d > 5 then
        movement_state = "slow_walk"
    end

    return {
        eye_yaw = eye_yaw,
        eye_pitch = eye_pitch,
        goal_feet = goal_feet,
        vx = vx,
        vy = vy,
        vz = vz,
        speed_2d = speed_2d,
        movement_state = movement_state,
        anim_state = anim_state,
        body_yaw = body_yaw,
        lean = lean,
        on_ground = bit.band(flags, 1) == 1
    }
end

function Resolver.resolve(ent_index)
    if not ent_index or ent_index == 0 or not entity.is_alive(ent_index) or entity.is_dormant(ent_index) then
        return nil
    end

    local data = Resolver.extract_entity_data(ent_index)
    if not data then
        return nil
    end

    local player_data = PlayerData.init(ent_index)

    local tick = globals.tickcount()
    local time = globals.realtime()
    PlayerData.update_history(
        player_data,
        tick,
        time,
        data.eye_yaw,
        data.eye_pitch,
        data.goal_feet,
        data.speed_2d,
        data.vx,
        data.vy
    )

    player_data.movement_state = data.movement_state

    local pattern_info = PatternDetector.analyze_patterns(player_data, data.anim_state, data.body_yaw, data.lean)

    player_data.last_side = pattern_info.side
    player_data.last_pattern = pattern_info.type

    local predicted_yaw, confidence, method

    if player_data.miss_streak >= CONFIG.BRUTEFORCE_THRESHOLD then
        predicted_yaw, method = Bruteforce.get_next_angle(player_data, data.goal_feet)
        confidence = 0.6
    else
        predicted_yaw, confidence, method =
            Predictor.multi_factor_prediction(player_data, data.anim_state, pattern_info, data.goal_feet)

        if confidence < CONFIG.CONFIDENCE_THRESHOLD then
            local fallback_bias, fallback_conf = Learning.get_best_fallback(player_data)
            if fallback_bias and fallback_conf > confidence then
                predicted_yaw = Math.normalize_angle(data.goal_feet + fallback_bias)
                confidence = fallback_conf
                method = "learned_fallback"
            end
        end
    end

    player_data.last_resolved_yaw = predicted_yaw
    player_data.last_resolved_method = method
    player_data.last_confidence = confidence

    plist.set(ent_index, "Force body yaw", true)
    plist.set(ent_index, "Force body yaw value", Math.clamp(predicted_yaw, -60, 60))

    return {
        yaw = predicted_yaw,
        pitch = data.eye_pitch,
        confidence = confidence,
        method = method,
        pattern = pattern_info.type,
        side = pattern_info.side
    }
end

function Resolver.on_shot(ent_index, was_hit)
    local player_data = player_database[ent_index]
    if not player_data then
        return
    end

    player_data.shots_fired = player_data.shots_fired + 1

    if was_hit then
        player_data.shots_hit = player_data.shots_hit + 1
        player_data.hit_streak = player_data.hit_streak + 1
        player_data.miss_streak = 0

        Learning.update_bias(
            player_data,
            true,
            player_data.last_resolved_yaw,
            player_data.angle_history[1] and player_data.angle_history[1].gf or 0
        )
    else
        player_data.miss_streak = player_data.miss_streak + 1
        player_data.hit_streak = 0

        Learning.update_bias(
            player_data,
            false,
            player_data.last_resolved_yaw,
            player_data.angle_history[1] and player_data.angle_history[1].gf or 0
        )
    end
end
local function compensate_lag(player_data, predicted_yaw)
    if not ui.get(resolver_lag_comp) then
        return predicted_yaw, 1
    end

    local latency = client.latency() or 0
    local lerp_time = cvar.cl_interp:get_float() or 0.015
    local total_delay = latency + lerp_time

    if #player_data.angle_history >= 2 then
        local curr = player_data.angle_history[1]
        local prev = player_data.angle_history[2]

        if curr and prev then
            local yaw_rate = Math.normalize_angle(curr.y - prev.y) / globals.tickinterval()
            local compensation = yaw_rate * total_delay

            return Math.normalize_angle(predicted_yaw + compensation), 1.2
        end
    end

    return predicted_yaw, 1
end
UI.Resolver = UI.Resolver or {}
UI.Resolver.enabled = my_tabs:add_checkbox("Rage", "Lua", "B", "Resolver")

UI.Resolver.label = my_tabs:add_label("Rage", "Lua", "B", "WARNING!")
UI.Resolver.label2 = my_tabs:add_label("Rage", "Lua", "B", "CAN CAUSES MISS AND FPS DROPS")

UI.Resolver.stats_label = my_tabs:add_label("Rage", "Lua", "B", "──────── Statistics ────────")
UI.Resolver.stats_hits = my_tabs:add_label("Rage", "Lua", "B", "Total Hits: 0")
UI.Resolver.stats_accuracy = my_tabs:add_label("Rage", "Lua", "B", "Accuracy: 0%")
UI.Resolver.stats_avg_conf = my_tabs:add_label("Rage", "Lua", "B", "Avg Confidence: 0")

UI.Resolver.experimental_lc = my_tabs:add_checkbox("Rage", "Lua", "B", "Lag Compensation")

my_tabs:add_conditional(
    "Rage",
    UI.Resolver.label,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.label2,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.stats_label,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.stats_hits,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.stats_accuracy,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.stats_avg_conf,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)
my_tabs:add_conditional(
    "Rage",
    UI.Resolver.experimental_lc,
    function()
        return ui.get(UI.Resolver.enabled)
    end
)

ui.set_callback(
    UI.Resolver.enabled,
    function()
        my_tabs:update_visibility()
    end
)

_G.resolver_enabled = UI.Resolver.enabled
_G.label = UI.Resolver.label
_G.label2 = UI.Resolver.label2
_G.stats_label = UI.Resolver.stats_label
_G.stats_hits = UI.Resolver.stats_hits
_G.stats_accuracy = UI.Resolver.stats_accuracy
_G.stats_avg_conf = UI.Resolver.stats_avg_conf
_G.experimental_lc = UI.Resolver.experimental_lc
function update_statistics()
    local total_shots = 0
    local total_hits = 0
    local total_conf = 0
    local player_count = 0

    for _, pdata in pairs(player_database) do
        total_shots = total_shots + pdata.shots_fired
        total_hits = total_hits + pdata.shots_hit
        total_conf = total_conf + pdata.last_confidence
        player_count = player_count + 1
    end

    local accuracy = total_shots > 0 and (total_hits / total_shots * 100) or 0
    local avg_conf = player_count > 0 and (total_conf / player_count) or 0

    ui.set(UI.stats_hits, string.format("Total Hits: %d/%d", total_hits, total_shots))
    ui.set(UI.stats_accuracy, string.format("Accuracy: %.1f%%", accuracy))
    ui.set(UI.stats_avg_conf, string.format("Avg Confidence: %.2f", avg_conf))
end

local last_cleanup_tick = 0
local frame_counter = 0

client.set_event_callback(
    "run_command",
    function(cmd)
        if not ui.get(resolver_enabled) then
            return
        end

        local tick = globals.tickcount()

        if tick - last_cleanup_tick >= CONFIG.CLEANUP_INTERVAL then
            PlayerData.cleanup()
            last_cleanup_tick = tick
        end

        if tick % CONFIG.UPDATE_RATE == 0 then
            for _, ent_index in ipairs(entity.get_players(true)) do
                if entity.is_alive(ent_index) and not entity.is_dormant(ent_index) then
                    Resolver.resolve(ent_index)
                end
            end
        end
    end
)

client.set_event_callback(
    "aim_hit",
    function(e)
        if not ui.get(resolver_enabled) then
            return
        end
        Resolver.on_shot(e.target, true)
    end
)

client.set_event_callback(
    "aim_miss",
    function(e)
        if not ui.get(resolver_enabled) then
            return
        end
        if e.reason == "death" then
            return
        end
        Resolver.on_shot(e.target, false)
    end
)

client.set_event_callback(
    "player_disconnect",
    function(e)
        local victim = client.userid_to_entindex(e.userid)
        if victim and player_database[victim] then
            player_database[victim] = nil
            print("cleaned")
        end
    end
)

client.set_event_callback(
    "round_start",
    function()
    end
)

client.set_event_callback(
    "shutdown",
    function()
        player_database = {}
    end
)

client.color_log(255, 255, 255, "welcome, user")
local http = require "gamesense/http"
local json = require "json"

local abs, min, max, floor = math.abs, math.min, math.max, math.floor
UI.DynamicIsland = UI.DynamicIsland or {}
UI.DynamicIsland.enable = my_tabs:add_checkbox("Visuals", "LUA", "B", "Dynamic Island")
UI.DynamicIsland.theme =
    my_tabs:add_combobox("Visuals", "LUA", "B", "Theme", "Dark", "Glass", "Light", "iOS", "Cyber", "Flat")

UI.DynamicIsland.glow = my_tabs:add_checkbox("Visuals", "LUA", "B", "Ambient glow", true)
UI.DynamicIsland.glow_intensity = my_tabs:add_slider("Visuals", "LUA", "B", "Glow intensity", 0, 200, 100, true, "%")
UI.DynamicIsland.liquid = my_tabs:add_checkbox("Visuals", "LUA", "B", "Liquid motion", true)

UI.DynamicIsland.x_center = my_tabs:add_slider("Visuals", "LUA", "B", "X (center)", 0, 4000, 0, true, "px")
UI.DynamicIsland.y_top = my_tabs:add_slider("Visuals", "LUA", "B", "Y (top)", 0, 2500, 80, true, "px")
UI.DynamicIsland.kbounce = my_tabs:add_slider("Visuals", "LUA", "B", "bounce", 0, 100, 65, true, "%")
UI.DynamicIsland.time = my_tabs:add_slider("Visuals", "LUA", "B", "notice time", 1, 6, 3, true, "s")
UI.DynamicIsland.particles = my_tabs:add_checkbox("Visuals", "LUA", "B", "particles", true)
UI.DynamicIsland.music = my_tabs:add_checkbox("Visuals", "LUA", "B", "Music in island", true)

my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.theme,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.glow,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.liquid,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.kbounce,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.time,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.particles,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.music,
    function()
        return ui.get(UI.DynamicIsland.enable)
    end
)

my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.glow_intensity,
    function()
        return ui.get(UI.DynamicIsland.enable) and ui.get(UI.DynamicIsland.glow)
    end
)

my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.x_center,
    function()
        return false
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.DynamicIsland.y_top,
    function()
        return false
    end
)

ui.set_callback(
    UI.DynamicIsland.enable,
    function()
        my_tabs:update_visibility()
    end
)
ui.set_callback(
    UI.DynamicIsland.glow,
    function()
        my_tabs:update_visibility()
    end
)

_G.di_enable = UI.DynamicIsland.enable
_G.di_theme = UI.DynamicIsland.theme
_G.di_glow = UI.DynamicIsland.glow
_G.di_glow_intensity = UI.DynamicIsland.glow_intensity
_G.di_liquid = UI.DynamicIsland.liquid
_G.di_x_center = UI.DynamicIsland.x_center
_G.di_y = UI.DynamicIsland.y_top
_G.di_kbounce = UI.DynamicIsland.kbounce
_G.di_time = UI.DynamicIsland.time
_G.di_particles = UI.DynamicIsland.particles
_G.di_music = UI.DynamicIsland.music

local function ellipsize(text, max_w, flags)
    if not text or text == "" then
        return ""
    end
    if renderer.measure_text(flags or "", text) <= max_w then
        return text
    end
    local t = text
    while #t > 0 and renderer.measure_text(flags or "", t .. "…") > max_w do
        t = t:sub(1, -2)
    end
    return (t == "" and "…") or (t .. "…")
end

local function clamp(v, a, b)
    return min(max(v, a), b)
end
local function lerp(a, b, t)
    return a + (b - a) * t
end
local function smoothstep(t)
    return t * t * (3 - 2 * t)
end

local function spring_update(s, dt)
    local a = -(s.k or 180) * (s.x - s.target) - (s.d or 18) * s.v
    s.v = s.v + a * dt
    s.x = s.x + s.v * dt
    return s.x
end

local function sec_to_time(ms)
    local sec = floor((ms or 0) / 1000)
    local m = floor(sec / 60)
    local s = sec % 60
    return string.format("%02d:%02d", m, s)
end

local function snap(x)
    return floor(x + 0.5)
end

local function draw_round(x, y, w, h, r, col)
    x, y, w, h = snap(x), snap(y), snap(w), snap(h)
    if renderer.rec then
        renderer.rec(x, y, w, h, r, col)
    else
        renderer.rectangle(x, y + r, w, h - r * 2, col[1], col[2], col[3], col[4])
        renderer.rectangle(x + r, y, w - r * 2, r, col[1], col[2], col[3], col[4])
        renderer.rectangle(x + r, y + h - r, w - r * 2, r, col[1], col[2], col[3], col[4])
        renderer.circle(x + r, y + r, col[1], col[2], col[3], col[4], r, 180, 0.25)
        renderer.circle(x - r + w, y + r, col[1], col[2], col[3], col[4], r, 90, 0.25)
        renderer.circle(x - r + w, y - r + h, col[1], col[2], col[3], col[4], r, 0, 0.25)
        renderer.circle(x + r, y - r + h, col[1], col[2], col[3], col[4], r, -90, 0.25)
    end
end

local function draw_glow(x, y, w, h, r, intensity, col)
    if not ui.get(di_glow) then
        return
    end

    local user_intensity = ui.get(di_glow_intensity) / 100
    intensity = intensity * user_intensity

    local layers = 5
    for i = 1, layers do
        local offset = i * 2.5
        local alpha = floor(intensity * (35 / i))
        if alpha > 0 then
            local glow_col = {col[1], col[2], col[3], alpha}
            draw_round(x - offset, y - offset, w + offset * 2, h + offset * 2, r + offset, glow_col)
        end
    end
end

local liquid_time = 0

local function update_liquid_motion(dt, is_active)
    if not ui.get(di_liquid) then
        return 0, 0
    end

    liquid_time = liquid_time + dt
    local wave1 = math.sin(liquid_time * 2.5) * 3
    local wave2 = math.cos(liquid_time * 3.2) * 2.5
    local wave3 = math.sin(liquid_time * 1.8 + 1.5) * 2

    return is_active and wave1 + wave2 or 0, is_active and wave3 or 0
end

local island = {
    w = {x = 260, v = 0, target = 260, k = 140, d = 22},
    h = {x = 54, v = 0, target = 54, k = 140, d = 22},
    scale = {x = 1, v = 0, target = 1, k = 180, d = 18},
    bright = {x = 0, v = 0, target = 0, k = 120, d = 16},
    glow_pulse = {x = 0, v = 0, target = 0, k = 100, d = 14}
}

local particles = {}
local function spawn_kill_particles(cx, cy)
    if not ui.get(di_particles) then
        return
    end

    for i = 1, 16 do
        local ang = (i / 16) * 6.28318530718
        local spd = 200 + (i % 4) * 40
        particles[#particles + 1] = {
            x = cx,
            y = cy,
            vx = math.cos(ang) * spd,
            vy = (math.sin(ang) - 0.3) * spd,
            life = 0.6,
            t = 0,
            size = 2 + (i % 3)
        }
    end
end

local queue, active = {}, nil

local function fit_width(title_txt, sub_txt, base, pad)
    local tw = renderer.measure_text("b", title_txt or "") or 0
    local sw = renderer.measure_text("", sub_txt or "") or 0
    return math.max(base, 24 + pad * 2 + math.max(tw, sw))
end

local function activate_next()
    if not active and #queue > 0 then
        active = table.remove(queue, 1)
        active.t = 0
        active.t_start = globals.realtime()
        island.w.target = fit_width(active.title, active.sub, 260, 12)
        island.h.target = 54
        island.glow_pulse.target = 1.2
    end
end

local function push_notice(title_txt, sub_txt, color)
    if type(sub_txt) == "table" then
        sub_txt = table.concat(sub_txt, " ")
    end
    queue[#queue + 1] = {
        kind = "kill",
        title = title_txt,
        sub = sub_txt or "",
        color = color or {255, 255, 255},
        life = ui.get(di_time),
        t = 0,
        t_start = globals.realtime(),
        kills = 1
    }
    island.w.target = 280
    island.h.target = 58
    island.scale.target = 1.08
    island.bright.target = 1
    island.glow_pulse.target = 1.5
end

local function push_notice_kill(title_txt, sub_txt, color)
    if type(sub_txt) == "table" then
        sub_txt = table.concat(sub_txt, " ")
    end
    local now = globals.realtime()
    local window_s = 1200 / 1000

    if active and active.kind == "kill" and (now - (active.t_start or now)) <= window_s then
        active.kills = (active.kills or 1) + 1
        active.title = (active.kills >= 2) and ("Multi-Kill x" .. active.kills) or "Kill"
        if sub_txt and sub_txt ~= "" then
            active.sub = sub_txt
        end
        active.life = ui.get(di_time)
        active.t = 0
        active.t_start = now
        island.w.target = fit_width(active.title, active.sub, 260, 12)
        island.glow_pulse.target = 1.8
        return
    end

    if #queue > 0 then
        local last = queue[#queue]
        if last.kind == "kill" and (now - (last.t_start or now)) <= window_s then
            last.kills = (last.kills or 1) + 1
            last.title = (last.kills >= 2) and ("Multi-Kill x" .. last.kills) or "Kill"
            if sub_txt and sub_txt ~= "" then
                last.sub = sub_txt
            end
            last.t_start = now
            return
        end
    end

    push_notice(title_txt or "Well played!", sub_txt or "", color or {255, 255, 255})
end

local streak = {n = 0}
local cover_img, cover_url, artist, title = nil, "", "Artist", "Title"
local last_query = 0
local last_title, track_start_time = "", 0
local duration = 0
local last_hg_str = last_hg_str or {}

local viz_level = 0
local viz_bands = {}
for i = 1, 16 do
    viz_bands[i] = 0
end

local last_sw, last_sh = 0, 0
local function apply_auto_position(force)
    if not ui.get(di_enable) then
        return
    end
    local sw, sh = client.screen_size()
    if force or sw ~= last_sw or sh ~= last_sh then
        ui.set(di_x_center, floor(sw / 2 + 0.5))
        ui.set(di_y, 80)
        last_sw, last_sh = sw, sh
    end
end

ui.set_callback(
    di_enable,
    function()
        apply_auto_position(true)
    end
)

client.set_event_callback(
    "player_death",
    function(e)
        if not ui.get(di_enable) then
            return
        end
        local me = entity.get_local_player()
        local attacker = client.userid_to_entindex(e.attacker)
        local victim = client.userid_to_entindex(e.userid)

        if victim == me then
            streak.n = 0
            return
        end

        if attacker == me and victim ~= nil then
            streak.n = (streak.n or 0) + 1
            local tgt = entity.get_player_name(victim) or "player"
            local hg_s = last_hg_str[victim]
            local subtitle = hg_s and {"Killed", tgt, "in", hg_s} or {"Killed", tgt}
            push_notice_kill("Kill", subtitle, {255, 255, 255})

            local kb = ui.get(di_kbounce) / 100
            island.scale.x = island.scale.x + 0.3 * kb
            island.scale.target = 1
            island.h.x = island.h.x + 20 * kb
            island.h.target = 54

            local cx = (ui.get(di_x_center) or 0)
            local cy = (ui.get(di_y) or 0) + island.h.x / 2
            spawn_kill_particles(cx, cy)
            last_hg_str[victim] = nil
        end
    end
)

client.set_event_callback(
    "round_start",
    function()
        queue = {}
        active = nil
        streak.n = 0
        island.w.target, island.h.target = 260, 54
        island.scale.target, island.bright.target, island.glow_pulse.target = 1, 0, 0
    end
)

client.set_event_callback(
    "net_update_end",
    function()
        if not ui.get(di_enable) or not ui.get(di_music) then
            return
        end
        local now = globals.realtime()
        if now - last_query < (500) / 1000 then
            return
        end
        last_query = now

        local base = "http://127.0.0.1:15351"
        http.get(
            base .. "/music",
            function(success, resp)
                if not success or resp.status ~= 200 then
                    return
                end
                local ok, data = pcall(json.parse, resp.body)
                if not ok or type(data) ~= "table" then
                    return
                end

                artist = data.artist or "Artist"
                title = data.title or "Title"
                duration = data.duration or 0

                if title ~= last_title then
                    track_start_time = globals.realtime()
                    last_title = title
                end

                local need_cover = data.cover and data.cover ~= "" and data.cover ~= cover_url
                if need_cover then
                    cover_url = data.cover
                    http.get(
                        base .. "/cover?url=" .. cover_url,
                        function(img_ok, img_resp)
                            if img_ok and img_resp.status == 200 then
                                cover_img = renderer.load_jpg(img_resp.body, 48, 48)
                            else
                                cover_img = nil
                            end
                        end
                    )
                elseif not data.cover or data.cover == "" then
                    cover_img, cover_url = nil, ""
                end
            end
        )
    end
)

local function theme_colors()
    local t = ui.get(di_theme)
    if t == "Light" then
        return {
            bg = {245, 245, 245, 230},
            txt = {15, 15, 15, 255},
            sub = {60, 60, 60, 220},
            barbg = {45, 45, 45, 110},
            barfg = {30, 144, 255, 255},
            accent = {80, 160, 255},
            glow = {120, 180, 255}
        }
    elseif t == "Glass" then
        return {
            bg = {25, 25, 35, 170},
            txt = {240, 240, 255, 255},
            sub = {200, 200, 220, 220},
            barbg = {80, 80, 110, 120},
            barfg = {160, 190, 255, 255},
            accent = {160, 190, 255},
            glow = {160, 190, 255}
        }
    elseif t == "iOS" then
        return {
            bg = {30, 32, 40, 150},
            txt = {245, 245, 245, 255},
            sub = {200, 205, 220, 230},
            barbg = {90, 95, 110, 120},
            barfg = {255, 255, 255, 220},
            accent = {120, 200, 255},
            glow = {120, 200, 255}
        }
    elseif t == "Cyber" then
        return {
            bg = {12, 12, 16, 210},
            txt = {230, 255, 240, 255},
            sub = {150, 220, 190, 230},
            barbg = {35, 45, 55, 140},
            barfg = {80, 255, 200, 255},
            accent = {80, 255, 200},
            glow = {80, 255, 200}
        }
    elseif t == "Flat" then
        return {
            bg = {22, 22, 26, 230},
            txt = {245, 245, 245, 255},
            sub = {175, 175, 185, 230},
            barbg = {50, 50, 58, 150},
            barfg = {255, 255, 255, 255},
            accent = {255, 255, 255},
            glow = {200, 200, 220}
        }
    elseif t == "Neon" then
        return {
            bg = {10, 10, 15, 240},
            txt = {255, 50, 255, 255},
            sub = {255, 100, 255, 230},
            barbg = {30, 10, 40, 150},
            barfg = {255, 0, 255, 255},
            accent = {255, 0, 200},
            glow = {255, 0, 255}
        }
    elseif t == "Sunset" then
        return {
            bg = {40, 20, 35, 220},
            txt = {255, 200, 150, 255},
            sub = {255, 150, 120, 230},
            barbg = {60, 30, 40, 140},
            barfg = {255, 120, 80, 255},
            accent = {255, 140, 100},
            glow = {255, 120, 80}
        }
    elseif t == "Ocean" then
        return {
            bg = {15, 30, 45, 230},
            txt = {150, 220, 255, 255},
            sub = {120, 200, 240, 230},
            barbg = {25, 50, 70, 140},
            barfg = {50, 180, 255, 255},
            accent = {80, 200, 255},
            glow = {50, 180, 255}
        }
    elseif t == "Forest" then
        return {
            bg = {20, 30, 25, 230},
            txt = {180, 255, 180, 255},
            sub = {150, 230, 150, 230},
            barbg = {30, 45, 35, 140},
            barfg = {100, 220, 120, 255},
            accent = {120, 240, 140},
            glow = {100, 220, 120}
        }
    elseif t == "Candy" then
        return {
            bg = {40, 25, 40, 220},
            txt = {255, 180, 220, 255},
            sub = {255, 150, 200, 230},
            barbg = {60, 40, 60, 140},
            barfg = {255, 100, 180, 255},
            accent = {255, 120, 200},
            glow = {255, 100, 180}
        }
    elseif t == "Nord" then
        return {
            bg = {46, 52, 64, 230},
            txt = {236, 239, 244, 255},
            sub = {216, 222, 233, 230},
            barbg = {59, 66, 82, 140},
            barfg = {136, 192, 208, 255},
            accent = {136, 192, 208},
            glow = {136, 192, 208}
        }
    elseif t == "Dracula" then
        return {
            bg = {40, 42, 54, 230},
            txt = {248, 248, 242, 255},
            sub = {189, 147, 249, 230},
            barbg = {68, 71, 90, 140},
            barfg = {255, 121, 198, 255},
            accent = {255, 121, 198},
            glow = {255, 121, 198}
        }
    elseif t == "Tokyo Night" then
        return {
            bg = {26, 27, 38, 230},
            txt = {169, 177, 214, 255},
            sub = {150, 166, 205, 230},
            barbg = {41, 46, 73, 140},
            barfg = {122, 162, 247, 255},
            accent = {122, 162, 247},
            glow = {122, 162, 247}
        }
    elseif t == "Catppuccin" then
        return {
            bg = {30, 30, 46, 230},
            txt = {205, 214, 244, 255},
            sub = {186, 194, 222, 230},
            barbg = {49, 50, 68, 140},
            barfg = {137, 180, 250, 255},
            accent = {137, 180, 250},
            glow = {137, 180, 250}
        }
    elseif t == "Gruvbox" then
        return {
            bg = {40, 40, 40, 230},
            txt = {235, 219, 178, 255},
            sub = {213, 196, 161, 230},
            barbg = {60, 56, 54, 140},
            barfg = {184, 187, 38, 255},
            accent = {250, 189, 47},
            glow = {184, 187, 38}
        }
    else
        return {
            bg = {12, 12, 14, 230},
            txt = {240, 240, 240, 255},
            sub = {170, 170, 180, 220},
            barbg = {40, 40, 48, 140},
            barfg = {159, 158, 163, 255},
            accent = {140, 180, 255},
            glow = {140, 180, 255}
        }
    end
end

client.set_event_callback(
    "paint",
    function()
        if not ui.get(di_enable) then
            return
        end
        apply_auto_position(false)

        local dt = globals.frametime()
        for _, s in pairs(island) do
            spring_update(s, dt)
        end
        island.bright.target = 0
        island.glow_pulse.target = lerp(island.glow_pulse.target, 0.4, dt * 3)

        local wave_w, wave_h = update_liquid_motion(dt, active ~= nil or ui.get(di_music))
        activate_next()

        if active then
            active.t = active.t + dt
            if active.t >= active.life then
                active = nil
            end
        end

        local base_w = max(220, island.w.x + wave_w)
        local base_h = max(44, island.h.x + wave_h)
        local s = clamp(island.scale.x, 0.85, 1.3)

        local draw_w = floor(base_w * s + 0.5)
        local draw_h = floor(base_h * s + 0.5)
        local cx = ui.get(di_x_center) or 0
        local x = snap(cx - draw_w / 2)
        local y = snap(ui.get(di_y) or 80)

        local col = theme_colors()
        local flash = clamp(island.bright.x, 0, 1)
        local bg = {
            lerp(col.bg[1], 255, flash),
            lerp(col.bg[2], 255, flash),
            lerp(col.bg[3], 255, flash),
            col.bg[4]
        }
        local r = 18

        local glow_intensity = clamp(island.glow_pulse.x, 0.2, 2)
        local pulse = math.sin(globals.realtime() * 2) * 0.15 + 0.85
        draw_glow(x, y, draw_w, draw_h, r, glow_intensity * pulse, col.glow)

        draw_round(x, y, draw_w, draw_h, r, bg)

        if active then
            local pad = 12
            local tw, th = renderer.measure_text("b", active.title or "")
            local sw_, sh_ = renderer.measure_text("", (active.sub ~= "" and active.sub) or " ")
            th, sh_ = th or 0, sh_ or 0
            local tx = snap(x + pad)
            local ty = snap(y + (draw_h - th - (active.sub == "" and 0 or sh_ + 2)) / 2)

            renderer.text(tx, ty, col.txt[1], col.txt[2], col.txt[3], col.txt[4], "b", 0, active.title or "")
            if active.sub ~= "" then
                renderer.text(tx, ty + th + 2, col.sub[1], col.sub[2], col.sub[3], col.sub[4], "", 0, active.sub)
            end
        elseif ui.get(di_music) then
            local pad = 10
            local left = snap(x + pad)
            local top = snap(y + pad)
            local inner_w = draw_w - pad * 2
            local inner_h = draw_h - pad * 2

            local cover_size = inner_h - 4
            if cover_img then
                if ui.get(di_glow) then
                    draw_glow(left - 2, top, cover_size + 4, cover_size + 4, 10, 0.3, col.accent)
                end
                renderer.texture(cover_img, left, top + 2, cover_size, cover_size, 255, 255, 255, 255)
            else
                draw_round(left, top + 2, cover_size, cover_size, 8, {60, 60, 70, 80})
            end

            local reserved_right = 0
            if (streak.n or 0) > 0 then
                local label = "Killstreak: " .. tostring(streak.n)
                local lw = renderer.measure_text("", label) or 0
                local lx = snap(x + draw_w - lw - 10)
                local ly = snap(y + 8)
                renderer.text(lx, ly, col.accent[1], col.accent[2], col.accent[3], 255, "", 0, label)
                reserved_right = lw + 12
            end

            local text_x = left + cover_size + 8
            local text_w = inner_w - cover_size - 8
            local max_title_width = math.max(0, text_w - reserved_right)

            local title_text = title or ""
            local artist_text = artist or ""

            local clipped = ellipsize(title_text, max_title_width, "b")
            renderer.text(snap(text_x), top, col.txt[1], col.txt[2], col.txt[3], 255, "b", 0, clipped)

            local artist_w = math.max(0, text_w - reserved_right)
            local artist_clip = ellipsize(artist_text, artist_w, "")
            renderer.text(snap(text_x), top + 14, col.sub[1], col.sub[2], col.sub[3], col.sub[4], "", 0, artist_clip)

            local bar_h = 6
            local bar_y = snap(y + draw_h - 8 - bar_h)
            local bar_x = snap(text_x)
            local bar_w = snap(text_w)

            local position = floor((globals.realtime() - track_start_time) * 1000)
            local k = (duration > 0) and clamp(position / duration, 0, 1) or 0
            local fill_w = snap(bar_w * k)

            draw_round(bar_x, bar_y, bar_w, bar_h, 2, {col.barbg[1], col.barbg[2], col.barbg[3], col.barbg[4]})
            if fill_w > 0 then
                if ui.get(di_glow) then
                    draw_glow(bar_x - 1, bar_y - 1, fill_w + 2, bar_h + 2, 3, 0.4, col.barfg)
                end
                draw_round(bar_x, bar_y, fill_w, bar_h, 2, {col.barfg[1], col.barfg[2], col.barfg[3], col.barfg[4]})
            end

            local tdiffs = sec_to_time((duration > 0) and (duration - position) or 0)
            local tw2 = renderer.measure_text("b", tdiffs)
            renderer.text(
                snap(bar_x + bar_w - tw2 - 8),
                bar_y - 12,
                col.sub[1],
                col.sub[2],
                col.sub[3],
                col.sub[4],
                "b",
                0,
                "-",
                tdiffs
            )
        end

        for i = #particles, 1, -1 do
            local p = particles[i]
            p.t = p.t + dt
            p.x = p.x + p.vx * dt
            p.y = p.y + p.vy * dt
            p.vy = p.vy + 450 * dt
            local progress = p.t / p.life
            local a = 255 * clamp(1 - progress, 0, 1)

            if a <= 0 then
                table.remove(particles, i)
            else
                local fade = smoothstep(1 - progress)
                local psize = p.size * fade
                renderer.rectangle(snap(p.x), snap(p.y), psize, psize, 255, 255, 255, a)
                if ui.get(di_glow) then
                    renderer.rectangle(snap(p.x - 1), snap(p.y - 1), psize + 2, psize + 2, 255, 255, 255, a * 0.3)
                end
            end
        end
    end
)
do
    local killphrasesgroup = {
        {
            "𝙣𝙚𝙫𝙚𝙧𝙡𝙤𝙨𝙚.𝙘𝙘 𝙞𝙨 𝙤𝙪𝙩𝙙𝙖𝙩𝙚𝙙 𝙨𝙞𝙣𝙘𝙚 𝙜𝙖𝙢𝙚𝙨𝙚𝙣𝙨𝙚.𝙥𝙪𝙗 𝙘𝙧𝙖𝙘𝙠"
        },
        {
            "♛ 𝐠𝐚𝐦𝐞𝐬𝐞𝐧𝐬𝐞 𝐜𝐮𝐥𝐭𝐮𝐫𝐞 ♛"
        },
        {
            "𝐨𝐧𝐥𝐲 𝐧𝐧’𝐬 𝐚𝐬𝐤 𝐰𝐡𝐚𝐭 𝐢𝐦 𝐮𝐬𝐢𝐧𝐠"
        },
        {
            "𝙜𝙖𝙢𝙚𝙨𝙚𝙣𝙨𝙚 𝙗𝙖𝙣𝙬𝙖𝙫𝙚 𝙬𝙖𝙨 𝙖 𝙢𝙞𝙨𝙩𝙖𝙠𝙚"
        },
        {
            "ＳＭＯＫＥＤＯＰＥ２０１６"
        },
        {
            "𝐣𝐨𝐢𝐧 𝐨𝐮𝐫 𝐜𝐥𝐮𝐛 ♛ 𝐠𝐚𝐦𝐞𝐬𝐞𝐧𝐬𝐞.𝐩𝐮𝐛 ♛"
        },
        {
            "𝐩𝐫𝐢𝐯𝐚𝐭𝐞 𝐦𝐞𝐧𝐭𝐚𝐥𝐢𝐭𝐲"
        },
        {
            "𝙨𝙠𝙚𝙚𝙩.𝙘𝙘 𝙖𝙡𝙬𝙖𝙮𝙨 𝙗𝙚 𝙖𝙝𝙚𝙖𝙙"
        },
        {
            "♠ＲＵＳＳＩＡＮ ＲＯＢＢＥＲＹ♠"
        },
        {
            "ｓｋｅｅｔ ｄｏｎｔ ｎｅｅｄ ｕｐｄａｔｅ"
        },
        {
            "𝐨𝐧𝐥𝐲 𝐫𝐞𝐚𝐥 𝐮𝐬𝐞𝐫𝐬 𝐤𝐧𝐨𝐰"
        },
        {
            "♛ 𝐰𝐞𝐥𝐜𝐨𝐦𝐞 𝐭𝐨 𝐠𝐚𝐦𝐞𝐬𝐞𝐧𝐬𝐞 ♛"
        },
        {
            "𝐖𝐄𝐋𝐂𝐎𝐌𝐄 𝐓𝐎 𝐒𝐏𝐎𝐓𝐋𝐈𝐆𝐇𝐓"
        }
    }
    local trashcheck = my_tabs:add_checkbox("Misc", "LUA", "B", "TRASHTALK")
    local trashdelay = my_tabs:add_slider("Misc", "LUA", "B", "Delay", 0, 5, 2, true, "s")

    my_tabs:add_conditional(
        "Misc",
        trashdelay,
        function()
            return ui.get(trashcheck)
        end
    )
    ui.set_callback(
        trashcheck,
        function()
            my_tabs:update_visibility()
        end
    )
    local phrase_index = 1

    local function get_random_phrase_group()
        local phrase = killphrasesgroup[phrase_index]
        phrase_index = phrase_index % #killphrasesgroup + 1
        return phrase
    end

    local function send_phrases_from_group_with_delay(group, delay)
        local accumulated_delay = delay

        for i = 1, #group do
            client.delay_call(
                accumulated_delay,
                function()
                    client.exec("say " .. group[i])
                end
            )

            accumulated_delay = accumulated_delay + 3
        end
    end
    local userid_to_entindex, get_local_player, is_enemy, console_cmd =
        client.userid_to_entindex,
        entity.get_local_player,
        entity.is_enemy,
        client.exec

    local function on_player_death(e)
        if ui.get(trashcheck) then
            local victim_userid, attacker_userid = e.userid, e.attacker
            if victim_userid == nil or attacker_userid == nil then
                return
            end
            local delay = ui.get(trashdelay)
            local victim_entindex = userid_to_entindex(victim_userid)
            local attacker_entindex = userid_to_entindex(attacker_userid)
            local group = get_random_phrase_group()
            if attacker_entindex == get_local_player() and is_enemy(victim_entindex) then
                send_phrases_from_group_with_delay(group, delay)
            end
        end
    end

    client.set_event_callback("player_death", on_player_death)
end
local ffi = require("ffi")
local uix = require("gamesense/uix")
local set_event_callback = client.set_event_callback
local unset_event_callback = client.unset_event_callback
local userid_to_entindex = client.userid_to_entindex
local get_local_player = entity.get_local_player
 GITHUB_TOKEN = "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"

local function create_interface_func(dll, interface, sig, ctype)
    local iface = client.create_interface(dll, interface) or error("invalid interface", 2)
    local addr = client.find_signature(dll, sig) or error("invalid signature", 2)
    local ok, fn_type = pcall(ffi.typeof, ctype)
    if not ok then
        error(fn_type, 2)
    end
    local casted = ffi.cast(fn_type, addr) or error("invalid typecast", 2)
    return function(...)
        return casted(iface, ...)
    end
end

local function vtable_func(dll, interface, index, ctype)
    local iface = client.create_interface(dll, interface) or error("invalid interface")
    local ok, fn_type = pcall(ffi.typeof, ctype)
    if not ok then
        error(fn_type, 2)
    end
    local vtbl = ffi.cast(fn_type, ffi.cast("void***", iface)[0][index]) or error("invalid vtable")
    return function(...)
        return vtbl(iface, ...)
    end
end

local builtin_sounds = {}
local sound_paths = {}
local int_1 = ffi.typeof("int[1]")
local char_arr = ffi.typeof("char[?]")

local fs_find =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xECj\x00\xFFu\x10\xFFu\f\xFFu\b\xE8\xCC\xCC\xCC\xCC]",
    "const char*(__thiscall*)(void*, const char*, const char*, int*)"
)
local fs_find_next =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xEC\x83\xEC\fS\x8Bً\r\xCC\xCC\xCC\xCC",
    "const char*(__thiscall*)(void*, int)"
)
local fs_find_close =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xECS\x8B]\b\x85",
    "void(__thiscall*)(void*, int)"
)
local fs_is_dir =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xEC\x0F\xB7E\b",
    "bool(__thiscall*)(void*, int)"
)

local fs_add_search_path =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xEC\x81\xEC\xCC\xCC\xCC̋U\bSVW",
    "void(__thiscall*)(void*, const char*, const char*, int)"
)

local fs_get_search_path =
    create_interface_func(
    "filesystem_stdio.dll",
    "VFileSystem017",
    "U\x8B\xECV\x8Bu\bV\xFFu\f",
    "bool(__thiscall*)(void*, char*, int)"
)

local cvar_sndplaydelay = cvar.sndplaydelay
local surface_play_sound =
    vtable_func("vguimatsurface.dll", "VGUI_Surface031", 82, "void(__thiscall*)(void*, const char*)")

local function collect_sounds()
    local results = {}
    local handle = int_1()
    local find = fs_find("*", "XGAME", handle)

    while find ~= nil do
        local name = ffi.string(find)
        if not fs_is_dir(handle[0]) and (name:find(".mp3") or name:find(".wav")) then
            results[#results + 1] = name
        end
        find = fs_find_next(handle[0])
    end

    fs_find_close(handle[0])
    return results
end

local function clean_name(name)
    name = name:gsub("_", " ")
    name = name:gsub("%.mp3", "")
    name = name:gsub("%.wav", "")
    return name
end

local function on_hit(event)
    local attacker = userid_to_entindex(event.attacker)
    local victim = userid_to_entindex(event.userid)
    if attacker == get_local_player() and victim ~= get_local_player() then
        local hp = entity.get_prop(victim, "m_iHealth")
        local dmg = event.dmg_health

        if hp ~= nil and dmg ~= nil and dmg >= hp then
            return
        end
        local sound = sound_paths[ui.get(hit_sound_combo)]
        if sound then
            for i = 1, ui.get(volume_slider) do
                surface_play_sound(sound)
            end
        end
    end
end

local function on_kill(event)
    local attacker = userid_to_entindex(event.attacker)
    local victim = userid_to_entindex(event.userid)
    if attacker == get_local_player() and victim ~= get_local_player() then
        local sound = sound_paths[ui.get(kill_sound_combo)]
        if sound then
            cvar_sndplaydelay:invoke_callback(0, sound)
        end
    end
end

local function toggle_visibility(control, state)
    ui.set_visible(hit_sound_combo, state)
    ui.set_visible(kill_sound_combo, state)
    ui.set_visible(volume_slider, state)
end

local function add_sound(display, path)
    builtin_sounds[#builtin_sounds + 1] = display
    sound_paths[display] = path
end

add_sound("Wood stop", "doors/wood_stop1.wav")
add_sound("Wood strain", "physics/wood/wood_strain7.wav")
add_sound("Wood plank impact", "physics/wood/wood_plank_impact_hard4.wav")
add_sound("Warning", "resource/warning.wav")
add_sound("none", "")

local buf = char_arr(128)
fs_get_search_path(buf, ffi.sizeof(buf))
local path = string.format("%s\\csgo\\sound\\hitsounds", ffi.string(buf))
fs_add_search_path(path, "XGAME", 0)

local files = collect_sounds()
for i = 1, #files do
    local file = files[i]
    add_sound(clean_name(file), string.format("hitsounds/%s", file))
end
enable_checkbox = my_tabs:add_checkbox("Misc", "LUA", "B", "Hit/Kill sound")
hit_sound_combo = my_tabs:add_combobox("Misc", "LUA", "B", "Hit sound", builtin_sounds)
kill_sound_combo = my_tabs:add_combobox("Misc", "LUA", "B", "Kill sound", builtin_sounds)
volume_slider = my_tabs:add_slider("Misc", "LUA", "B", "Sound volume", 1, 100, 1, true, "%")

my_tabs:add_conditional(
    "Misc",
    hit_sound_combo,
    function()
        return ui.get(enable_checkbox)
    end
)
my_tabs:add_conditional(
    "Misc",
    kill_sound_combo,
    function()
        return ui.get(enable_checkbox)
    end
)
my_tabs:add_conditional(
    "Misc",
    volume_slider,
    function()
        return ui.get(enable_checkbox)
    end
)

ui.set_callback(
    enable_checkbox,
    function()
        my_tabs:update_visibility()
    end
)
set_event_callback("player_hurt", on_hit)
set_event_callback("player_death", on_kill)

do
    local VK_LBUTTON = 0x01
    local VK_RBUTTON = 0x02
    local dragging = {island = false, logs = false}
    local grab_off = {x = 0, y = 0}
    local prev_rmb = false

    local function island_rect()
        local sw, sh = client.screen_size()
        local w = (island and island.w and (island.w.target or island.w.x)) or 260
        local h = (island and island.h and (island.h.target or island.h.x)) or 54
        w = math.max(220, w)
        h = math.max(44, h)
        local cx = ui.get(di_x_center) or math.floor(sw / 2 + 0.5)
        local x = math.floor(cx - w / 2 + 0.5)
        local y = math.floor((ui.get(di_y) or 80) + 0.5)
        return x, y, math.floor(w + 0.5), math.floor(h + 0.5), cx
    end

    local function logs_rect()
        local sw, sh = client.screen_size()
        local w = (ui.get(osl_width) or 440)
        local h = 2 * 10 + 18 + (18 - 2)
        local cx = ui.get(osl_center_x) or math.floor(sw / 2 + 0.5)
        local cy = ui.get(osl_center_y) or math.floor(sh * 0.55 + 0.5)
        local x = math.floor(cx - w / 2 + 0.5)
        local y = math.floor(cy - h / 2 + 0.5)
        return x, y, w, h, cx, cy
    end

    local function inside(mx, my, x, y, w, h)
        return mx >= x and mx <= x + w and my >= y and my <= y + h
    end

    local function draw_guide_v(x)
        local sw, sh = client.screen_size()
        renderer.rectangle(x, 0, 1, sh, 255, 255, 255, 40)
    end
    local function draw_guide_h(y)
        local sw, sh = client.screen_size()
        renderer.rectangle(0, y, sw, 1, 255, 255, 255, 40)
    end

    local function draw_preview_round(x, y, w, h, r, a)
        if renderer.rec then
            renderer.rec(x, y, w, h, r, {20, 22, 30, a})
        else
            renderer.rectangle(x, y + r, w, h - r * 2, 20, 22, 30, a)
            renderer.rectangle(x + r, y, w - r * 2, r, 20, 22, 30, a)
            renderer.rectangle(x + r, y + h - r, w - r * 2, r, 20, 22, 30, a)
            renderer.circle(x + r, y + r, 20, 22, 30, a, r, 180, 0.25)
            renderer.circle(x - r + w, y + r, 20, 22, 30, a, r, 90, 0.25)
            renderer.circle(x - r + w, y - r + h, 20, 22, 30, a, r, 0, 0.25)
            renderer.circle(x + r, y - r + h, 20, 22, 30, a, r, -90, 0.25)
        end
    end
end

do
    local VK_LBUTTON = 0x01
    local VK_RBUTTON = 0x02
    local dragging = {island = false, logs = false}
    local grab_off = {x = 0, y = 0}
    local prev_rmb = false

    local function island_rect()
        local sw, sh = screen()
        local w = 260
        local h = 54
        if rawget(_G, "island") and type(island) == "table" and island.w and island.h then
            w = tonumber(island.w.target or island.w.x) or w
            h = tonumber(island.h.target or island.h.x) or h
        end
        w = math.max(220, w)
        h = math.max(44, h)

        local cx = tonumber(ui.get and di_x_center and ui.get(di_x_center)) or (sw / 2)
        local yv = tonumber(ui.get and di_y and ui.get(di_y)) or 80

        local x = math.floor(cx - w / 2 + 0.5)
        local y = math.floor(yv + 0.5)
        return x, y, math.floor(w + 0.5), math.floor(h + 0.5), cx, yv
    end

    local function logs_rect()
        local sw, sh = screen()
        local w = tonumber(ui.get and osl_width and ui.get(osl_width)) or 440
        local h = 2 * 10 + 18 + (18 - 2)
        local cx = tonumber(ui.get and osl_center_x and ui.get(osl_center_x)) or math.floor(sw / 2 + 0.5)
        local cy = tonumber(ui.get and osl_center_y and ui.get(osl_center_y)) or math.floor(sh * 0.55 + 0.5)
        local x = math.floor(cx - w / 2 + 0.5)
        local y = math.floor(cy - h / 2 + 0.5)
        return x, y, w, h, cx, cy
    end

    local function inside(mx, my, x, y, w, h)
        return mx and my and x and y and w and h and mx >= x and mx <= x + w and my >= y and my <= y + h
    end

    local function draw_guide_v(x)
        if not x then
            return
        end
        local sw, sh = screen()
        renderer.rectangle(x, 0, 1, sh, 255, 255, 255, 40)
    end
    local function draw_guide_h(y)
        if not y then
            return
        end
        local sw, sh = screen()
        renderer.rectangle(0, y, sw, 1, 255, 255, 255, 40)
    end

    local function draw_preview_round(x, y, w, h, r, a)
        if renderer.rec then
            renderer.rec(x, y, w, h, r, {20, 22, 30, a})
        else
            renderer.rectangle(x, y + r, w, h - r * 2, 20, 22, 30, a)
            renderer.rectangle(x + r, y, w - r * 2, r, 20, 22, 30, a)
            renderer.rectangle(x + r, y + h - r, w - r * 2, r, 20, 22, 30, a)
            renderer.circle(x + r, y + r, 20, 22, 30, a, r, 180, 0.25)
            renderer.circle(x - r + w, y + r, 20, 22, 30, a, r, 90, 0.25)
            renderer.circle(x - r + w, y - r + h, 20, 22, 30, a, r, 0, 0.25)
            renderer.circle(x + r, y - r + h, 20, 22, 30, a, r, -90, 0.25)
        end
    end

    client.set_event_callback(
        "paint_ui",
        function()
            if not ui.is_menu_open() then
                dragging.island, dragging.logs = false, false
                prev_rmb = false
                return
            end

            local sw, sh = client.screen_size()
            if (ui.get(osl_center_x) or 0) == 0 then
                ui.set(osl_center_x, math.floor(sw / 2 + 0.5))
            end
            if (ui.get(osl_center_y) or 0) == 0 then
                ui.set(osl_center_y, math.floor(sh * 0.55 + 0.5))
            end
            if not ui.get(di_x_center) then
                ui.set(di_x_center, math.floor(sw / 2 + 0.5))
            end
            if not ui.get(di_y) then
                ui.set(di_y, 80)
            end

            local ix, iy, iw, ih = island_rect()
            local lx, ly, lw, lh = logs_rect()

            local center_x = math.floor(sw / 2 + 0.5)
            local thirds_y1 = math.floor(sh / 3 + 0.5)
            local thirds_y2 = math.floor(sh * 2 / 3 + 0.5)
            local default_island_y = 80
            draw_guide_v(center_x)
            draw_guide_h(thirds_y1)
            draw_guide_h(thirds_y2)

            draw_preview_round(ix, iy, iw, ih, 18, 120)
            renderer.text(ix + 10, iy - 14, 200, 220, 255, 180, "", 0, "Dynamic Island (drag / RMB reset)")

            if ui.get(osl_style) == "Liquid Glass" and draw_glass then
                draw_glass(lx, ly, lw, lh, {base = {60, 70, 92, 110}, radius = 18, mist = {255, 255, 255, 12}})
            else
                draw_preview_round(lx, ly, lw, lh, 14, 150)
            end
            renderer.text(lx + 10, ly - 14, 200, 220, 255, 180, "", 0, "On-screen Logs (drag / RMB reset)")

            local mx, my = ui.mouse_position()
            local lmb = client.key_state(VK_LBUTTON) == true
            local rmb = client.key_state(VK_RBUTTON) == true
            local rmb_click = rmb and (not prev_rmb)

            if rmb_click then
                if inside(mx, my, ix, iy, iw, ih) then
                    ui.set(di_x_center, math.floor(sw / 2 + 0.5))
                    ui.set(di_y, default_island_y)
                elseif inside(mx, my, lx, ly, lw, lh) then
                    ui.set(osl_center_x, math.floor(sw / 2 + 0.5))
                    ui.set(osl_center_y, math.floor(sh * 0.75 + 0.5))
                end
            end
            prev_rmb = rmb

            local snap_dx, snap_dy = 10, 10

            if not dragging.island and lmb and inside(mx, my, ix, iy, iw, ih) then
                dragging.island = true
                grab_off.x = mx - (ui.get(di_x_center) or (ix + iw / 2))
                grab_off.y = my - (ui.get(di_y) or iy)
            end
            if dragging.island then
                local new_cx = mx - grab_off.x
                local new_y = my - grab_off.y
                if math.abs(new_cx - center_x) <= snap_dx then
                    new_cx = center_x
                end
                if math.abs(new_y - default_island_y) <= snap_dy then
                    new_y = default_island_y
                end
                if math.abs(new_y - thirds_y1) <= snap_dy then
                    new_y = thirds_y1
                end
                if math.abs(new_y - thirds_y2) <= snap_dy then
                    new_y = thirds_y2
                end
                ui.set(di_x_center, math.max(0, math.min(sw, math.floor(new_cx + 0.5))))
                ui.set(di_y, math.max(0, math.min(sh, math.floor(new_y + 0.5))))
                if not lmb then
                    dragging.island = false
                end
            end

            if not dragging.logs and lmb and inside(mx, my, lx, ly, lw, lh) then
                dragging.logs = true
                grab_off.x = mx - (ui.get(osl_center_x) or (lx + lw / 2))
                grab_off.y = my - (ui.get(osl_center_y) or (ly + lh / 2))
            end
            if dragging.logs then
                local new_cx = mx - grab_off.x
                local new_cy = my - grab_off.y
                if math.abs(new_cx - center_x) <= snap_dx then
                    new_cx = center_x
                end
                if math.abs(new_cy - thirds_y1) <= snap_dy then
                    new_cy = thirds_y1
                end
                if math.abs(new_cy - thirds_y2) <= snap_dy then
                    new_cy = thirds_y2
                end
                ui.set(osl_center_x, math.max(0, math.min(sw, math.floor(new_cx + 0.5))))
                ui.set(osl_center_y, math.max(0, math.min(sh, math.floor(new_cy + 0.5))))
                if not lmb then
                    dragging.logs = false
                end
            end
        end
    )
end

do
    local shown = false
    local started_at = globals.realtime()
    local fallback = nil

    local function _snap(x)
        return math.floor(x + 0.5)
    end
    local function _draw_round(x, y, w, h, r, col)
        x, y, w, h = _snap(x), _snap(y), _snap(w), _snap(h)
        if renderer.rec then
            renderer.rec(x, y, w, h, r, col)
        else
            renderer.rectangle(x, y + r, w, h - r * 2, col[1], col[2], col[3], col[4])
            renderer.rectangle(x + r, y, w - r * 2, r, col[1], col[2], col[3], col[4])
            renderer.rectangle(x + r, y + h - r, w - r * 2, r, col[1], col[2], col[3], col[4])
            renderer.circle(x + r, y + r, col[1], col[2], col[3], col[4], r, 180, 0.25)
            renderer.circle(x - r + w, y + r, col[1], col[2], col[3], col[4], r, 90, 0.25)
            renderer.circle(x - r + w, y - r + h, col[1], col[2], col[3], col[4], r, 0, 0.25)
            renderer.circle(x + r, y - r + h, col[1], col[2], col[3], col[4], r, -90, 0.25)
        end
    end

    local function try_show_welcome()
        if shown then
            return
        end
        shown = true

        local lp = entity.get_local_player()
        local nick = (lp and entity.get_player_name(lp)) or "друг"
        local title = ("Привет, %s!"):format(nick)
        local sub = "Скрипт загружен - удачной игры!✨"

        if type(osl_push) == "function" and (ui.get and ui.get(osl_enable)) then
            osl_push("info", title, sub)
        elseif type(push_notice) == "function" then
            push_notice(title, sub, {255, 255, 255})
        elseif type(push_notice_kill) == "function" then
            push_notice_kill(title, sub, {255, 255, 255})
        else
            fallback = {t = 0, life = 2.8, title = title, sub = sub}
        end
    end

    client.set_event_callback(
        "paint",
        function()
            if not shown and globals.realtime() - started_at > 0.15 then
                try_show_welcome()
            end

            if fallback then
                local dt = globals.frametime()
                fallback.t = fallback.t + dt
                local k = fallback.t / fallback.life
                if k >= 1 then
                    fallback = nil
                    return
                end

                local sw, sh = client.screen_size()
                local w = 360
                local h = (fallback.sub ~= "" and 64 or 44)
                local x = _snap((sw - w) / 2)
                local y = _snap(sh * 0.20)

                local a
                if k < 0.15 then
                    a = math.floor(255 * (k / 0.15) + 0.5)
                elseif k > 0.85 then
                    a = math.floor(255 * ((1 - k) / 0.15) + 0.5)
                else
                    a = 255
                end
                local bgA = math.min(180, a)

                _draw_round(x, y, w, h, 12, {20, 22, 30, bgA})
                renderer.circle(x + 10, y + h / 2, 120, 200, 255, math.min(235, a), 3, 360, 1)

                local tx = x + 24
                local ty = y + 8
                renderer.text(tx, ty, 255, 255, 255, a, "b", 0, fallback.title or "")
                if fallback.sub and fallback.sub ~= "" then
                    renderer.text(tx, ty + 18, 205, 210, 220, math.min(230, a), "", 0, fallback.sub)
                end
            end
        end
    )
end

do
    UI.Evaded = UI.Evaded or {}
    UI.Evaded.enabled = my_tabs:add_checkbox("Visuals", "Lua", "B", "Log evaded shots")
    UI.Evaded.col = my_tabs:add_color_picker("Visuals", "Lua", "B", "Evaded color", 120, 220, 120, 255)
    UI.Evaded.show_distance = my_tabs:add_checkbox("Visuals", "Lua", "B", "Show miss distance")
    my_tabs:add_conditional(
        "Visuals",
        UI.Evaded.col,
        function()
            return ui.get(UI.Evaded.enabled)
        end
    )
    my_tabs:add_conditional(
        "Visuals",
        UI.Evaded.show_distance,
        function()
            return ui.get(UI.Evaded.enabled)
        end
    )
    ui.set_callback(
        UI.Evaded.enabled,
        function()
            my_tabs:update_visibility()
        end
    )

    _G.evadeenable = _G.enabled or UI.Evaded.enabled
    _G.evaded_col = UI.Evaded.col
    _G.show_distance = UI.Evaded.show_distance
    local shots = {}
    local hitgroup_names = {
        [0] = "generic",
        [1] = "head",
        [2] = "chest",
        [3] = "stomach",
        [4] = "left arm",
        [5] = "right arm",
        [6] = "left leg",
        [7] = "right leg"
    }

    local function push_evaded(kind, title, msg)
        push_log(kind, title, msg)
    end

    local function len2(x, y, z)
        return x * x + y * y + z * z
    end
    local function len(x, y, z)
        return math.sqrt(len2(x, y, z))
    end

    local function seg_point_dist(p1, p2, p)
        local vx, vy, vz = p2[1] - p1[1], p2[2] - p1[2], p2[3] - p1[3]
        local wx, wy, wz = p[1] - p1[1], p[2] - p1[2], p[3] - p1[3]
        local vv = len2(vx, vy, vz)
        local t = vv > 0 and (vx * wx + vy * wy + vz * wz) / vv or 0
        if t < 0 then
            t = 0
        elseif t > 1 then
            t = 1
        end
        local cx, cy, cz = p1[1] + t * vx, p1[2] + t * vy, p1[3] + t * vz
        local dx, dy, dz = p[1] - cx, p[2] - cy, p[3] - cz
        return math.sqrt(len2(dx, dy, dz))
    end

    local function is_enemy(ent)
        local me = entity.get_local_player()
        return me and ent and ent ~= me and entity.is_enemy(ent)
    end

    local function eye_pos(ent)
        local x, y, z = entity.get_prop(ent, "m_vecOrigin")
        if not x then
            return 0, 0, 0
        end
        local vz = entity.get_prop(ent, "m_vecViewOffset[2]") or 64
        return x, y, z + vz
    end

    local function get_body_positions(ent)
        local mx, my, mz = entity.get_prop(ent, "m_vecOrigin")
        if not mx then
            return {}
        end
        local vo = entity.get_prop(ent, "m_vecViewOffset[2]") or 64

        return {
            head = {mx, my, mz + vo - 2},
            neck = {mx, my, mz + vo - 12},
            chest = {mx, my, mz + vo - 24},
            stomach = {mx, my, mz + vo - 40},
            pelvis = {mx, my, mz + vo - 52},
            legs = {mx, my, mz + 20},
            center = {mx, my, mz + vo * 0.5}
        }
    end

    local function get_closest_bodypart(eye_pos, impact, body_positions)
        local min_dist = math.huge
        local closest_part = "body"

        for part, pos in pairs(body_positions) do
            local dist = seg_point_dist(eye_pos, impact, pos)
            if dist < min_dist then
                min_dist = dist
                closest_part = part
            end
        end

        return closest_part, min_dist
    end

    client.set_event_callback(
        "weapon_fire",
        function(e)
            if not ui.get(evadeenable) then
                return
            end
            local att = client.userid_to_entindex(e.userid)
            if not is_enemy(att) then
                return
            end

            local ex, ey, ez = eye_pos(att)
            shots[att] = {
                t = globals.curtime(),
                impact = nil,
                eye = {ex, ey, ez},
                near = false,
                hit = false,
                done = false,
                dist = 0,
                bodypart = ""
            }
        end
    )

    client.set_event_callback(
        "bullet_impact",
        function(e)
            if not ui.get(evadeenable) then
                return
            end
            local att = client.userid_to_entindex(e.userid)
            local s = shots[att]
            if not (s and is_enemy(att)) then
                return
            end

            local ix, iy, iz = e.x, e.y, e.z
            s.impact = {ix, iy, iz}

            local me = entity.get_local_player()
            if not me then
                return
            end

            local body_pos = get_body_positions(me)
            local bodypart, dist = get_closest_bodypart(s.eye, s.impact, body_pos)

            s.bodypart = bodypart
            s.dist = dist

            local thresh = 38

            local thresholds = {
                head = thresh * 0.6,
                neck = thresh * 0.7,
                chest = thresh * 1.0,
                stomach = thresh * 1.0,
                pelvis = thresh * 1.1,
                legs = thresh * 1.2,
                center = thresh * 1.0
            }

            local current_thresh = thresholds[bodypart] or thresh
            s.near = (dist <= current_thresh)
        end
    )

    client.set_event_callback(
        "player_hurt",
        function(e)
            if not ui.get(evadeenable) then
                return
            end
            local me = entity.get_local_player()
            if client.userid_to_entindex(e.userid) ~= me then
                return
            end
            local att = client.userid_to_entindex(e.attacker)
            local s = shots[att]
            if not s then
                return
            end
            s.hit = true
            s.hitgroup = e.hitgroup or 0
        end
    )

    client.set_event_callback(
        "paint",
        function()
            if not ui.get(evadeenable) or not entity.is_alive(entity.get_local_player()) then
                return
            end
            local now = globals.curtime()

            for att, s in pairs(shots) do
                if not s.done and now - s.t > 0.1 then
                    if s.near and not s.hit then
                        local name = entity.get_player_name(att) or "enemy"
                        local bodypart_nice = s.bodypart:sub(1, 1):upper() .. s.bodypart:sub(2)

                        local title = "Evaded shot from " .. name
                        local msg = " "

                        if ui.get(show_distance) then
                            msg = string.format("Shot was in %s | %.1fu away", bodypart_nice, s.dist)
                        else
                            msg = string.format("Shot was in %s", bodypart_nice)
                        end

                        push_evaded("evade", "" .. title, msg)
                        s.done = true
                    elseif s.hit then
                        s.done = true
                    else
                        s.done = true
                    end
                end

                if now - s.t > 3.0 then
                    shots[att] = nil
                end
            end
        end
    )

    client.set_event_callback(
        "round_start",
        function()
            shots = {}
        end
    )
    client.set_event_callback(
        "level_init",
        function()
            shots = {}
        end
    )
end

do
    UI.Watermark = UI.Watermark or {}
    UI.Watermark.title = "exponential"
    UI.Watermark.pos =
        my_tabs:add_combobox(
        "Visuals",
        "LUA",
        "B",
        "watermark position",
        "top-left",
        "top-center",
        "top-right",
        "bottom-left",
        "bottom-center",
        "bottom-right"
    )
    UI.Watermark.info = my_tabs:add_multiselect("Visuals", "LUA", "B", "watermark info", "time", "ping", "tickrate")
    UI.Watermark.col = my_tabs:add_color_picker("Visuals", "LUA", "B", "text color", 255, 255, 255, 255)
    UI.Watermark.bg = my_tabs:add_checkbox("Visuals", "LUA", "B", "background", true)
    UI.Watermark.bgcol = my_tabs:add_color_picker("Visuals", "LUA", "B", "background color", 10, 12, 16, 140)
    UI.Watermark.shadow = my_tabs:add_checkbox("Visuals", "LUA", "B", "text shadow", true)
    my_tabs:add_conditional(
        "Visuals",
        UI.Watermark.bgcol,
        function()
            return ui.get(UI.Watermark.bg)
        end
    )

    ui.set_callback(
        UI.Watermark.bg,
        function()
            my_tabs:update_visibility()
        end
    )

    _G.wm_pos = UI.Watermark.pos
    _G.wm_info = UI.Watermark.info
    _G.wm_col = UI.Watermark.col
    _G.wm_bg = UI.Watermark.bg
    _G.wm_bgcol = UI.Watermark.bgcol
    _G.wm_shadow = UI.Watermark.shadow
    _G.wm_title = UI.Watermark.title

    client.set_event_callback(
        "paint",
        function()
            local sw, sh = client.screen_size()

            local sel = ui.get(wm_info)
            local want_time, want_ping, want_fps, want_tick = false, false, false, false
            if type(sel) == "table" then
                for i = 1, #sel do
                    local v = sel[i]
                    if v == "time" then
                        want_time = true
                    elseif v == "ping" then
                        want_ping = true
                    elseif v == "tickrate" then
                        want_tick = true
                    end
                end
            end

            local H, M, S = client.system_time()
            local ping = math.floor((client.latency() or 0) * 1000 + 0.5)
            local tick = math.floor(1 / globals.tickinterval() + 0.5)

            local text = wm_title
            if want_time then
                text = text .. "  |  " .. ("%02d:%02d:%02d"):format(H, M, S)
            end
            if want_ping then
                text = text .. "  |  " .. ("%dms"):format(ping)
            end
            if want_tick then
                text = text .. "  |  " .. ("%dtick"):format(tick)
            end

            local tw, th = renderer.measure_text("b", text)
            local pad_x, pad_y = 8, 5
            local w, h = tw + pad_x * 2, th + pad_y * 2

            local pos = ui.get(wm_pos) or "top-left"
            local x, y
            if pos == "top-left" then
                x, y = 16, 16
            elseif pos == "top-center" then
                x, y = (sw - w) / 2, 16
            elseif pos == "top-right" then
                x, y = sw - w - 16, 16
            elseif pos == "bottom-left" then
                x, y = 16, sh - h - 16
            elseif pos == "bottom-center" then
                x, y = (sw - w) / 2, sh - h - 16
            else
                x, y = sw - w - 16, sh - h - 16
            end

            if ui.get(wm_bg) then
                local br, bg, bb, ba = ui.get(wm_bgcol)
                renderer.rectangle(x, y, w, h, br, bg, bb, ba)
                renderer.rectangle(x, y, w, 1, 255, 255, 255, 10)
                renderer.rectangle(x, y + h - 1, w, 1, 0, 0, 0, 25)
            end

            local r, g, b, a = ui.get(wm_col)
            local tx, ty = x + pad_x, y + pad_y
            if ui.get(wm_shadow) then
                renderer.text(tx + 1, ty + 1, 0, 0, 0, 140, "b", 0, text)
            end
            renderer.text(tx, ty, r, g, b, a, "b", 0, text)
        end
    )
end

UI.AspectRatio = UI.AspectRatio or {}

UI.AspectRatio.enable = my_tabs:add_checkbox("Visuals", "LUA", "B", "Aspect ratio override")
UI.AspectRatio.mode = my_tabs:add_combobox("Visuals", "LUA", "B", "Mode", "Presets", "Custom")

UI.AspectRatio.preset =
    my_tabs:add_combobox("Visuals", "LUA", "B", "Preset", "4:3", "5:4", "16:10", "16:9", "21:9", "32:9")

UI.AspectRatio.custom = my_tabs:add_slider("Visuals", "LUA", "B", "Custom ratio", 50, 300, 178, true, "")

my_tabs:add_conditional(
    "Visuals",
    UI.AspectRatio.mode,
    function()
        return ui.get(UI.AspectRatio.enable)
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.AspectRatio.preset,
    function()
        return ui.get(UI.AspectRatio.enable) and (ui.get(UI.AspectRatio.mode) == "Presets")
    end
)
my_tabs:add_conditional(
    "Visuals",
    UI.AspectRatio.custom,
    function()
        return ui.get(UI.AspectRatio.enable) and (ui.get(UI.AspectRatio.mode) == "Custom")
    end
)

ui.set_callback(
    UI.AspectRatio.enable,
    function()
        my_tabs:update_visibility()
    end
)
ui.set_callback(
    UI.AspectRatio.mode,
    function()
        my_tabs:update_visibility()
    end
)

local AR_STATE = {saved = nil, last = nil, saved_ok = false}

local function ar_parse_preset(name)
    name = tostring(name or "")

    local w, h = name:match("(%d+)%s*[:/xX]%s*(%d+)")
    if w and h then
        w, h = tonumber(w), tonumber(h)
        if w and h and h > 0 then
            return w / h
        end
    end

    return 16 / 9
end
local function ar_get_target()
    if ui.get(UI.AspectRatio.mode) == "Presets" then
        return ar_parse_preset(ui.get(UI.AspectRatio.preset))
    else
        return (ui.get(UI.AspectRatio.custom) or 178) / 100.0
    end
end

local function ar_set(val)
    if _G.cvar and cvar.r_aspectratio and cvar.r_aspectratio.set_float then
        cvar.r_aspectratio:set_float(val)
    else
        client.exec(string.format("r_aspectratio %.6f", val))
    end
end

local function ar_get_current()
    if _G.cvar and cvar.r_aspectratio and cvar.r_aspectratio.get_float then
        return cvar.r_aspectratio:get_float()
    end

    return AR_STATE.last or 0
end

local function ar_ensure_saved()
    if AR_STATE.saved_ok then
        return
    end
    AR_STATE.saved = ar_get_current()
    AR_STATE.saved_ok = true
end

local function ar_restore()
    if not AR_STATE.saved_ok then
        return
    end
    local back = AR_STATE.saved or 0
    if AR_STATE.last ~= nil and math.abs((AR_STATE.last or 0) - back) > 1e-6 then
        ar_set(back)
    end
    AR_STATE.last = nil
end

local function ar_apply_if_needed()
    if not ui.get(UI.AspectRatio.enable) then
        ar_restore()
        return
    end

    ar_ensure_saved()

    local target = ar_get_target()
    if target < 0.5 then
        target = 0.5
    elseif target > 4.0 then
        target = 4.0
    end

    if AR_STATE.last == nil or math.abs(target - AR_STATE.last) > 1e-4 then
        ar_set(target)
        AR_STATE.last = target
    end
end

client.set_event_callback("paint", ar_apply_if_needed)

client.set_event_callback(
    "level_init",
    function()
        ar_restore()
        AR_STATE = {saved = nil, last = nil, saved_ok = false}
    end
)
client.set_event_callback(
    "round_start",
    function()
        ar_apply_if_needed()
    end
)

UI.Ind = UI.Ind or {}
UI.Ind.enable = UI.Ind.enable or my_tabs:add_checkbox("Visuals", "LUA", "B", "Crosshair indicators")
UI.Ind.style = UI.Ind.style or my_tabs:add_combobox("Visuals", "LUA", "B", "Icon style", "Semantic", "Bold", "Minimal")

local dt_cb, dt_key = ui.reference("RAGE", "Aimbot", "Double tap")
local hs_cb, hs_key = ui.reference("AA", "Other", "On shot anti-aim")
local fd_key = ui.reference("RAGE", "Other", "Duck peek assist")
local slowmo_cb, slowmo_key = ui.reference("AA", "Other", "Slow motion")
local md_slider, md_key = ui.reference("RAGE", "Aimbot", "Minimum damage override")
local baim_key = ui.reference("RAGE", "Aimbot", "Force body aim")

local bit = bit or require("bit")
local function on_bool(item)
    if not item then
        return false
    end
    local ok, v = pcall(ui.get, item)
    return ok and v == true
end
local function on_pair(cb, hk)
    return on_bool(cb) and on_bool(hk)
end
local function scoped(lp)
    local s = entity.get_prop(lp, "m_bIsScoped")
    return s == 1 or s == true
end
local function vel_2d(ent)
    local vx, vy = entity.get_prop(ent, "m_vecVelocity")
    vx, vy = vx or 0, vy or 0
    return math.sqrt(vx * vx + vy * vy)
end
local function on_ground(ent)
    return bit.band(entity.get_prop(ent, "m_fFlags") or 0, 1) == 1
end
local function ducking(ent)
    return (entity.get_prop(ent, "m_flDuckAmount") or 0) > 0.55
end

local V_STILL, V_MOVE = 2, 40
local last_state, state_acc = "STAND", 0
local function raw_state(lp)
    if not lp or not entity.is_alive(lp) then
        return "DEAD"
    end
    local ground = on_ground(lp)
    local duck = ducking(lp)
    local sp = vel_2d(lp)

    if on_bool(fd_key) then
        return ground and "FD"
    end

    if not ground then
        return duck and "AEROBIC+" or "AEROBIC"
    end
    if duck then
        return "CROUCH"
    end
    if on_pair(slowmo_cb, slowmo_key) then
        return "WALK"
    end
    if sp < V_STILL then
        return "STAND"
    end
    if sp < V_MOVE then
        return "SLOW"
    end
    return "MOVE"
end

local function compute_state(lp)
    local want = raw_state(lp)
    if want ~= last_state then
        state_acc = state_acc + globals.frametime()
        if state_acc > 0.06 then
            last_state = want
            state_acc = 0
        end
    else
        state_acc = 0
    end
    return last_state
end

local ORDER = {"STATE", "BAIM", "DMG", "DUCK", "DT", "HS"}

local IND = {}
for _, k in ipairs(ORDER) do
    IND[k] = {on = false, t = 0}
end
IND.TITLE = {on = true, t = 0}

local ANIM_IN, ANIM_OUT = 0.16, 0.14
local function ease_out_cubic(k)
    local i = 1 - k
    return 1 - i * i * i
end
local function ease_in_quad(k)
    return k * k
end
local function ind_set(tag, on)
    local it = IND[tag]
    if it and it.on ~= on then
        it.on = on
        it.t = 0
    end
end
local function ind_step(dt)
    for _, it in pairs(IND) do
        local d = it.on and ANIM_IN or ANIM_OUT
        it.t = (it.t < d) and (it.t + dt) or d
    end
end
local function ind_alpha(tag)
    local it = IND[tag]
    if not it then
        return 0
    end
    local d = it.on and ANIM_IN or ANIM_OUT
    local k = (d > 0) and (it.t / d) or (it.on and 1 or 0)
    if k < 0 then
        k = 0
    elseif k > 1 then
        k = 1
    end
    return it.on and ease_out_cubic(k) or (1 - ease_in_quad(k))
end

local scope_k = 0
local function step_scope(dt, want)
    local target = want and 1 or 0
    local rate = 7.0 * dt
    if rate > 1 then
        rate = 1
    end
    scope_k = scope_k + (target - scope_k) * rate
end

local tw = {text = "", shown_len = 0, t = 0}
local TW_CPS = 34
local function typewriter(dt, txt)
    if txt ~= tw.text then
        tw.text = txt or ""
        tw.shown_len = 0
        tw.t = 0
    end
    if tw.shown_len < #tw.text then
        tw.t = tw.t + dt * TW_CPS
        local want_len = math.floor(tw.t + 0.5)
        if want_len > tw.shown_len then
            if want_len > #tw.text then
                want_len = #tw.text
            end
            tw.shown_len = want_len
        end
    end
    return (tw.shown_len > 0) and tw.text:sub(1, tw.shown_len) or ""
end

local TEXT_CACHE = {}
local function text_wh(flags, s)
    local key = (flags or "_") .. "|" .. (s or "")
    local c = TEXT_CACHE[key]
    if c then
        return c.w, c.h
    end
    local w, h = renderer.measure_text(flags, s or "")
    TEXT_CACHE[key] = {w = w or 0, h = h or 0}
    return w or 0, h or 0
end

local ICON_SET = {
    Semantic = {
        DT = "⚡",
        HS = "✜",
        DUCK = "↧",
        DMG = "✷",
        BAIM = "▣",
        STATE = {
            ["FD"] = "↧",
            ["AIR FD"] = "△",
            ["AIR CROUCH"] = "▽",
            ["AIR"] = "△",
            ["CROUCH"] = "▾",
            ["WALK"] = "≡",
            ["SLOW"] = "⟂",
            ["MOVE"] = "➜",
            ["STAND"] = "●",
            ["DEAD"] = "✖",
            ["*"] = "●"
        }
    },
    Bold = {
        DT = "⚡",
        HS = "✚",
        DUCK = "▾",
        DMG = "✺",
        BAIM = "◎",
        STATE = {
            ["FD"] = "▾",
            ["AIR FD"] = "△",
            ["AIR CROUCH"] = "▽",
            ["AIR"] = "△",
            ["CROUCH"] = "▾",
            ["WALK"] = "≡",
            ["SLOW"] = "∥",
            ["MOVE"] = "➤",
            ["STAND"] = "●",
            ["DEAD"] = "✖",
            ["*"] = "●"
        }
    },
    Minimal = {
        DT = "⚡",
        HS = "×",
        DUCK = "∨",
        DMG = "+",
        BAIM = "○",
        STATE = {
            ["FD"] = "∨",
            ["AIR FD"] = "△",
            ["AIR CROUCH"] = "▽",
            ["AIR"] = "△",
            ["CROUCH"] = "∨",
            ["WALK"] = "≡",
            ["SLOW"] = "∥",
            ["MOVE"] = "›",
            ["STAND"] = "•",
            ["DEAD"] = "×",
            ["*"] = "•"
        }
    }
}

local function get_iconset()
    local name = ui.get(UI.Ind.style) or "Semantic"
    return ICON_SET[name] or ICON_SET.Semantic
end

local function icon_for_state(state_str)
    local set = get_iconset().STATE
    return (set and (set[state_str] or set["*"])) or "•"
end

local function dt_is_on()
    return on_pair(dt_cb, dt_key)
end

local DT_SHIFT_TICKS = 14

local function timers_ready(lp, wep)
    if not (lp and wep) then
        return false, 0
    end
    local now = globals.curtime()
    local na = (entity.get_prop(lp, "m_flNextAttack") or 0) - now
    local nwa = (entity.get_prop(wep, "m_flNextPrimaryAttack") or 0) - now
    local left = math.max(na or 0, 0) + math.max(nwa or 0, 0)
    return (left <= 0.0005), left
end

function shift_ready()
    ti = globals.tickinterval()
    lag = client.latency() or 0
    need_s = DT_SHIFT_TICKS * ti

    return need_s + lag * 0.5
end

local function draw_arc(cx, cy, r, pct, thickness, r_, g, b, a)
    pct = math.max(0, math.min(1, pct or 0))
    if pct <= 0 then
        return
    end
    local start = -math.pi / 2
    local ang = pct * 2 * math.pi
    local seg = math.max(8, math.floor(48 * pct + 0.5))

    for t = 0, math.max(0, (thickness or 1) - 1) do
        local rr = r - t
        local px = cx + math.cos(start) * rr
        local py = cy + math.sin(start) * rr
        for i = 1, seg do
            local a1 = start + ang * (i - 1) / seg
            local a2 = start + ang * i / seg
            local x1 = cx + math.cos(a1) * rr
            local y1 = cy + math.sin(a1) * rr
            local x2 = cx + math.cos(a2) * rr
            local y2 = cy + math.sin(a2) * rr
            renderer.line(x1, y1, x2, y2, r_, g, b, a)
        end
    end
end

_dt_smooth = 0
function dt_charge_pct()
    return _dt_smooth
end
function dt_is_charged()
    return _dt_smooth >= 0.999
end

function dt_update_charge()
    if not dt_is_on() then
        _dt_smooth = 0
        return 0
    end

    local lp = entity.get_local_player()
    if not (lp and entity.is_alive(lp)) then
        _dt_smooth = 0
        return 0
    end
    local wep = entity.get_player_weapon(lp)

    local now = globals.curtime()
    local na = (entity.get_prop(lp, "m_flNextAttack") or 0) - now
    local nwa = (entity.get_prop(wep, "m_flNextPrimaryAttack") or 0) - now
    local left = math.max(na or 0, 0) + math.max(nwa or 0, 0)
    local ok_timers = (left <= 0.0005)

    local ti = globals.tickinterval()
    local need_s = (DT_SHIFT_TICKS or 14) * ti + (client.latency() or 0) * 0.5

    local raw = ok_timers and 1.0 or math.max(0, math.min(1, 1.0 - left / math.max(need_s, 0.001)))

    local dt = globals.frametime()
    local fall = 8.0
    if raw > _dt_smooth then
        _dt_smooth = raw
    else
        _dt_smooth = _dt_smooth + (raw - _dt_smooth) * math.min(1, fall * dt)
    end

    return raw
end

local function draw_item_centered(base_x, y, label, icon, active, fade, slide)
    local icon_str = icon or "•"

    local flags = "d"

    if active and label then
        local iw, ih = text_wh(flags, icon_str)
        local lw, lh = text_wh(flags, label)
        local total_w = iw + 6 + lw
        local x = math.floor(base_x - total_w / 2 + slide + 0.5)
        local a_text = math.floor(200 * fade)
        local a_icon = math.floor(200 * fade)

        renderer.text(x + 1, y + 1, 0, 0, 0, math.floor(a_icon * 0.5), flags, 0, icon_str)
        renderer.text(x, y - 1, 255, 255, 255, a_icon, flags, 0, icon_str)
        x = x + iw + 6

        renderer.text(x + 1, y + 1, 0, 0, 0, math.floor(a_text * 0.5), flags, 0, label)
        renderer.text(x, y, 255, 255, 255, a_text, flags, 0, label)
        return math.max(ih, lh)
    else
        local iw, ih = text_wh(flags, icon_str)
        local x = math.floor(base_x - iw / 2 + slide + 0.5)
        local a_icon = math.floor(90 * fade)
        renderer.text(x + 1, y + 1, 0, 0, 0, math.floor(a_icon * 0.5), flags, 0, icon_str)
        renderer.text(x, y - 1, 200, 200, 200, a_icon, flags, 0, icon_str)
        return ih
    end
end

client.set_event_callback(
    "paint",
    function()
        if not ui.get(UI.Ind.enable) then
            return
        end
        local lp = entity.get_local_player()
        if not lp or not entity.is_alive(lp) then
            return
        end

        local dt_raw = dt_update_charge()
        local dt_on = on_pair(dt_cb, dt_key)
        local hs_on = on_pair(hs_cb, hs_key)
        local fd_on = on_bool(fd_key)
        local baim_on = on_bool(baim_key)
        local dmg_on = on_bool(md_key)

        ind_set("STATE", true)
        ind_set("DT", dt_on)

        ind_set("HS", hs_on)
        ind_set("DUCK", fd_on)
        ind_set("BAIM", baim_on)
        ind_set("DMG", dmg_on)
        IND.TITLE.on = true

        dtf = globals.frametime()
        ind_step(dtf)
        step_scope(dtf, scoped(lp))
        state_txt = typewriter(dtf, compute_state(lp))
        state_icon = icon_for_state(state_txt)

        local sw, sh = client.screen_size()
        local base_x = math.floor(sw / 2 - 6 + 0.5)

        local base_y = math.floor(sh / 2 + 18 + 0.5)

        local function draw_expo_icon(x, y, s, r, g, b, a)
            r, g, b = 255, 255, 255

            local base_y = y + s - 1
            local right = x + s - 1

            local pad_x = math.max(1, math.floor(s * 0.08 + 0.5))
            local pad_y = math.max(1, math.floor(s * 0.18 + 0.5))
            ah = math.max(2, math.floor(s * 0.18 + 0.5))

            renderer.line(x, base_y, right, base_y, r, g, b, a)
            renderer.line(right, base_y, right, y, r, g, b, a)

            renderer.line(right, y, right - ah, y + math.floor(ah * 0.6), r, g, b, a)
            renderer.line(x, base_y, x + math.floor(ah * 0.6), base_y + ah, r, g, b, a)

            do
                flags_small = "d-"
                local tw, th = renderer.measure_text(flags_small, "x")

                local tx = right - math.floor(tw / 2) - 1
                local ty = y - th - 2

                renderer.text(tx, ty, r, g, b, a, flags_small, 0, "x")
            end

            steps = 80
            local k = 8.0
            gain_y = (s - pad_y * 0.1)

            span = (s - 1) - pad_x * 2
            prev_x = x + pad_x
            prev_y = base_y - pad_y

            ek = math.exp(k) - 1
            for i = 1, steps do
                local t = i / steps
                local e = (math.exp(k * t) - 1) / ek
                xx = x + pad_x + math.floor(span * t + 0.5)
                yy = base_y - pad_y - math.floor(gain_y * e + 0.5)
                renderer.line(prev_x, prev_y, xx, yy, r, g, b, a)
                prev_x, prev_y = xx, yy
            end
        end

        do
            local a = ind_alpha("TITLE")
            name = "exponential"
            name_w, name_h = text_wh(nil, name)
            s = math.max(12, math.floor(name_h * 1.1 + 0.5))
            local gap = 6
            local sw, sh = client.screen_size()

            total_w = s + gap + name_w
            local x = math.floor(base_x - total_w / 2 + scope_k * 28 + 0.5)
            local y = base_y - 8
            at = math.floor(195 * a)
            draw_expo_icon(x, y, s, 255, 180, 120, at)
            x = x + s + gap
            renderer.text(x + 1, y + 1, 0, 0, 0, math.floor(at * 0.55), nil, 0, name)
            renderer.text(x, y, 255, 255, 255, at, nil, 0, name)
        end

        local y = base_y + 6

        do
            fade = ind_alpha("STATE")
            if fade > 0.03 then
                slide = scope_k * 28 + (1 - fade) * 8
                ih = draw_item_centered(base_x - 2, y, state_txt, state_icon, true, fade, slide)

                y = y + ih + 2
            end
        end

        S = get_iconset()
        items = {
            {"BAIM", baim_on, "BAIM", S.BAIM},
            {"DMG", dmg_on, "DMG", S.DMG},
            {"DUCK", fd_on, "DUCK", S.DUCK},
            {"DT", dt_on, "DT", S.DT},
            {"HS", hs_on, "HS", S.HS}
        }

        for i = 1, #items do
            local tag = items[i][1]
            local active = items[i][2]
            local label = items[i][3]
            local icon = items[i][4]

            local fade = ind_alpha(tag)
            if fade > 0.03 then
                local slide = scope_k * 28 + (1 - fade) * 8
                local charge = dt_charge_pct()
                local this_fade = fade
                local this_label = (active and label) or nil

                if tag == "DT" then
                    local min_brightness = 0.25
                    local brightness = min_brightness + charge * (1 - min_brightness)
                    this_fade = fade * brightness
                    this_label = label
                end

                local ih = draw_item_centered(base_x, y, this_label, icon, active, this_fade, slide)

                if tag == "DT" then
                    local min_brightness = 0.25
                    local brightness = min_brightness + charge * (1 - min_brightness)
                    this_fade = fade * brightness
                    this_label = label

                    local icon_w, ih_txt = text_wh(nil, icon)
                    local lbl_w = this_label and select(1, text_wh(nil, this_label)) or 0
                    local gap = this_label and 6 or 0
                    local total_w = icon_w + gap + lbl_w

                    local x_right = math.floor(base_x + total_w / 2 + slide + 0.5)
                    local y_center = y + math.floor(ih_txt / 2 + 0.5)

                    local r = 5
                    local cx = x_right + 10
                    local cy = y_center + 1

                    local pct = math.max(0.06, math.min(1.0, dt_raw))
                    local thickness = 2
                    local min_alpha, max_alpha = 120, 220
                    local alpha = math.floor((min_alpha + (max_alpha - min_alpha) * charge) * fade)

                    draw_arc(cx, cy, r, pct, thickness, 255, 255, 255, alpha)
                end

                y = y + ih + 2
            end
        end
    end
)
 http = require 'gamesense/http'
 base64 = require 'gamesense/base64'

 DEBUG_LEVEL = 0
 REPO_OWNER = "Routtyyy"
 REPO_NAME = "ijda9i0sdj90awijd90asidd9saok"
 FILE_PATH = "players.json"

 scoreboard_images = panorama.loadstring([[
    var panel = null;
    var name_panels = {};
    var target_players = {};

    var _Update = function(players) {
        _Destroy();
        target_players = players || {};
        let scoreboard = $.GetContextPanel().FindChildTraverse("ScoreboardContainer").FindChildTraverse("Scoreboard");
      
        if (!scoreboard) return;

        scoreboard.FindChildrenWithClassTraverse("sb-row").forEach(function(row) {
            if (target_players[row.m_xuid]) {
                row.style.backgroundColor = "rgb(0, 0, 0)";
                row.style.border = "1px solid rgb(94, 94, 94)";
              
                row.Children().forEach(function(child) {
                    let nameLabel = child.FindChildTraverse("name");
                    if (nameLabel) {
                        nameLabel.style.color = "rgb(155, 155, 155)";
                        nameLabel.style.fontFamily = "Stratum2 Bold Monodigit";
                        nameLabel.style.fontWeight = "bold";
                    }

                    if (nameLabel) {
                        let parent = nameLabel.GetParent();
                        parent.style.flowChildren = "left";

                        let image_panel = $.CreatePanel("Panel", parent, "custom_image_panel_" + row.m_xuid);
                        let layout = `
                        <root>
                            <Panel style="flow-children: left; margin-right: 5px;">
                                <Image textureheight="24" texturewidth="24" src="https://yougame.biz/data/avatars/l/279/279781.jpg?1735272377" />
                            </Panel>
                        </root>
                        `;

                        image_panel.BLoadLayoutFromString(layout, false, false);
                        parent.MoveChildBefore(image_panel, nameLabel);
                        name_panels[row.m_xuid] = image_panel;
                    }
                });
            }
        });
    };


    var _Destroy = function() {
        let scoreboard = $.GetContextPanel().FindChildTraverse("ScoreboardContainer").FindChildTraverse("Scoreboard");
      
        if (scoreboard) {
            scoreboard.FindChildrenWithClassTraverse("sb-row").forEach(function(row) {
                row.style.backgroundColor = null;
                row.style.border = null;
              
                row.Children().forEach(function(child) {
                    let nameLabel = child.FindChildTraverse("name");
                    if (nameLabel) {
                        nameLabel.style.color = null;
                        nameLabel.style.fontFamily = "Stratum2";
                        nameLabel.style.fontWeight = "normal";
                    }
                });
            });
        }

        for (let xuid in name_panels) {
            if (name_panels[xuid] && name_panels[xuid].IsValid()) {
                name_panels[xuid].DeleteAsync(0.0);
            }
        }
      
        name_panels = {};
        target_players = {};
    };

    return {
        update: _Update,
        remove: _Destroy
    };
]], "CSGOHud")()

local function update_github_file(steamid, action)
    local headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["Accept"] = "application/vnd.github.v3+json"
    }
  
     api_url = string.format(
        "https://api.github.com/repos/%s/%s/contents/%s",
        REPO_OWNER, REPO_NAME, FILE_PATH
    )

    http.get(api_url, {headers = headers}, function(success, response)
        if not success then return end
      
         current_data = {}
         sha = nil
      
        if response.status == 200 then
            local content = json.parse(response.body)
            sha = content.sha
            current_data = json.parse(base64.decode(content.content))
        end
      
        if action == "add" then
            current_data[tostring(steamid)] = true
        else
            current_data[tostring(steamid)] = nil
        end
      
         update_data = {
            message = string.format("update - %s %s", action, steamid),
            content = base64.encode(json.stringify(current_data)),
            sha = sha
        }
      
        http.put(api_url, {
            headers = headers,
            body = json.stringify(update_data)
        }, function(success, response)
            if success then
                if DEBUG_LEVEL > 1 then
                    print("[shared] successfully fully updated")
                end
            end
        end)
    end)
end

scoreboard_images.update(target_players)

 function get_local_steamid()
    return tostring(panorama.open().MyPersonaAPI.GetXuid())
end

client.set_event_callback("player_connect_full", function(e)
     steamid = get_local_steamid()
    if steamid then
        update_github_file(steamid, "add")

        local target = client.userid_to_entindex(e.userid)
        if target == entity.get_local_player() then
            scoreboard_images.remove()
            client.delay_call(0.5, function()
                scoreboard_images.update(target_players)
            end)
        else
            scoreboard_images.remove()
            client.delay_call(0.5, function()
                scoreboard_images.update(target_players)
            end)
        end
    end
end)

 function update_target_players(github_data)
    target_players = {}
    for steamid, _ in pairs(github_data) do
        target_players[steamid] = true
    end
    scoreboard_images.update(target_players)
end

 function check_and_update_github()
     headers = {
        ["Authorization"] = "token " .. GITHUB_TOKEN,
        ["Accept"] = "application/vnd.github.v3+json"
    }
  
     api_url = string.format(
        "https://api.github.com/repos/%s/%s/contents/%s",
        REPO_OWNER, REPO_NAME, FILE_PATH
    )

    http.get(api_url, {headers = headers}, function(success, response)
        if success and response.status == 200 then
            local content = json.parse(response.body)
            local current_data = json.parse(base64.decode(content.content))
            update_target_players(current_data)
            if DEBUG_LEVEL > 0 then
                print("[shared] successfully updated")
            end
        end
    end)
end

check_and_update_github()

 last_update = 0
 last_github_check = 0
client.set_event_callback('paint', function()
    local current_time = globals.realtime()
    if current_time - last_update >= 3.0 then
        scoreboard_images.update(target_players)
        last_update = current_time
    end

    if current_time - last_github_check >= 1.5 then
        check_and_update_github()
        last_github_check = current_time
    end
end)

client.set_event_callback("shutdown", function()
     steamid = get_local_steamid()
    if steamid then
        scoreboard_images.remove()
        update_github_file(steamid, "remove")
    end
end)


client.delay_call(
    0.1,
    function()
        my_tabs:update_visibility()
    end
)
