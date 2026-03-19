Brainstorm = {}
local tpack = table.pack or function(...)
	return {n = select("#", ...), ...}
end
local tunpack = table.unpack or unpack

Brainstorm.LOGGER = Brainstorm.LOGGER or {
	nativefs = nil,
	lovely = nil,
}

local function init_logger_handles()
	if Brainstorm.LOGGER.nativefs and Brainstorm.LOGGER.lovely then
		return true
	end
	local ok_lovely, lovely_mod = pcall(require, "lovely")
	local ok_nativefs, nativefs_mod = pcall(require, "nativefs")
	if ok_lovely then
		Brainstorm.LOGGER.lovely = lovely_mod
	end
	if ok_nativefs then
		Brainstorm.LOGGER.nativefs = nativefs_mod
	end
	return Brainstorm.LOGGER.nativefs ~= nil and Brainstorm.LOGGER.lovely ~= nil
end

function Brainstorm.get_debug_log_path()
	if not init_logger_handles() then
		return nil
	end
	return Brainstorm.LOGGER.lovely.mod_dir .. "/Brainstorm/brainstorm_debug.log"
end

function Brainstorm.log_debug(message, always_print)
	local stamp = os.date("%Y-%m-%d %H:%M:%S")
	local line = "[Brainstorm-Enhanced][" .. stamp .. "] " .. tostring(message)
	local log_path = Brainstorm.get_debug_log_path()
	if log_path and Brainstorm.LOGGER.nativefs and Brainstorm.LOGGER.nativefs.append then
		pcall(Brainstorm.LOGGER.nativefs.append, log_path, line .. "\n")
	end
	if always_print or (Brainstorm.SETTINGS and Brainstorm.SETTINGS.debug_mode) then
		print(line)
	end
end

local function stringify_pack_list(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	local out = {}
	for i = 1, #value do
		out[#out + 1] = tostring(value[i])
	end
	return table.concat(out, ",")
end

function Brainstorm.runtime_context()
	local parts = {}
	parts[#parts + 1] = "state=" .. tostring(G and G.STATE)
	parts[#parts + 1] = "stage=" .. tostring(G and G.STAGE)
	if G and G.GAME then
		parts[#parts + 1] = "run_seed=" .. tostring(G.GAME.pseudorandom and G.GAME.pseudorandom.seed)
		parts[#parts + 1] = "first_shop_buffoon=" .. tostring(G.GAME.first_shop_buffoon)
		if G.GAME.round_resets then
			parts[#parts + 1] = "ante=" .. tostring(G.GAME.round_resets.ante)
			parts[#parts + 1] = "blind=" .. tostring(G.GAME.round_resets.blind)
		end
	end
	if Brainstorm.SETTINGS and Brainstorm.SETTINGS.autoreroll then
		local ar = Brainstorm.SETTINGS.autoreroll
		parts[#parts + 1] = "searchTag=" .. tostring(ar.searchTag)
		parts[#parts + 1] = "searchVoucher=" .. tostring(ar.searchVoucher)
		parts[#parts + 1] = "searchPackSlot=" .. tostring(ar.searchPackShopSlot)
		parts[#parts + 1] = "searchPack=" .. stringify_pack_list(ar.searchPack)
		parts[#parts + 1] = "seedsPerFrame=" .. tostring(ar.seedsPerFrame)
	end
	return table.concat(parts, " | ")
end

function Brainstorm.log_error(context, err)
	local trace = tostring(err)
	if debug and debug.traceback then
		trace = debug.traceback(trace, 2)
	end
	Brainstorm.log_debug("ERROR in " .. tostring(context) .. ": " .. trace, true)
	local ok_ctx, ctx = pcall(Brainstorm.runtime_context)
	if ok_ctx and ctx and ctx ~= "" then
		Brainstorm.log_debug("Context: " .. ctx, true)
	end
end

function Brainstorm.safe_call_result(context, fn, ...)
	local args = tpack(...)
	local results = tpack(xpcall(function()
		return fn(tunpack(args, 1, args.n))
	end, function(err)
		Brainstorm.log_error(context, err)
		return err
	end))
	local ok = results[1]
	return ok, tunpack(results, 2, results.n)
end

local function deepcopy(tbl)
	if type(tbl) ~= "table" then return tbl end
	local out = {}
	for k, v in pairs(tbl) do
		out[k] = deepcopy(v)
	end
	return out
end

local function merge_defaults(dst, defaults)
	for k, v in pairs(defaults) do
		if type(v) == "table" then
			if type(dst[k]) ~= "table" then
				dst[k] = {}
			end
			merge_defaults(dst[k], v)
		elseif dst[k] == nil then
			dst[k] = v
		end
	end
end

local DEFAULT_SETTINGS = {
	autoreroll = {
		searchForSoul = 1,
		searchSoulCardModeID = 1,
		searchSoulCardMode = "soul_only",
		searchSoulResultID = 1,
		searchSoulResult = "",
		searchVoucher = "",
		searchPack = { "p_spectral_mega_1" },
		searchPackShopSlotID = 1,
		searchPackShopSlot = 1,
		searchTag = "tag_charm",
		searchVoucherID = 1,
		seedsPerFrameID = 3,
		seedsPerFrame = 1000,
		searchPackID = 21,
		searchTagID = 2,
	},
	debug_mode = false,
	keybinds = {
		loadState = "x",
		saveState = "z",
		autoReroll = "a",
		rerollSeed = "t",
	},
}

local function load_brainstorm_file(nativefs, path)
	local chunk_str, read_err = nativefs.read(path)
	if not chunk_str then
		error("Could not read file: " .. tostring(path) .. " | " .. tostring(read_err))
	end
	local chunk, load_err = load(chunk_str)
	if not chunk then
		error("Could not load file: " .. tostring(path) .. " | " .. tostring(load_err))
	end
	return chunk()
end

function initBrainstorm()
	local lovely = require("lovely")
	local nativefs = require("nativefs")
	Brainstorm.LOGGER.nativefs = nativefs
	Brainstorm.LOGGER.lovely = lovely

	local ok, err = Brainstorm.safe_call_result("initBrainstorm", function()
		load_brainstorm_file(nativefs, lovely.mod_dir .. "/Brainstorm/Brainstorm_main.lua")
		load_brainstorm_file(nativefs, lovely.mod_dir .. "/Brainstorm/Brainstorm_UI.lua")
		load_brainstorm_file(nativefs, lovely.mod_dir .. "/Brainstorm/Brainstorm_keyhandler.lua")
		load_brainstorm_file(nativefs, lovely.mod_dir .. "/Brainstorm/Brainstorm_reroll.lua")
		Brainstorm.SETTINGS = deepcopy(DEFAULT_SETTINGS)
		if nativefs.getInfo(lovely.mod_dir .. "/Brainstorm/settings.lua") then
			local settings_file = STR_UNPACK(nativefs.read((lovely.mod_dir .. "/Brainstorm/settings.lua")))
			if settings_file ~= nil then
				Brainstorm.SETTINGS = settings_file
			end
		end
		merge_defaults(Brainstorm.SETTINGS, DEFAULT_SETTINGS)
		nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
		_RELEASE_MODE = not Brainstorm.SETTINGS.debug_mode
		Brainstorm.log_debug("Initialized " .. tostring(Brainstorm.VER or "Brainstorm"), false)
	end)
	if not ok then
		error(err)
	end
end
