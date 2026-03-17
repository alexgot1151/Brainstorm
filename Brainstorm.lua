Brainstorm = {}
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
		searchPack = { "p_spectral_mega_1" },
		searchTag = "tag_charm",
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

function initBrainstorm()
	local lovely = require("lovely")
	local nativefs = require("nativefs")
	assert(load(nativefs.read(lovely.mod_dir .. "/Brainstorm/Brainstorm_main.lua")))()
	assert(load(nativefs.read(lovely.mod_dir .. "/Brainstorm/Brainstorm_UI.lua")))()
	assert(load(nativefs.read(lovely.mod_dir .. "/Brainstorm/Brainstorm_keyhandler.lua")))()
	assert(load(nativefs.read(lovely.mod_dir .. "/Brainstorm/Brainstorm_reroll.lua")))()
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
end

