local lovely = require("lovely")
local nativefs = require("nativefs")



Brainstorm.SearchTagList = {
	["None"] = "",
}
Brainstorm.SearchVoucherList = {
	["None"] = "",
}

Brainstorm.SearchPackList = {
	["None"] = {},
}
Brainstorm.SearchPackSlotList = {
	["Shop 1"] = 1,
	["Shop 2"] = 2,
}
Brainstorm.SearchSoulCardModeList = {
	["Soul Only"] = "soul_only",
	["Soul or Gateway (Cryptid)"] = "soul_or_gateway",
	["Gateway Only (Cryptid)"] = "gateway_only",
}
Brainstorm.SearchSoulResultList = {
	["Any Legendary"] = "",
}
Brainstorm.seedsPerFrame = {
    ["500"] = 500,
    ["750"] = 750,
    ["1000"] = 1000,
}

local searchPackSlotKeys = {"Shop 1", "Shop 2"}
local searchSoulCardModeKeys = {"Soul Only", "Soul or Gateway (Cryptid)", "Gateway Only (Cryptid)"}
local seedsPerFrame = {"500", "750", "1000"}
-- print(Brainstorm.FUNCS.inspect(searchTagKeys))

local function normalize_pool_center(entry)
	if type(entry) == "table" then
		return entry
	end
	if type(entry) == "string" and G and G.P_CENTERS then
		return G.P_CENTERS[entry]
	end
	return nil
end

local function normalize_pool_key(entry, center)
	if type(entry) == "string" then
		return entry
	end
	if center and center.key then
		return center.key
	end
	return nil
end

