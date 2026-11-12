-- Tap to Pin Tooltip v1.1.0
-- Created by GlowlineStd. Requires Steamodded.
-- Tap special cards to pin their popup. Dismissing a pin also deselects the card.
-- A small drag hides the popup. A harmless drop also clears selection.
-- Native drop targets are handled by the original game before this cleanup.

local pinned_card = nil
local gesture = nil
local DRAG_DISTANCE = 0.07 -- In Balatro game units (about a few screen pixels).

local card_click = Card.click
local card_hover = Card.hover
local card_stop_hover = Card.stop_hover
local card_drag = Card.drag
local card_remove = Card.remove
local controller_press = Controller.L_cursor_press
local controller_release = Controller.L_cursor_release
local controller_update = Controller.update

local function is_touch()
    if not G or not G.CONTROLLER then return false end
    local controller = G.CONTROLLER
    if (controller.HID and controller.HID.touch) or controller.using_touch then
        return true
    end
    return love and love.system and love.system.getOS
        and love.system.getOS() == 'iOS'
end

local function in_hand(card)
    if not G or not G.hand then return false end
    if card.area == G.hand then return true end
    if G.hand.cards then
        for _, hand_card in ipairs(G.hand.cards) do
            if hand_card == card then return true end
        end
    end
    return false
end


-- Always update Balatro's CardArea list as well as the card's animation.
-- Skip ordinary hand cards, which never use the pinning behaviour.
local function deselect_special(card)
    if not card or card.REMOVED or not card.highlighted or in_hand(card) then return end
    local area = card.area
    if area and area.remove_from_highlighted then
        area:remove_from_highlighted(card)
    elseif card.highlight then
        card:highlight(false)
    end
end

local function close_pinned(deselect)
    local previous = pinned_card
    pinned_card = nil -- Unpin before invoking the original stop_hover.
    if not previous or previous.REMOVED then return end

    if previous.children then
        card_stop_hover(previous)
    end

    -- Popup lifetime and card highlight are separate in Balatro.
    -- Only remove selection on tap-dismissal, not while dragging, because
    -- drags (selling, buying, rearranging) must retain their native logic.
    if deselect then deselect_special(previous) end
end


local function pinnable(card)
    if not card or in_hand(card) then return false end
    return not card.REMOVED and card.children and card.states
        and card.states.visible and card.facing == 'front' and not card.no_ui
        and not (G and G.deck and G.deck.cards and G.deck.cards[1] == card)
end

local function moving_past_threshold(t)
    if not gesture or not t or not gesture.start then return false end
    local dx = (t.x or gesture.start.x) - gesture.start.x
    local dy = (t.y or gesture.start.y) - gesture.start.y
    return dx * dx + dy * dy >= DRAG_DISTANCE * DRAG_DISTANCE
end

local function mark_dragged(t)
    if not gesture or gesture.moved or not moving_past_threshold(t) then return end
    gesture.moved = true

    -- Cancel both pinned and regular long-press tooltips for this gesture.
    if pinned_card then close_pinned(false) end
    local card = gesture.card
    if card and not card.REMOVED and card.children then
        card_stop_hover(card)
    end
end

local function check_cursor_movement(controller)
    if not gesture or gesture.moved or not controller or not controller.is_cursor_down then return end
    -- Controller has already converted the physical pointer to game coordinates.
    local t = G and G.CURSOR and G.CURSOR.T
    if t then mark_dragged(t) end
end

-- Block new popups during a drag, including Balatro's delayed hover event.
function Card:hover(...)
    if gesture and gesture.moved and is_touch() then return end
    return card_hover(self, ...)
end

function Card:stop_hover(...)
    if pinned_card == self then
        if not in_hand(self) then return end
        pinned_card = nil
    end
    return card_stop_hover(self, ...)
end

