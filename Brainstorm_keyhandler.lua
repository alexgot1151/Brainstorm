local lovely = require("lovely")
local nativefs = require("nativefs")

Brainstorm.AUTOREROLL = {}

local saveKeys = { "1", "2", "3", "4", "5" }
Brainstorm.KEY_HANDLER = Brainstorm.KEY_HANDLER or { last_key = nil, last_t = -1 }

local function ctrl_down()
	return love.keyboard.isDown("lctrl", "rctrl")
end

local function normalize_keybind(k)
	if type(k) ~= "string" then return nil end
	return string.lower(k)
end

local function first_held_save_slot()
	for _, k in ipairs(saveKeys) do
		if love.keyboard.isDown(k) then
			return k
		end
	end
	return nil
end

local function save_state_to_slot(k)
	if G.STAGE == G.STAGES.RUN then
		compress_and_save(G.SETTINGS.profile .. "/" .. "saveState" .. k .. ".jkr", G.ARGS.save_run)
		saveManagerAlert("Saved state to slot [" .. k .. "]")
	end
end

local function load_state_from_slot(k)
	G:delete_run()
	G.SAVED_GAME = get_compressed(G.SETTINGS.profile .. "/" .. "saveState" .. k .. ".jkr")
	if G.SAVED_GAME ~= nil then
		G.SAVED_GAME = STR_UNPACK(G.SAVED_GAME)
	end
	G:start_run({
		savetext = G.SAVED_GAME,
	})
	saveManagerAlert("Loaded save from slot [" .. k .. "]")
end

local function key_press_update_impl(key)
	if not key or not Brainstorm.SETTINGS or not Brainstorm.SETTINGS.keybinds then
		return
	end

	local now = (love.timer and love.timer.getTime and love.timer.getTime()) or 0
	if Brainstorm.KEY_HANDLER.last_key == key and (now - Brainstorm.KEY_HANDLER.last_t) < 0.01 then
		return
	end
	Brainstorm.KEY_HANDLER.last_key = key
	Brainstorm.KEY_HANDLER.last_t = now

	local saveBind = normalize_keybind(Brainstorm.SETTINGS.keybinds.saveState)
	local loadBind = normalize_keybind(Brainstorm.SETTINGS.keybinds.loadState)
	local rerollBind = normalize_keybind(Brainstorm.SETTINGS.keybinds.rerollSeed)
	local autoBind = normalize_keybind(Brainstorm.SETTINGS.keybinds.autoReroll)
	key = normalize_keybind(key) or key

	-- Brainstorm Key Handler
	for _, k in ipairs(saveKeys) do
		--  SaveState
		if key == k and saveBind and love.keyboard.isDown(saveBind) then
			save_state_to_slot(k)
		end
		--  LoadState
		if key == k and loadBind and love.keyboard.isDown(loadBind) then
			load_state_from_slot(k)
		end
	end

	-- Also allow opposite key order: hold number, then press save/load key
	if key == saveBind then
		local slot = first_held_save_slot()
		if slot then
			save_state_to_slot(slot)
		end
	end
	if key == loadBind then
		local slot = first_held_save_slot()
		if slot then
			load_state_from_slot(slot)
		end
	end

	--  FastReroll
	if key == rerollBind and ctrl_down() then
		FastReroll()
	end
	if key == autoBind and ctrl_down() then
		Brainstorm.AUTOREROLL.autoRerollActive = not Brainstorm.AUTOREROLL.autoRerollActive
	end

	-- Emergency stop for active seed search
	if key == "p" and ctrl_down() and Brainstorm.AUTOREROLL.autoRerollActive then
		Brainstorm.AUTOREROLL.autoRerollActive = false
		Brainstorm.AUTOREROLL.autoRerollFrames = 0
		Brainstorm.AUTOREROLL.rerollTimer = 0
		if Brainstorm.AUTOREROLL.rerollText and Brainstorm.remove_attention_text then
			Brainstorm.remove_attention_text(Brainstorm.AUTOREROLL.rerollText)
			Brainstorm.AUTOREROLL.rerollText = nil
		end
		if saveManagerAlert then
			saveManagerAlert("AutoReroll stopped [Ctrl+P]")
		end
	end
end

function Brainstorm.key_press_update(key)
	if Brainstorm.safe_call_result then
		local ok = Brainstorm.safe_call_result("Brainstorm.key_press_update", key_press_update_impl, key)
		if not ok and Brainstorm.log_debug then
			Brainstorm.log_debug("Key handler disabled for this key press due to error", true)
		end
		return
	end
	return key_press_update_impl(key)
end