local function collect_pool_centers(pool)
	local out = {}
	local seen = {}
	if type(pool) ~= "table" then
		return out
	end
	for _, entry in pairs(pool) do
		local center = normalize_pool_center(entry)
		local key = normalize_pool_key(entry, center)
		if key and not seen[key] then
			seen[key] = true
			out[#out + 1] = {center = center, key = key}
		end
	end
	return out
end

local function copy_key_list(list)
	local out = {}
	if type(list) ~= "table" then
		return out
	end
	for i = 1, #list do
		out[i] = list[i]
	end
	return out
end

local function same_key_list(a, b)
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	if #a ~= #b then
		return false
	end
	local counts = {}
	for _, key in ipairs(a) do
		counts[key] = (counts[key] or 0) + 1
	end
	for _, key in ipairs(b) do
		if not counts[key] then
			return false
		end
		counts[key] = counts[key] - 1
		if counts[key] < 0 then
			return false
		end
	end
	for _, count in pairs(counts) do
		if count ~= 0 then
			return false
		end
	end
	return true
end

local function sorted_keys_from_set(set_table)
	local keys = {}
	for key, _ in pairs(set_table) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

local function infer_pack_size_label(key)
	local lower = string.lower(key or "")
	if string.find(lower, "_normal_", 1, true) then
		return "Normal"
	end
	if string.find(lower, "_jumbo_", 1, true) then
		return "Jumbo"
	end
	if string.find(lower, "_mega_", 1, true) then
		return "Mega"
	end
	return nil
end

local function log_pack_pool_diagnostics(raw_entries, deduped_entries)
	if not Brainstorm.SETTINGS or not Brainstorm.SETTINGS.debug_mode then
		return
	end

	local function inc(map, key)
		map[key] = (map[key] or 0) + 1
	end

	local function sorted_duplicate_items(map)
		local items = {}
		for key, count in pairs(map) do
			if count > 1 then
				items[#items + 1] = {key = key, count = count}
			end
		end
		table.sort(items, function(a, b)
			if a.count == b.count then
				return a.key < b.key
			end
			return a.count > b.count
		end)
		return items
	end

	local source_counts = {}
	local key_counts = {}
	local label_counts = {}
	local base_key_counts = {}
	local base_label_counts = {}
	for _, entry in ipairs(raw_entries) do
		inc(source_counts, entry.source or "unknown")
		inc(key_counts, entry.key or "nil")
		inc(label_counts, entry.label or "nil")
		if (entry.mod_id or "base") == "base" then
			inc(base_key_counts, entry.key or "nil")
			inc(base_label_counts, entry.label or "nil")
		end
	end

	local lines = {}
	lines[#lines + 1] = "Brainstorm Pack Pool Diagnostics"
	lines[#lines + 1] = "raw_entries=" .. tostring(#raw_entries) .. ", deduped_entries=" .. tostring(#deduped_entries)
	lines[#lines + 1] = "source_counts:"
	for source, count in pairs(source_counts) do
		lines[#lines + 1] = "  " .. source .. ": " .. tostring(count)
	end

	local dup_all_keys = sorted_duplicate_items(key_counts)
	local dup_base_keys = sorted_duplicate_items(base_key_counts)
	local dup_all_labels = sorted_duplicate_items(label_counts)
	local dup_base_labels = sorted_duplicate_items(base_label_counts)

	lines[#lines + 1] = "duplicate_keys_all(" .. tostring(#dup_all_keys) .. "):"
	for _, item in ipairs(dup_all_keys) do
		lines[#lines + 1] = "  [" .. tostring(item.count) .. "] " .. tostring(item.key)
	end
	lines[#lines + 1] = "duplicate_keys_base_only(" .. tostring(#dup_base_keys) .. "):"
	for _, item in ipairs(dup_base_keys) do
		lines[#lines + 1] = "  [" .. tostring(item.count) .. "] " .. tostring(item.key)
	end

	lines[#lines + 1] = "duplicate_labels_all(" .. tostring(#dup_all_labels) .. "):"
	for _, item in ipairs(dup_all_labels) do
		lines[#lines + 1] = "  [" .. tostring(item.count) .. "] " .. tostring(item.key)
	end
	lines[#lines + 1] = "duplicate_labels_base_only(" .. tostring(#dup_base_labels) .. "):"
	for _, item in ipairs(dup_base_labels) do
		lines[#lines + 1] = "  [" .. tostring(item.count) .. "] " .. tostring(item.key)
	end

	lines[#lines + 1] = "raw_entries_detail:"
	for _, entry in ipairs(raw_entries) do
		lines[#lines + 1] =
			"  source=" .. tostring(entry.source)
			.. " | mod=" .. tostring(entry.mod_id)
			.. " | kind=" .. tostring(entry.kind)
			.. " | key=" .. tostring(entry.key)
			.. " | label=" .. tostring(entry.label)
	end

	local log_path = lovely.mod_dir .. "/pack_pool_debug.log"
	nativefs.write(log_path, table.concat(lines, "\n"))
	print("[Brainstorm] Pack diagnostics saved: " .. log_path)
end

local function build_pack_keys()
	Brainstorm.SearchPackList = {
		["None"] = {},
	}
	local keys = {"None"}

	if G then
		local boosters = {}
		local seen = {}
		local raw_entries = {}
		local function add_entries(entries, source_name)
			for _, entry in ipairs(entries) do
				local center = entry.center or (G and G.P_CENTERS and G.P_CENTERS[entry.key])
				raw_entries[#raw_entries + 1] = {
					source = source_name,
					key = entry.key,
					label = tostring((center and center.name) or entry.key),
					kind = tostring((center and center.kind) or "Other"),
					mod_id = (center and center.mod and center.mod.id) or "base",
				}
				if not seen[entry.key] then
					seen[entry.key] = true
					boosters[#boosters + 1] = entry
				end
			end
		end
		if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Booster then
			add_entries(collect_pool_centers(G.P_CENTER_POOLS.Booster), "G.P_CENTER_POOLS.Booster")
		end
		if G.P_BOOSTERS then
			add_entries(collect_pool_centers(G.P_BOOSTERS), "G.P_BOOSTERS")
		end

		local by_kind = {}
		local by_kind_size = {}
		local singles = {}

		for _, entry in ipairs(boosters) do
			local center = entry.center or (G and G.P_CENTERS and G.P_CENTERS[entry.key])
			local kind = tostring((center and center.kind) or "Other")

			by_kind[kind] = by_kind[kind] or {}
			by_kind[kind][entry.key] = true

			local size_label = infer_pack_size_label(entry.key)
			if size_label then
				by_kind_size[kind] = by_kind_size[kind] or {}
				by_kind_size[kind][size_label] = by_kind_size[kind][size_label] or {}
				by_kind_size[kind][size_label][entry.key] = true
			end

			local label = tostring((center and center.name) or entry.key)
			singles[#singles + 1] = {
				label = label,
				key = entry.key,
			}
		end

		local preferred_kinds = {"Arcana", "Celestial", "Standard", "Buffoon", "Spectral"}
		local kind_order = {}
		local kind_seen = {}
		for _, kind in ipairs(preferred_kinds) do
			if by_kind[kind] then
				kind_order[#kind_order + 1] = kind
				kind_seen[kind] = true
			end
		end
		local extra_kinds = {}
		for kind, _ in pairs(by_kind) do
			if not kind_seen[kind] then
				extra_kinds[#extra_kinds + 1] = kind
			end
		end
		table.sort(extra_kinds)
		for _, kind in ipairs(extra_kinds) do
			kind_order[#kind_order + 1] = kind
		end

		for _, kind in ipairs(kind_order) do
			Brainstorm.SearchPackList[kind] = sorted_keys_from_set(by_kind[kind])
			keys[#keys + 1] = kind
			if by_kind_size[kind] then
				for _, size_label in ipairs({"Normal", "Jumbo", "Mega"}) do
					if by_kind_size[kind][size_label] then
						local label = size_label .. " " .. kind
						Brainstorm.SearchPackList[label] = sorted_keys_from_set(by_kind_size[kind][size_label])
						keys[#keys + 1] = label
					end
				end
			end
		end

		-- Collapse identical display labels into a single selectable entry.
		local singles_by_label = {}
		for _, entry in ipairs(singles) do
			if not singles_by_label[entry.label] then
				singles_by_label[entry.label] = {}
			end
			singles_by_label[entry.label][#singles_by_label[entry.label] + 1] = entry.key
		end
		local single_labels = {}
		for label, _ in pairs(singles_by_label) do
			single_labels[#single_labels + 1] = label
		end
		table.sort(single_labels)
		for _, base_label in ipairs(single_labels) do
			local pack_keys = singles_by_label[base_label]
			table.sort(pack_keys)
			local label = base_label
			if Brainstorm.SearchPackList[label] ~= nil then
				if #pack_keys == 1 then
					label = base_label .. " (" .. pack_keys[1] .. ")"
				else
					label = base_label .. " (" .. tostring(#pack_keys) .. " variants)"
				end
			end
			Brainstorm.SearchPackList[label] = copy_key_list(pack_keys)
			keys[#keys + 1] = label
		end

		log_pack_pool_diagnostics(raw_entries, boosters)
	end

	local current = Brainstorm.SETTINGS.autoreroll.searchPack or {}
	if type(current) == "string" then
		current = {current}
	end
	local current_id = 1
	for i, label in ipairs(keys) do
		if same_key_list(Brainstorm.SearchPackList[label], current) then
			current_id = i
			break
		end
	end
	if type(current) == "table" and #current > 0 and current_id == 1 then
		local extra_label = "Current Pack Filter"
		local suffix = 2
		while Brainstorm.SearchPackList[extra_label] ~= nil do
			extra_label = "Current Pack Filter " .. suffix
			suffix = suffix + 1
		end
		Brainstorm.SearchPackList[extra_label] = copy_key_list(current)
		keys[#keys + 1] = extra_label
		current_id = #keys
	end

	return keys, current_id
end

local function build_tag_keys()
	Brainstorm.SearchTagList = {
		["None"] = "",
	}
	local keys = {"None"}
	if G then
		local tags = {}
		local seen = {}
		local function add_tag_entries(entries)
			for _, entry in ipairs(entries) do
				if not seen[entry.key] then
					seen[entry.key] = true
					local label = entry.key
					if entry.center and entry.center.name then
						label = entry.center.name
					elseif G and G.P_CENTERS and G.P_CENTERS[entry.key] and G.P_CENTERS[entry.key].name then
						label = G.P_CENTERS[entry.key].name
					end
					label = tostring(label)
					tags[#tags + 1] = {label = label, key = entry.key}
				end
			end
		end
		if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Tag then
			add_tag_entries(collect_pool_centers(G.P_CENTER_POOLS.Tag))
		end
		if G.P_TAGS then
			add_tag_entries(collect_pool_centers(G.P_TAGS))
		end
		table.sort(tags, function(a, b)
			if a.label == b.label then
				return a.key < b.key
			end
			return a.label < b.label
		end)
		for _, entry in ipairs(tags) do
			local label = entry.label
			if Brainstorm.SearchTagList[label] ~= nil then
				label = entry.label .. " (" .. entry.key .. ")"
			end
			Brainstorm.SearchTagList[label] = entry.key
			keys[#keys + 1] = label
		end
	end

	local current = Brainstorm.SETTINGS.autoreroll.searchTag or ""
	local current_id = 1
	for i, label in ipairs(keys) do
		if Brainstorm.SearchTagList[label] == current then
			current_id = i
			break
		end
	end
	if current ~= "" and current_id == 1 then
		local extra_label = "Current (" .. current .. ")"
		Brainstorm.SearchTagList[extra_label] = current
		keys[#keys + 1] = extra_label
		current_id = #keys
	end

	return keys, current_id
end

local function build_voucher_keys()
	Brainstorm.SearchVoucherList = {
		["None"] = "",
	}
	local keys = {"None"}
	if G then
		local vouchers = {}
		local seen = {}
		local function add_voucher_entries(entries)
			for _, entry in ipairs(entries) do
				if not seen[entry.key] then
					seen[entry.key] = true
					local label = entry.key
					if entry.center and entry.center.name then
						label = entry.center.name
					elseif G and G.P_CENTERS and G.P_CENTERS[entry.key] and G.P_CENTERS[entry.key].name then
						label = G.P_CENTERS[entry.key].name
					end
					label = tostring(label)
					vouchers[#vouchers + 1] = {label = label, key = entry.key}
				end
			end
		end
		if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Voucher then
			add_voucher_entries(collect_pool_centers(G.P_CENTER_POOLS.Voucher))
		end
		if G.P_VOUCHERS then
			add_voucher_entries(collect_pool_centers(G.P_VOUCHERS))
		end
		table.sort(vouchers, function(a, b)
			if a.label == b.label then
				return a.key < b.key
			end
			return a.label < b.label
		end)
		for _, entry in ipairs(vouchers) do
			local label = entry.label
			if Brainstorm.SearchVoucherList[label] ~= nil then
				label = entry.label .. " (" .. entry.key .. ")"
			end
			Brainstorm.SearchVoucherList[label] = entry.key
			keys[#keys + 1] = label
		end
	end

	local current = Brainstorm.SETTINGS.autoreroll.searchVoucher or ""
	local current_id = 1
	for i, label in ipairs(keys) do
		if Brainstorm.SearchVoucherList[label] == current then
			current_id = i
			break
		end
	end
	if current ~= "" and current_id == 1 then
		local extra_label = "Current (" .. current .. ")"
		Brainstorm.SearchVoucherList[extra_label] = current
		keys[#keys + 1] = extra_label
		current_id = #keys
	end

	return keys, current_id
end

local function build_soul_result_keys()
	Brainstorm.SearchSoulResultList = {
		["Any Legendary"] = "",
	}
	local keys = {"Any Legendary"}
	if G and G.P_CENTER_POOLS and G.P_CENTER_POOLS.Joker then
		local targets = {}
		for _, entry in ipairs(collect_pool_centers(G.P_CENTER_POOLS.Joker)) do
			local center = entry.center or (G and G.P_CENTERS and G.P_CENTERS[entry.key])
			if center and center.rarity == 4 then
				local label = tostring(center.name or entry.key)
				targets[#targets + 1] = {label = label, key = entry.key}
			end
		end
		table.sort(targets, function(a, b)
			if a.label == b.label then
				return a.key < b.key
			end
			return a.label < b.label
		end)
		for _, entry in ipairs(targets) do
			local label = entry.label
			if Brainstorm.SearchSoulResultList[label] ~= nil then
				label = entry.label .. " (" .. entry.key .. ")"
			end
			Brainstorm.SearchSoulResultList[label] = entry.key
			keys[#keys + 1] = label
		end
	end
	local current = Brainstorm.SETTINGS.autoreroll.searchSoulResult or ""
	local current_id = 1
	for i, label in ipairs(keys) do
		if Brainstorm.SearchSoulResultList[label] == current then
			current_id = i
			break
		end
	end
	return keys, current_id
end

Brainstorm.G_FUNCS_options_ref = G.FUNCS.options
G.FUNCS.options = function(e)
	Brainstorm.G_FUNCS_options_ref(e)
end
local ct = create_tabs
function create_tabs(args)
	if args and args.tab_h == 7.05 then
		local searchTagKeys, searchTagID = build_tag_keys()
		local searchVoucherKeys, searchVoucherID = build_voucher_keys()
		local searchPackKeys, searchPackID = build_pack_keys()
		local searchSoulResultKeys, searchSoulResultID = build_soul_result_keys()
		args.tabs[#args.tabs + 1] = {
			label = "Brainstorm",
			tab_definition_function = function()
				return {
					n = G.UIT.ROOT,
					config = {
						align = "cm",
						padding = 0.05,
						colour = G.C.CLEAR,
					},
					nodes = {
						create_toggle({
							label = "Debug Mode",
							ref_table = Brainstorm.SETTINGS,
							ref_value = "debug_mode",
							callback = function(_set_toggle)
								_RELEASE_MODE = not Brainstorm.SETTINGS.debug_mode
								G.F_NO_ACHIEVEMENTS = Brainstorm.SETTINGS.debug_mode
							end,
						}),
						create_option_cycle({
							label = "AutoReroll Search Tag",
							scale = 0.8,
							w = 4,
							options = searchTagKeys,
							opt_callback = "change_search_tag",
							current_option = searchTagID,
						}),
						create_option_cycle({
							label = "AutoReroll Search Voucher",
							scale = 0.8,
							w = 4,
							options = searchVoucherKeys,
							opt_callback = "change_search_voucher",
							current_option = searchVoucherID,
						}),
						create_option_cycle({
							label = "AutoReroll Search Pack",
							scale = 0.8,
							w = 4,
							options = searchPackKeys,
							opt_callback = "change_search_pack",
							current_option = searchPackID,
						}),
						create_option_cycle({
							label = "AutoReroll Pack Shop Slot",
							scale = 0.8,
							w = 4,
							options = searchPackSlotKeys,
							opt_callback = "change_search_pack_slot",
							current_option = Brainstorm.SETTINGS.autoreroll.searchPackShopSlotID or 1,
						}),
						create_option_cycle({
							label = "Charm Tag/Arcana Pack: Number of Souls",
							scale = 0.8,
							w = 4,
							options = {0,1,2},
							opt_callback = "change_search_soul_count",
							current_option = Brainstorm.SETTINGS.autoreroll.searchForSoul + 1 or 1,
						}),
						create_option_cycle({
							label = "Soul Card Mode",
							scale = 0.8,
							w = 4,
							options = searchSoulCardModeKeys,
							opt_callback = "change_search_soul_card_mode",
							current_option = Brainstorm.SETTINGS.autoreroll.searchSoulCardModeID or 1,
						}),
						create_option_cycle({
							label = "Soul Result Target",
							scale = 0.8,
							w = 4,
							options = searchSoulResultKeys,
							opt_callback = "change_search_soul_result",
							current_option = searchSoulResultID,
						}),
                        create_option_cycle({
							label = "Rerolls per Frame",
							scale = 0.8,
							w = 4,
							options = seedsPerFrame,
							opt_callback = "change_seeds_per_frame",
							current_option = Brainstorm.SETTINGS.autoreroll.seedsPerFrameID or 1,
						}),
					},
				}
			end,
			tab_definition_function_args = "Brainstorm",
		}
	end
	return ct(args)
end
function saveManagerAlert(text)
	G.E_MANAGER:add_event(Event({
		trigger = "after",
		delay = 0.4,
		func = function()
			attention_text({
				text = text,
				scale = 0.7,
				hold = 3,
				major = G.STAGE == G.STAGES.RUN and G.play or G.title_top,
				backdrop_colour = G.C.SECONDARY_SET.Tarot,
				align = "cm",
				offset = {
					x = 0,
					y = -3.5,
				},
				silent = true,
			})
			G.E_MANAGER:add_event(Event({
				trigger = "after",
				delay = 0.06 * G.SETTINGS.GAMESPEED,
				blockable = false,
				blocking = false,
				func = function()
					play_sound("other1", 0.76, 0.4)
					return true
				end,
			}))
			return true
		end,
	}))
end