function Card:click(...)
    local was_pinned = pinned_card == self
    local result = card_click(self, ...) -- Keep all normal card actions.

    if is_touch() then
        -- Balatro may still call click after a tiny movement. Never pin on drag.
        if gesture and gesture.card == self and gesture.moved then
            if pinned_card == self then close_pinned(false) end
        elseif was_pinned then
            close_pinned(true)
        elseif pinnable(self) then
            close_pinned(true)
            if not self.children.h_popup then card_hover(self) end
            if self.children and self.children.h_popup then pinned_card = self end
        end
    end
    return result
end

-- Detect movement as soon as the game drags the object, before drag actions.
if card_drag then
    function Card:drag(...)
        if gesture and gesture.card == self and is_touch() then
            local controller = G and G.CONTROLLER
            local t = G and G.CURSOR and G.CURSOR.T
            if controller and controller.is_cursor_down and t then mark_dragged(t) end
        end
        return card_drag(self, ...)
    end
end

function Controller:L_cursor_press(...)
    local result = controller_press(self, ...)
    if is_touch() and self.is_cursor_down then
        local target = self.cursor_down and self.cursor_down.target
        gesture = nil
        if pinnable(target) and self.cursor_down.T then
            gesture = {
                card = target,
                original_area = target.area,
                start = { x = self.cursor_down.T.x, y = self.cursor_down.T.y },
                moved = false,
                released = false
            }
        end
        if pinned_card and target ~= pinned_card then close_pinned(true) end
    end
    return result
end

function Controller:L_cursor_release(...)
    local result = controller_release(self, ...)
    if gesture and is_touch() and not self.is_cursor_down then
        -- Also catches short swipes where no update frame ran between move/release.
        mark_dragged(self.cursor_up and self.cursor_up.T)
        gesture.released = true
    end
    return result
end

function Controller:update(...)
    local result = controller_update(self, ...)
    if is_touch() then check_cursor_movement(self) end
    -- Original Controller:update has already processed Card:click and release
    -- targets on this frame. Only then clean up an unsuccessful drag.
    if gesture and gesture.released then
        if gesture.moved then
            local card = gesture.card
            local destination = self.cursor_up and self.cursor_up.target
            -- Never pre-empt an active buy/use/sell drop zone. It may still
            -- schedule its transaction for a later game event.
            local on_action_target = destination and destination ~= card
                and destination.states and destination.states.release_on
                and destination.states.release_on.can
                and self.released_on and self.released_on.target == destination
            if not on_action_target and card and not card.REMOVED
                and card.area == gesture.original_area then
                deselect_special(card)
            end
        end
        gesture = nil
    end
    return result
end

if card_remove then
    function Card:remove(...)
        if pinned_card == self then pinned_card = nil end
        if gesture and gesture.card == self then gesture = nil end
        return card_remove(self, ...)
    end
end

-- Tooltip scaling operates on copied UI node data to avoid modifying
-- the shared tables used by existing descriptions.

local atpt_mod = SMODS and SMODS.current_mod
local atpt_settings = atpt_mod and atpt_mod.config or { tooltip_scale = 1 }
local original_dyna_scales = setmetatable({}, { __mode = 'k' })
if type(atpt_settings) ~= 'table' then atpt_settings = { tooltip_scale = 1 } end
if atpt_mod then atpt_mod.config = atpt_settings end

-- Hide optional action-button UIBoxes attached to any card type.
-- Existing game actions and independent drop targets remain untouched.
-- Initialize the option for configurations created before this setting existed.
if atpt_settings.hide_card_buttons == nil then
    atpt_settings.hide_card_buttons = false
end

-- Store the original visibility/collision state of each UIBox. In particular,
-- never delete shop buttons or replace action callbacks: the game's
-- layout and input systems may reference the UIBox while it is hidden.
local button_previous_states = setmetatable({}, { __mode = 'k' })

local function sync_button_box(box)
    if not box or not box.states or not box.states.collide then return end
    local previous = button_previous_states[box]
    if atpt_settings.hide_card_buttons then
        if not previous then
            previous = {
                visible = box.states.visible,
                collide = box.states.collide.can
            }
            button_previous_states[box] = previous
        end
        box.states.visible = false
        box.states.collide.can = false
    elseif previous then
        box.states.visible = previous.visible
        box.states.collide.can = previous.collide
        button_previous_states[box] = nil
    end
