local lovely = require("lovely")
local nativefs = require("nativefs")

Brainstorm.AUTOREROLL = {}

G.FUNCS.change_search_tag = function(x)
	Brainstorm.SETTINGS.autoreroll.searchTagID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchTag = Brainstorm.SearchTagList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_voucher = function(x)
	Brainstorm.SETTINGS.autoreroll.searchVoucherID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchVoucher = Brainstorm.SearchVoucherList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_pack = function(x)
	Brainstorm.SETTINGS.autoreroll.searchPackID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchPack = Brainstorm.SearchPackList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_pack_slot = function(x)
	Brainstorm.SETTINGS.autoreroll.searchPackShopSlotID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchPackShopSlot = Brainstorm.SearchPackSlotList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_soul_count = function(x)
	Brainstorm.SETTINGS.autoreroll.searchForSoul = x.to_val
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_soul_card_mode = function(x)
	Brainstorm.SETTINGS.autoreroll.searchSoulCardModeID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchSoulCardMode = Brainstorm.SearchSoulCardModeList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_search_soul_result = function(x)
	Brainstorm.SETTINGS.autoreroll.searchSoulResultID = x.to_key
	Brainstorm.SETTINGS.autoreroll.searchSoulResult = Brainstorm.SearchSoulResultList[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

G.FUNCS.change_seeds_per_frame = function(x)
	Brainstorm.SETTINGS.autoreroll.seedsPerFrameID = x.to_key
	Brainstorm.SETTINGS.autoreroll.seedsPerFrame = Brainstorm.seedsPerFrame[x.to_val]
	nativefs.write(lovely.mod_dir .. "/Brainstorm/settings.lua", STR_PACK(Brainstorm.SETTINGS))
end

Brainstorm.AUTOREROLL.autoRerollActive = false
Brainstorm.AUTOREROLL.rerollInterval = 0.01 -- Time interval between rerolls (in seconds)
Brainstorm.AUTOREROLL.rerollTimer = 0

local function key_is_banned(key)
	if not key or not G or not G.GAME then return false end
	return (G.GAME.banned_keys and G.GAME.banned_keys[key])
		or (G.GAME.cry_banished_keys and G.GAME.cry_banished_keys[key])
end

local function center_to_key(center)
	if type(center) == "string" then
		return center
	end
	if type(center) == "table" and center.key then
		return center.key
	end
	return nil
end

local function is_unavailable_center(center)
	if center == "UNAVAILABLE" then
		return true
	end
	local key = center_to_key(center)
	return key and key_is_banned(key) or false
end

local function predict_pool_center(_type, _rarity, _legendary, _append, seed_found)
	if not get_current_pool then return nil end
	local _pool, _pool_key = get_current_pool(_type, _rarity, _legendary, _append)
	if not _pool or not _pool_key then return nil end
	local center = pseudorandom_element(_pool, Brainstorm.pseudoseed(_pool_key .. seed_found))
	local it = 1
	while is_unavailable_center(center) and it < 50 do
		it = it + 1
		center = pseudorandom_element(_pool, Brainstorm.pseudoseed(_pool_key .. "_resample" .. it .. seed_found))
	end
	if is_unavailable_center(center) then
		return nil
	end
	return center
end

function Brainstorm.predict_legendary_from_soul(seed_found)
	local center = predict_pool_center("Joker", nil, true, nil, seed_found)
	if center_to_key(center) then return center_to_key(center) end
	center = predict_pool_center("Joker", nil, true, "sou", seed_found)
	if center_to_key(center) then return center_to_key(center) end
	center = predict_pool_center("Joker", nil, true, "soul", seed_found)
	return center_to_key(center)
end

local function get_fallback_tag_pool()
	if not G then return nil end
	local pool = {}
	local seen = {}

	if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Tag then
		for _, entry in ipairs(G.P_CENTER_POOLS.Tag) do
			local key = center_to_key(entry)
			if key and not seen[key] and not key_is_banned(key) then
				seen[key] = true
				pool[#pool + 1] = key
			end
		end
	end
	if #pool > 0 then
		return pool
	end

	if G.P_TAGS then
		for k, entry in pairs(G.P_TAGS) do
			local key = center_to_key(entry)
			if not key and type(k) == "string" then
				key = k
			end
			if key and not seen[key] and not key_is_banned(key) then
				seen[key] = true
				pool[#pool + 1] = key
			end
		end
	end
	if #pool > 0 then
		table.sort(pool)
		return pool
	end

	return nil
end

function Brainstorm.predict_tag_from_seed(seed_found)
	local center = predict_pool_center("Tag", nil, nil, nil, seed_found)
	local key = center_to_key(center)
	if key then
		return key
	end
	local fallback_pool = get_fallback_tag_pool()
	if fallback_pool and #fallback_pool > 0 then
		return pseudorandom_element(fallback_pool, Brainstorm.pseudoseed("Tag1" .. seed_found))
	end
	return nil
end

local function get_fallback_voucher_pool()
	if not G then return nil end
	local pool = {}
	local seen = {}

	if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Voucher then
		for _, entry in ipairs(G.P_CENTER_POOLS.Voucher) do
			local key = center_to_key(entry)
			if key and not seen[key] and not key_is_banned(key) then
				seen[key] = true
				pool[#pool + 1] = key
			end
		end
	end
	if #pool > 0 then
		table.sort(pool)
		return pool
	end

	if G.P_VOUCHERS then
		for k, entry in pairs(G.P_VOUCHERS) do
			local key = center_to_key(entry)
			if not key and type(k) == "string" then
				key = k
			end
			if key and not seen[key] and not key_is_banned(key) then
				seen[key] = true
				pool[#pool + 1] = key
			end
		end
	end
	if #pool > 0 then
		table.sort(pool)
		return pool
	end

	return nil
end

function Brainstorm.predict_voucher_from_seed(seed_found)
	local center = predict_pool_center("Voucher", nil, nil, nil, seed_found)
	local key = center_to_key(center)
	if key then
		return key
	end
	local fallback_pool = get_fallback_voucher_pool()
	if fallback_pool and #fallback_pool > 0 then
		return pseudorandom_element(fallback_pool, Brainstorm.pseudoseed("Voucher1" .. seed_found))
	end
	return nil
end

local function get_fallback_booster_pool()
	if not G then return nil end
	local pool = {}
	local seen = {}

	if G.P_CENTER_POOLS and G.P_CENTER_POOLS.Booster then
		for _, entry in ipairs(G.P_CENTER_POOLS.Booster) do
			local key = center_to_key(entry)
			local center = (type(entry) == "table" and entry) or (G.P_CENTERS and G.P_CENTERS[key])
			if key and not seen[key] and not key_is_banned(key) then
				seen[key] = true
				pool[#pool + 1] = {
					key = key,
					weight = (center and center.weight) or 1,
				}
			end
		end
	end
	if #pool > 0 then
		return pool
	end

	if G.P_BOOSTERS then
		local keys = {}
		for k, _ in pairs(G.P_BOOSTERS) do
			if type(k) == "string" then
				keys[#keys + 1] = k
			end
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			local entry = G.P_BOOSTERS[key]
			local center = (type(entry) == "table" and entry) or (G.P_CENTERS and G.P_CENTERS[key])
			local resolved_key = center_to_key(entry) or key
			if resolved_key and not seen[resolved_key] and not key_is_banned(resolved_key) then
				seen[resolved_key] = true
				pool[#pool + 1] = {
					key = resolved_key,
					weight = (center and center.weight) or 1,
				}
			end
		end
	end
	if #pool > 0 then
		return pool
	end

	return nil
end

local function weighted_pick_booster(pool, seed_found, pack_slot)
	local cume = 0
	for _, entry in ipairs(pool) do
		cume = cume + (entry.weight or 1)
	end
	if cume <= 0 then
		return nil
	end
	local poll = pseudorandom(Brainstorm.pseudoseed(pack_slot .. seed_found)) * cume
	local it = 0
	for _, entry in ipairs(pool) do
		it = it + (entry.weight or 1)
		if it >= poll and it - (entry.weight or 1) <= poll then
			return entry.key
		end
	end
	return nil
end

local function get_weighted_shop_booster_pool()
	if not G then return nil end
	local pool = {}
	local source_pool = G.P_CENTER_POOLS and G.P_CENTER_POOLS.Booster

	if source_pool then
		for _, entry in ipairs(source_pool) do
			local center = (type(entry) == "table" and entry) or (G.P_CENTERS and G.P_CENTERS[center_to_key(entry)])
			local key = center_to_key(entry) or (center and center.key)
			if key then
				local add = true
				if SMODS and SMODS.add_to_pool then
					local res, pool_opts = SMODS.add_to_pool(center or entry)
					pool_opts = pool_opts or {}
					add = res and (add or pool_opts.override_base_checks)
				end
				if add and not key_is_banned(key) then
					local weight = (center and center.get_weight and center:get_weight()) or (center and center.weight) or 1
					pool[#pool + 1] = {key = key, weight = weight}
				end
			end
		end
	end

	if #pool > 0 then
		return pool
	end

	return get_fallback_booster_pool()
end

function Brainstorm.predict_booster_from_seed(seed_found, pack_slot)
	local slot = tonumber(pack_slot) or 1
	if slot < 1 or slot > 2 then
		slot = 1
	end

	local pool = get_weighted_shop_booster_pool()
	if not pool or #pool == 0 then
		return {}
	end

	local ante = (G and G.GAME and G.GAME.round_resets and G.GAME.round_resets.ante) or 1
	local shop_pack_seed_key = "shop_pack" .. tostring(ante)
	local forced_first_buffoon = G and G.GAME and (not G.GAME.first_shop_buffoon) and not key_is_banned("p_buffoon_normal_1")

	-- Vanilla/SMODS `get_pack('shop_pack')` short-circuits first call of a run to Buffoon.
	-- The second slot then consumes the *first* weighted shop_pack roll.
	if forced_first_buffoon then
		if slot == 1 then
			return {"p_buffoon_normal_1", "p_buffoon_normal_2"}
		end
		local second_slot_key = weighted_pick_booster(pool, seed_found, shop_pack_seed_key)
		return second_slot_key and {second_slot_key} or {}
	end

	local first_slot_key = weighted_pick_booster(pool, seed_found, shop_pack_seed_key)
	if slot == 1 then
		return first_slot_key and {first_slot_key} or {}
	end
	local second_slot_key = weighted_pick_booster(pool, seed_found, shop_pack_seed_key)
	return second_slot_key and {second_slot_key} or {}
end

function FastReroll()
	G.GAME.viewed_back = nil
	G.run_setup_seed = G.GAME.seeded
	G.challenge_tab = G.GAME and G.GAME.challenge and G.GAME.challenge_tab or nil
	G.forced_seed, G.setup_seed = nil, nil
	if G.GAME.seeded then
		G.forced_seed = G.GAME.pseudorandom.seed
	end
	local current_stake = G.GAME.stake
	local _seed = G.run_setup_seed and G.setup_seed or G.forced_seed or nil
	local _challenge = G.challenge_tab
	if not G.challenge_tab then
		_stake = current_stake or G.PROFILES[G.SETTINGS.profile].MEMORY.stake or 1
	else
		_stake = 1
	end
	G:delete_run()
	G:start_run({ stake = _stake, seed = _seed, challenge = _challenge })
end

local function auto_reroll_impl()
	local rerollsThisFrame = 0
	-- This part is meant to mimic how Balatro rerolls for Gold Stake
	local extra_num = -0.561892350821
	local seed_found = nil
	while not seed_found and rerollsThisFrame < Brainstorm.SETTINGS.autoreroll.seedsPerFrame do
		rerollsThisFrame = rerollsThisFrame + 1
		extra_num = extra_num + 0.561892350821
		seed_found = random_string(
			8,
			extra_num
				+ G.CONTROLLER.cursor_hover.T.x * 0.33411983
				+ G.CONTROLLER.cursor_hover.T.y * 0.874146
				+ 0.412311010 * G.CONTROLLER.cursor_hover.time
		)
		Brainstorm.random_state = {
			hashed_seed = pseudohash(seed_found),
		}
		if Brainstorm.SETTINGS.autoreroll.searchTag ~= "" then
			if key_is_banned(Brainstorm.SETTINGS.autoreroll.searchTag) then
				seed_found = nil
			else
				local predicted_tag = Brainstorm.predict_tag_from_seed(seed_found)
				if predicted_tag ~= Brainstorm.SETTINGS.autoreroll.searchTag then
					seed_found = nil
				end
			end
		end
		if seed_found and Brainstorm.SETTINGS.autoreroll.searchVoucher and Brainstorm.SETTINGS.autoreroll.searchVoucher ~= "" then
			if key_is_banned(Brainstorm.SETTINGS.autoreroll.searchVoucher) then
				seed_found = nil
			else
				local predicted_voucher = Brainstorm.predict_voucher_from_seed(seed_found)
				if predicted_voucher ~= Brainstorm.SETTINGS.autoreroll.searchVoucher then
					seed_found = nil
				end
			end
		end
		if seed_found and Brainstorm.SETTINGS.autoreroll.searchForSoul then
			local soul_mode = Brainstorm.SETTINGS.autoreroll.searchSoulCardMode or "soul_only"
			local target_legendary = Brainstorm.SETTINGS.autoreroll.searchSoulResult or ""
			-- Check if Arcana has The Soul and optionally match Cryptid Gateway logic
			for i = 1, Brainstorm.SETTINGS.autoreroll.searchForSoul do
				local card_found = false
				for j = 1, 5 do
					local soul_found = pseudorandom(Brainstorm.pseudoseed("soul_Tarot1" .. seed_found)) > 0.997
					local gateway_found = false
					if soul_mode ~= "soul_only" then
						gateway_found = pseudorandom(Brainstorm.pseudoseed("soul_Spectral1" .. seed_found)) > 0.997
					end
					if soul_mode == "soul_only" then
						card_found = soul_found
					elseif soul_mode == "gateway_only" then
						card_found = gateway_found
					else
						card_found = soul_found or gateway_found
					end
					if card_found and target_legendary ~= "" then
						if soul_mode == "gateway_only" then
							card_found = false
						else
							local predicted_legendary = Brainstorm.predict_legendary_from_soul(seed_found)
							card_found = predicted_legendary == target_legendary
						end
					end
					if card_found then break end
				end
				if not card_found then
					seed_found = nil
					break
				end
			end
		end
		if seed_found and Brainstorm.SETTINGS.autoreroll.searchPack and #Brainstorm.SETTINGS.autoreroll.searchPack > 0 then
			local selected_pack_keys = Brainstorm.SETTINGS.autoreroll.searchPack
			if type(selected_pack_keys) == "string" then
				selected_pack_keys = {selected_pack_keys}
			end
			local pack_found = false
			local pack_slot = tonumber(Brainstorm.SETTINGS.autoreroll.searchPackShopSlot) or 1
			if pack_slot < 1 or pack_slot > 2 then
				pack_slot = 1
			end
			local predicted_packs = Brainstorm.predict_booster_from_seed(seed_found, pack_slot)
			if type(predicted_packs) ~= "table" then
				predicted_packs = {predicted_packs}
			end
			for i = 1, #selected_pack_keys do
				for j = 1, #predicted_packs do
					if predicted_packs[j] and selected_pack_keys[i] == predicted_packs[j] then
						pack_found = true
						break
					end
				end
				if pack_found then break end
			end
			if not pack_found then
				seed_found = nil
			end
		end
		--[[
		Relevant vanilla pack code
		    local cume, it, center = 0, 0, nil
			for k, v in ipairs(G.P_CENTER_POOLS['Booster']) do
				if (not _type or _type == v.kind) and not G.GAME.banned_keys[v.key] then cume = cume + (v.weight or 1 ) end
			end
			local poll = pseudorandom(pseudoseed((_key or 'pack_generic')..G.GAME.round_resets.ante))*cume
			for k, v in ipairs(G.P_CENTER_POOLS['Booster']) do
				if not G.GAME.banned_keys[v.key] then 
					if not _type or _type == v.kind then it = it + (v.weight or 1) end
					if it >= poll and it - (v.weight or 1) <= poll then center = v; break end
				end
			end
			return center
		]]
	end
	if seed_found then
		_stake = G.GAME.stake
		G:delete_run()
		G:start_run({
			stake = _stake,
			seed = seed_found,
			challenge = G.GAME and G.GAME.challenge and G.GAME.challenge_tab,
		})
		G.GAME.seeded = false
	end
	return seed_found
end

function Brainstorm.auto_reroll()
	if Brainstorm.safe_call_result then
		local ok, seed_found = Brainstorm.safe_call_result("Brainstorm.auto_reroll", auto_reroll_impl)
		if not ok then
			if Brainstorm.AUTOREROLL then
				Brainstorm.AUTOREROLL.autoRerollActive = false
				Brainstorm.AUTOREROLL.autoRerollFrames = 0
				Brainstorm.AUTOREROLL.rerollTimer = 0
			end
			return nil
		end
		return seed_found
	end
	return auto_reroll_impl()
end

function Brainstorm.searchParametersMet()
	--note: this appears to be deprecated, so I didn't update it
	if not G or not G.GAME or not G.GAME.round_resets or not G.GAME.round_resets.blind_tags then
		print("One or more variables are nil or undefined")
		return false
	end

	local _tag = G.GAME.round_resets.blind_tags.Small
	if not _tag then
		print("Value of _tag is nil or undefined")
		return false
	end

	if _tag == Brainstorm.SETTINGS.autoreroll.searchTag then
		if Brainstorm.SETTINGS.autoreroll.searchForSoul then
			return true
		end
		-- Check if arcana pack from skip has The Soul
		Brainstorm.random_state = copy_table(G.GAME.pseudorandom)
		for i = 1, 5 do
			if pseudorandom(Brainstorm.pseudoseed("soul_Tarot1")) > 0.997 then
				return true
			end
		end
		return false
	else
		return false
	end
end

function wait(seconds)
	local start = os.clock()
	while os.clock() - start < seconds do
		-- Busy wait
	end
end

function Brainstorm.pseudoseed(key, predict_seed)
	if key == "seed" then
		return math.random()
	end

	if predict_seed then
		local _pseed = pseudohash(key .. (predict_seed or ""))
		_pseed = math.abs(tonumber(string.format("%.13f", (2.134453429141 + _pseed * 1.72431234) % 1)))
		return (_pseed + (pseudohash(predict_seed) or 0)) / 2
	end

	if not Brainstorm.random_state[key] then
		Brainstorm.random_state[key] = pseudohash(key .. (Brainstorm.random_state.seed or ""))
	end

	Brainstorm.random_state[key] =
		math.abs(tonumber(string.format("%.13f", (2.134453429141 + Brainstorm.random_state[key] * 1.72431234) % 1)))
	return (Brainstorm.random_state[key] + (Brainstorm.random_state.hashed_seed or 0)) / 2
end

--Used for reroll UI
--Based on Balatro's attention_text
function Brainstorm.attention_text(args)
    args = args or {}
    args.text = args.text or 'test'
    args.scale = args.scale or 1
    args.colour = copy_table(args.colour or G.C.WHITE)
    args.hold = (args.hold or 0) + 0.1*(G.SPEEDFACTOR)
    args.pos = args.pos or {x = 0, y = 0}
    args.align = args.align or 'cm'
    args.emboss = args.emboss or nil

    args.fade = 1

    if args.cover then
      args.cover_colour = copy_table(args.cover_colour or G.C.RED)
      args.cover_colour_l = copy_table(lighten(args.cover_colour, 0.2))
      args.cover_colour_d = copy_table(darken(args.cover_colour, 0.2))
    else
      args.cover_colour = copy_table(G.C.CLEAR)
    end

    args.uibox_config = {
      align = args.align or 'cm',
      offset = args.offset or {x=0,y=0}, 
      major = args.cover or args.major or nil,
    }

    G.E_MANAGER:add_event(Event({
      trigger = 'after',
      delay = 0,
      blockable = false,
      blocking = false,
      func = function()
          args.AT = UIBox{
            T = {args.pos.x,args.pos.y,0,0},
            definition = 
              {n=G.UIT.ROOT, config = {align = args.cover_align or 'cm', minw = (args.cover and args.cover.T.w or 0.001) + (args.cover_padding or 0), minh = (args.cover and args.cover.T.h or 0.001) + (args.cover_padding or 0), padding = 0.03, r = 0.1, emboss = args.emboss, colour = args.cover_colour}, nodes={
                {n=G.UIT.O, config={draw_layer = 1, object = DynaText({scale = args.scale, string = args.text, maxw = args.maxw, colours = {args.colour},float = true, shadow = true, silent = not args.noisy, args.scale, pop_in = 0, pop_in_rate = 6, rotate = args.rotate or nil})}},
              }}, 
            config = args.uibox_config
          }
          args.AT.attention_text = true

          args.text = args.AT.UIRoot.children[1].config.object
          args.text:pulse(0.5)

          if args.cover then
            Particles(args.pos.x,args.pos.y, 0,0, {
              timer_type = 'TOTAL',
              timer = 0.01,
              pulse_max = 15,
              max = 0,
              scale = 0.3,
              vel_variation = 0.2,
              padding = 0.1,
              fill=true,
              lifespan = 0.5,
              speed = 2.5,
              attach = args.AT.UIRoot,
              colours = {args.cover_colour, args.cover_colour_l, args.cover_colour_d},
          })
          end
          if args.backdrop_colour then
            args.backdrop_colour = copy_table(args.backdrop_colour)
            Particles(args.pos.x,args.pos.y,0,0,{
              timer_type = 'TOTAL',
              timer = 5,
              scale = 2.4*(args.backdrop_scale or 1), 
              lifespan = 5,
              speed = 0,
              attach = args.AT,
              colours = {args.backdrop_colour}
            })
          end
          return true
      end
      }))
      return args
end

function Brainstorm.remove_attention_text(args)
    G.E_MANAGER:add_event(Event({
        trigger = 'after',
        delay = 0,
        blockable = false,
        blocking = false,
        func = function()
          if not args.start_time then
            args.start_time = G.TIMERS.TOTAL
            args.text:pop_out(3)
          else
            --args.AT:align_to_attach()
            args.fade = math.max(0, 1 - 3*(G.TIMERS.TOTAL - args.start_time))
            if args.cover_colour then args.cover_colour[4] = math.min(args.cover_colour[4], 2*args.fade) end
            if args.cover_colour_l then args.cover_colour_l[4] = math.min(args.cover_colour_l[4], args.fade) end
            if args.cover_colour_d then args.cover_colour_d[4] = math.min(args.cover_colour_d[4], args.fade) end
            if args.backdrop_colour then args.backdrop_colour[4] = math.min(args.backdrop_colour[4], args.fade) end
            args.colour[4] = math.min(args.colour[4], args.fade)
            if args.fade <= 0 then
              args.AT:remove()
              return true
            end
          end
        end
      }))
end