end

-- Different card actions can use different UIBox keys. Match button
-- functions rather than card type or area. Avoid
-- hiding price labels, hover descriptions, edition stickers, or other UI.
local function is_attached_action_key(key)
    if type(key) ~= 'string' then return false end
    return key == 'button' or key:match('_buttons?$') ~= nil
end

local function sync_card_buttons(card)
    if not card or card.REMOVED or not card.children then return end
    for key, child in pairs(card.children) do
        if is_attached_action_key(key) then
            sync_button_box(child)
        end
    end
    -- Handle action buttons exposed through controller focus.
    local focus = card.children.focused_ui
    if focus and focus.get_UIE_by_ID then
        local attach = focus:get_UIE_by_ID('ATTACH_TO_ME')
        local attached = attach and attach.children
        if attached then
            for key, child in pairs(attached) do
                if key == 'buy' or key == 'buy_and_use' or key == 'sell'
                    or key == 'use' or key == 'redeem' or key == 'open'
                    or key == 'select' or is_attached_action_key(key) then
                    sync_button_box(child)
                end
            end
        end
    end
end

-- Vanilla Card:draw changes buy_button.states.visible = true on every
-- highlighted frame. A hidden flag alone is therefore not enough for shop
-- Jokers, vouchers, booster packs, etc. Prevent *only the registered card
-- action boxes* from drawing; all other UIBoxes keep their normal rendering.
-- No buttons are removed and none of their buy/sell/use callbacks are changed.
local original_uibox_draw_for_buttons = UIBox and UIBox.draw
if original_uibox_draw_for_buttons then
    function UIBox:draw(...)
        if atpt_settings.hide_card_buttons and button_previous_states[self] then
            return
        end
        return original_uibox_draw_for_buttons(self, ...)
    end
end

-- Register action UIBoxes before every draw (including those created between
-- updates), and re-apply collision/visibility after Card:draw modifies them.
local original_card_draw_for_buttons = Card.draw
if original_card_draw_for_buttons then
    function Card:draw(...)
        sync_card_buttons(self)
        local result = original_card_draw_for_buttons(self, ...)
        sync_card_buttons(self)
        return result
    end
end

-- Cover immediate card highlighting and hover, and the asynchronous shop UI
-- creation (the shop schedules its buttons after a short delay).
local original_highlight_for_buttons = Card.highlight
if original_highlight_for_buttons then
    function Card:highlight(...)
        local result = original_highlight_for_buttons(self, ...)
        sync_card_buttons(self)
        return result
    end
end

local original_hover_for_buttons = Card.hover
if original_hover_for_buttons then
    function Card:hover(...)
        local result = original_hover_for_buttons(self, ...)
        sync_card_buttons(self)
        return result
    end
end

local original_card_update_for_buttons = Card.update
if original_card_update_for_buttons then
    function Card:update(...)
        local result = original_card_update_for_buttons(self, ...)
        sync_card_buttons(self)
        return result
    end
end

local function sync_all_visible_cards()
    if not G then return end
    -- Apply changed settings immediately to every currently visible card area.
    -- Card:update handles cards belonging to additional card areas.
    local areas = {
        G.jokers, G.consumeables, G.shop_jokers, G.shop_vouchers,
        G.shop_booster, G.pack_cards, G.hand, G.play, G.deck,
        G.discard, G.title_top, G.title_bottom
    }
    for _, area in pairs(areas) do
        if area and area.cards then
            for _, card in ipairs(area.cards) do sync_card_buttons(card) end
        end
    end
    -- Some areas only register their cards in the global pool.
    -- This includes cards already drawn that are not currently in a CardArea.
    if G.I and G.I.CARD then
        for _, card in pairs(G.I.CARD) do sync_card_buttons(card) end
    end
end

local scale_values = {}
local scale_labels = {}
for step = 0, 10 do
    local value = 1 + step / 20
    scale_values[step + 1] = value
    scale_labels[step + 1] = string.format('%.2f', value)
end

local function tooltip_scale()
    local value = tonumber(atpt_settings.tooltip_scale) or 1
    if value < 1 or value > 1.5 then return 1 end
    return value
end

local function scale_index()
    local selected = tooltip_scale()
    local nearest, distance = 1, math.huge
    for i, value in ipairs(scale_values) do
        local delta = math.abs(value - selected)
        if delta < distance then nearest, distance = i, delta end
    end
    return nearest
end

-- Steamodded renders this as Mods > Tap to Pin Tooltip > Config.
if atpt_mod and G and G.FUNCS then
    G.FUNCS.atpt_cycle_tooltip_scale = function(e)
        local index = e and tonumber(e.to_key)
        if not index or not scale_values[index] then return end
        atpt_settings.tooltip_scale = scale_values[index]
        -- Reset previously scaled live DynaText objects before the next popup.
        for obj, original in pairs(original_dyna_scales) do
            if type(obj.config) == 'table' then obj.config.scale = original end
        end
        if SMODS.save_mod_config then SMODS.save_mod_config(atpt_mod) end
    end

    -- create_toggle writes to atpt_settings.hide_card_buttons. The callback
    -- persists the preference and applies it to cards already on screen.
    local function persist_button_setting()
        sync_all_visible_cards()
        if SMODS.save_mod_config then SMODS.save_mod_config(atpt_mod) end
    end

    -- Settings labels are resolved when the tab opens, so they follow
    -- Balatro's selected language. English is the fallback for other locales.
    local english_fallback = {
        atpt_tooltip_scale = 'Tooltip scale',
        atpt_scale_hint = '1.00 to 1.50 (steps of 0.05)',
        atpt_hide_buttons = 'Hide attached card buttons',
    }

    local function atpt_text(key)
        local dict = G and G.localization and G.localization.misc
            and G.localization.misc.dictionary
        local translated = dict and dict[key]
        return (type(translated) == 'string' and translated)
            or english_fallback[key] or key
    end

    atpt_mod.config_tab = function()
        -- Show only interactive tooltip and button visibility settings.
        return {
            n = G.UIT.ROOT,
            config = { align = 'cm', colour = G.C.CLEAR, minw = 6.5, minh = 2.0, padding = 0.12 },
            nodes = {
                { n = G.UIT.R, config = { align = 'cm', padding = 0.11 }, nodes = {
                    { n = G.UIT.T, config = { text = atpt_text('atpt_tooltip_scale'), scale = 0.43, colour = G.C.UI.TEXT_LIGHT } }
                }},
                { n = G.UIT.R, config = { align = 'cm', padding = 0.05 }, nodes = {
                    create_option_cycle({
                        scale = 0.8,
                        w = 4.2,
                        options = scale_labels,
                        opt_callback = 'atpt_cycle_tooltip_scale',
                        current_option = scale_index(),
                        colour = G.C.RED
                    })
                }},
                { n = G.UIT.R, config = { align = 'cm', padding = 0.07 }, nodes = {
                    { n = G.UIT.T, config = { text = atpt_text('atpt_scale_hint'), scale = 0.29, colour = G.C.UI.TEXT_LIGHT } }
                }},
                { n = G.UIT.R, config = { align = 'cm', padding = 0.08 }, nodes = {
                    create_toggle({
                        label = atpt_text('atpt_hide_buttons'),
                        label_scale = 0.32,
                        scale = 0.8,
                        ref_table = atpt_settings,
                        ref_value = 'hide_card_buttons',
                        callback = persist_button_setting
                    })
                }},
            }
        }
    end
end

local function clone_table(t)
    if type(t) ~= 'table' then return t end
    local result = {}
    for key, value in pairs(t) do result[key] = value end
    return result
end

-- DynaText is a live game object, so retain its identity and remember its
-- original size. Rebuilding a popup must never multiply an already-scaled size.
local function resize_dynamic_text(config, factor)
    if type(config) ~= 'table' then return end
    local object = config.object
    if type(object) ~= 'table' or type(object.config) ~= 'table' then return end
    local existing = object.config.scale
    if type(existing) ~= 'number' then return end
    local original = original_dyna_scales[object]
    if not original then
        original = existing
        original_dyna_scales[object] = original
    end
    object.config.scale = original * factor
end

local function resized_node(node, factor)
    if type(node) ~= 'table' then return node end
    local copy = clone_table(node)
    if type(node.config) == 'table' then
        copy.config = clone_table(node.config)
        if type(node.config.scale) == 'number' then
            copy.config.scale = node.config.scale * factor
        end
        resize_dynamic_text(copy.config, factor)
    end
    return copy
end

local function resized_rows(rows, factor)
    if type(rows) ~= 'table' then return rows end
    local result = {}
    for i, row in ipairs(rows) do
        if type(row) == 'table' then
            local new_row = {}
            for j, node in ipairs(row) do
                new_row[j] = resized_node(node, factor)
            end
            result[i] = new_row
        else
            result[i] = row
        end
    end
    return result
end

local native_desc_from_rows = desc_from_rows
if type(native_desc_from_rows) == 'function' then
    function desc_from_rows(desc_nodes, empty, maxw, ...)
        local factor = tooltip_scale()
        if factor == 1 then return native_desc_from_rows(desc_nodes, empty, maxw, ...) end
        local adjusted = resized_rows(desc_nodes, factor)
        local result = native_desc_from_rows(adjusted, empty, maxw and (maxw * factor) or nil, ...)
        if result and result.config then
            local c = result.config
            c.r = (c.r or 0.1) * factor
            c.padding = (c.padding or 0.04) * factor
            c.minw = (c.minw or 2) * factor
            c.minh = (c.minh or 0.8) * factor
            if c.emboss then c.emboss = c.emboss * factor end
            if result.nodes and result.nodes[1] and result.nodes[1].config then
                local child = result.nodes[1].config
                if child.padding then child.padding = child.padding * factor end
            end
        end
        return result
    end
end

local native_name_from_rows = name_from_rows
if type(native_name_from_rows) == 'function' then
    function name_from_rows(name_nodes, background_colour, ...)
        local factor = tooltip_scale()
        if factor == 1 then return native_name_from_rows(name_nodes, background_colour, ...) end
        local adjusted = name_nodes
        if type(name_nodes) == 'table' then
            adjusted = {}
            for i, node in ipairs(name_nodes) do
                adjusted[i] = resized_node(node, factor)
            end
        end
        local result = native_name_from_rows(adjusted, background_colour, ...)
        if result and result.config then
            local c = result.config
            c.padding = (c.padding or 0.05) * factor
            c.r = (c.r or 0.1) * factor
            if c.emboss then c.emboss = c.emboss * factor end
        end
        return result
    end
end

local native_info_tip_from_rows = info_tip_from_rows
if type(native_info_tip_from_rows) == 'function' then
    function info_tip_from_rows(desc_nodes, name, ...)
        local factor = tooltip_scale()
        if factor == 1 then return native_info_tip_from_rows(desc_nodes, name, ...) end
        local adjusted = resized_rows(desc_nodes, factor)
        local result = native_info_tip_from_rows(adjusted, name, ...)
        if result then
            if result.config then result.config.r = (result.config.r or 0.1) * factor end
            for _, node in ipairs(result.nodes or {}) do
                if node.config then
                    local c = node.config
                    if c.padding then c.padding = c.padding * factor end
                    if c.minh then c.minh = c.minh * factor end
                    if c.minw then c.minw = c.minw * factor end
                    if c.r then c.r = c.r * factor end
                    if c.scale then c.scale = c.scale * factor end
                end
                if node.nodes and node.nodes[1] and node.nodes[1].config then
                    local nested = node.nodes[1].config
                    if nested.scale then nested.scale = nested.scale * factor end
                end
            end
        end
        return result
    end
end
