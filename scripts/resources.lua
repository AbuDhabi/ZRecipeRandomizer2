local resource_util = require "scripts.resource_util"
local util = require "scripts.util"

local resourcesModule = {}

function resourcesModule.new()
	local not_random_ores = settings.startup["z-randomizer-not-random-ore-processing"].value

	local F = {}

	F.rawTBN = {}
	F.default = {}
	F.waiting = {}
	F.prepared = {}
	F.unlocked_itemsTBN = {}
	F.unlocked_categories = {}
	F.category_unlocks = {}
	F.tech_defaults = {}
	F.item_defaults = {}

	F.dont_randomize_ingredients = nil
	F.recipes = nil

	F.queue = {q = {}, a = {}, i = 0, s = 0}

	F.calculated = {}
	F.calcs = {}
	F.current_tech = nil
	F.current_recipes = {}

	F.base_raw = {value = 0}

	function F.init(defaults, default_categories, cat_unlocks, d_r_i, rs)
		F.current_tech = util.default_tech_name
		F.dont_randomize_ingredients = d_r_i
		F.recipes = rs
		F.unlocked_categories = table.deepcopy(default_categories)
		F.category_unlocks = cat_unlocks
		for item, tbl in pairs(defaults) do
			F.default[item] = tbl.value
			if tbl.tech then
				if not F.tech_defaults[tbl.tech] then
					F.tech_defaults[tbl.tech] = {}
				end
				F.tech_defaults[tbl.tech][#F.tech_defaults[tbl.tech] + 1] = {item = item, value = tbl.value}
			elseif tbl.items then
				F.item_defaults[#F.item_defaults + 1] = {locks = table.deepcopy(tbl.items), item = item, value = tbl.value}
			else
				F.update(item, {value = tbl.value, complexity = util.default_complexity, [item] = 1}, nil, {}, true)
			end
			F.base_raw[item] = 1 / tbl.value
		end
	end

	function F.raw(item)
		return F.rawTBN[item]
	end

	function F.unlocked_items()
		return F.unlocked_itemsTBN
	end

	function F.all_not_calculated()
		local ret = {}
		for key, value in pairs(F.prepared) do
			if not F.calcs[key] then
				ret[key] = value
			end
		end
		return ret
	end

	local function unlock(item, recipe)
		local un = false
		if not F.unlocked_itemsTBN[item] then
			F.unlocked_itemsTBN[item] = {}
			un = true
		else
			for _, value in ipairs(F.current_recipes) do
				if value == recipe then
					un = true
					break
				end
			end
		end
		if un and not F.unlocked_itemsTBN[item][F.current_tech] then
			F.unlocked_itemsTBN[item][F.current_tech] = true
			if F.category_unlocks[item] then
				for _, cat in pairs(F.category_unlocks[item]) do
					if not F.unlocked_categories[cat] then
						F.unlocked_categories[cat] = {[F.current_tech] = true}
						if F.waiting["CAT-" .. cat] then
							for r, rly in pairs(F.waiting["CAT-" .. cat]) do
								F.queue.add(r)
							end
						end
						F.waiting["CAT-" .. cat] = nil
					else
						F.unlocked_categories[cat][F.current_tech] = true
					end
				end
			end
		end
	end

	function F.pattern(recipe_name)
		local pattern = {}
		local total_raw = {value = 0, time = 0}
		local changeable = {}
		local recipe = F.recipes[recipe_name]
		local raws = {}
		if recipe == nil then
			return
		end
		for i = 1, #recipe.ing, 1 do
			local ing = recipe.ing[i]
			local item = util.dot(ing)
			local r = table.deepcopy(F.rawTBN[item])
			if r and not r.time then
				r.time = 1
			end
			if not r and not F.prepared[recipe_name].removed_ings[item] then
				return
			end
			if #changeable >= 5 or not r or r.value == 0 or r.value == math.huge or (not_random_ores and string.match(item, "^item%..*%-ore$")) or F.dont_randomize_ingredients[item] then
				pattern[i] = {type = ing.type, name = ing.name, amount = ing.amount, value = r and r.value or 0}
			else
				changeable[#changeable + 1] = i
				pattern[i] = {type = ing.type, comp = r.complexity, on = ing.name, oa = ing.amount}
				raws[i] = resource_util.multiply(r, ing.amount)
				total_raw = resource_util.add(total_raw, raws[i])
			end
		end
		return {pattern = pattern, raw = total_raw, changeable = changeable, raws = raws}
	end

	local function recalculate(recipe_name, trace, last_when_loop)

		local r = F.prepared[recipe_name]

		if r == nil or r.ia == 0 or r.ra == 0 then
			return
		end
		if r.category ~= nil and not F.unlocked_categories[r.category] then
			if not F.waiting["CAT-" .. r.category] then
				F.waiting["CAT-" .. r.category] = {}
			end
			F.waiting["CAT-" .. r.category][recipe_name] = true
			return
		end

		local comp = {value = 0, time = 4 * r.time, complexity = util.default_complexity}
		local ex = {}
		for name, amt in pairs(r.res) do
			ex[name] = amt
		end
		local ready = true
		for name, amt in pairs(r.ing) do
			local got = F.rawTBN[name]
			if got then
				if not got.time then
					comp.time = comp.time + amt
				end
				comp = resource_util.add(comp, resource_util.multiply(got, amt))
			else
				ready = false
				break
			end
		end

		for key, _ in pairs(r.ing) do
			if not F.waiting[key] then
				F.waiting[key] = {[recipe_name] = true}
			elseif F.waiting[key][recipe_name] == nil then
				F.waiting[key][recipe_name] = true
			end
		end

		local ret = resource_util.simplify_recipe({ing = comp, res = ex, time = comp.time, complexity = comp.complexity})
		comp = ret.ing
		comp.time = ret.time / 4
		ret.time = r.time
		comp.complexity = ret.complexity + r.complexity + math.sqrt(r.time)
		ret.complexity = r.complexity
		ex = ret.res
		local ra = ret.ra

		if not trace then
			trace = {recipe_name}
		else
			trace = table.deepcopy(trace)
			if trace[#trace] ~= recipe_name then
				trace[#trace + 1] = recipe_name
			end
		end

		if ready then
			local nn = last_when_loop or recipe_name
			if F.dont_randomize_ingredients and not F.calcs[nn] then
				local p = F.pattern(nn)
				if p then
					F.calcs[nn] = true
					F.calculated[nn] = p
				end
			end
		end

		local dra = 0
		for res, _ in pairs(ex) do
			if F.default[res] then
				dra = dra + 1
			end
		end
		local ndra = ra - dra
		if dra > 0 then
			local dv = 0
			for res, amt in pairs(ex) do
				if F.default[res] then
					dv = dv + amt * F.default[res]
				end
			end
			local max = comp.value * dra / ra
			if dv > max then
				dv = max
			end
			comp = resource_util.multiply(comp, (comp.value - dv) / comp.value)
		end

		if ndra <= 1 then
			for res, amt in pairs(ex) do
				if not F.default[res] then
					if not ready then
						F.update(res, nil, nil, trace)
					elseif r.res[res] then
						local c = table.deepcopy(comp)
						c = resource_util.multiply(c, 1 / amt)
						F.update(res, c, recipe_name, trace)
					end
				end
			end
		else
			local svs = {}
			for res, amt in pairs(ex) do
				if not F.default[res] then
					if F.rawTBN[res] then
						svs[res] = math.min(comp.value / ndra, F.rawTBN[res].value * amt)
						if not F.waiting[res] then
							F.waiting[res] = {[recipe_name] = true}
						elseif F.waiting[res][recipe_name] == nil then
							F.waiting[res][recipe_name] = true
						end
					end
				end
			end
			for res, amt in pairs(ex) do
				if not F.default[res] then
					if not ready then
						F.update(res, nil, nil, trace)
					elseif r.res[res] then
						local c = table.deepcopy(comp)
						local mult = c.value
						for key, value in pairs(svs) do
							if key ~= res then
								mult = mult - value
							end
						end
						c = resource_util.multiply(c, mult / c.value / amt)
						F.update(res, c, recipe_name, trace)
					end
				end
			end
		end
		F.queue.run()
	end

	local function recalculate_loop(recipe, trace)
		local loop = nil
		for _, value in ipairs(trace) do
			if loop then
				loop[#loop + 1] = value
			end
			if value == recipe then
				loop = {}
			end
		end
		loop[#loop + 1] = recipe
		local new = table.deepcopy(F.prepared[recipe])
		for i = #loop - 1, 1, -1 do
			new = resource_util.merge_recipes(new, F.prepared[loop[i]], true)
		end
		if new and new.ia > 0 and new.ra > 0 then
			local name = table.concat(loop, ".")
			F.prepared[name] = new
			F.queue.add(name, nil, recipe)
			return true;
		end
		return false;
	end

	function F.update(item, new_comp, recipe, trace, override_default)
		if new_comp == nil then
			if F.rawTBN[item] then
				return
			end
		else
			if new_comp ~= nil and F.current_tech ~= nil then
				unlock(item, recipe)
			end
			if F.default[item] and not override_default then
				if F.rawTBN[item] and F.rawTBN[item].value * 0.99999 > new_comp.value and F.dont_randomize_ingredients then
					log(util.get_progress() .. "\nAlternative data for resource " .. item .. ": " .. serpent.line(new_comp))
				end
				if not F.rawTBN[item].time then
					F.rawTBN[item].time = new_comp.time
					F.rawTBN[item].complexity = new_comp.complexity
				elseif F.rawTBN[item].time > new_comp.time then
					F.rawTBN[item].time = new_comp.time
					F.rawTBN[item].complexity = new_comp.complexity
				else
					return
				end
			else
				if not F.rawTBN[item] then
					F.rawTBN[item] = new_comp
				elseif F.rawTBN[item].value * 0.99999 > new_comp.value then
					F.rawTBN[item] = new_comp
				else
					return
				end
			end
		end
		if F.waiting[item] and trace then
			for nr, rly in pairs(F.waiting[item]) do
				if rly then
					local cycle = false
					if #trace > 1 then
						for _, r in ipairs(trace) do
							if nr == r then
								cycle = true
								break
							end
						end
					end
					if cycle then
						if #string.gsub(table.concat(trace, "."), "[^%.]+", "") < 40 then
							log(util.get_progress() .. "\nLoop detected: " .. table.concat(trace, " > "))
							-- F.waiting[item][nr] = not recalculate_loop(nr, trace)
						else
							F.waiting[item][nr] = true
						end
					else
						F.queue.add(nr, trace)
					end
				end
			end
		end
	end

	local function prepare(recipe)
		local rec = {ing = {}, res = {}}
		for _, v in pairs(recipe.ing) do
			rec.ing[util.dot(v)] = v.amount
		end
		for _, v in pairs(recipe.res) do
			rec.res[util.dot(v)] = v.amount
		end
		local r = resource_util.simplify_recipe(rec)
		r.complexity = r.ia + r.ra * 2 - 3
		r.time = recipe.time
		r.category = recipe.category
		F.prepared[recipe.name] = r
	end

	local function unlock_tech_defaults()
		local to_unlock = F.tech_defaults[F.current_tech]
		F.tech_defaults[F.current_tech] = nil
		if to_unlock then
			for _, tbl in ipairs(to_unlock) do
				F.update(tbl.item, {value = tbl.value, complexity = util.default_complexity, [tbl.item] = 1}, nil, {}, true)
			end
		end
	end

	local function unlock_item_defaults(allowed)
		for _, tbl in ipairs(F.item_defaults) do
			local a = true
			local u = false
			for _, item in ipairs(tbl.locks) do
				if F.is_allowed(item, allowed) then
					u = u or F.is_allowed(item, {[F.current_tech] = true})
				else
					a = false
					break
				end
			end
			if a and (not F.unlocked_itemsTBN[tbl.item] or u) then
				F.update(tbl.item, {value = tbl.value, complexity = util.default_complexity, [tbl.item] = 1}, nil, {}, true)
			end
		end
		F.queue.run()
	end

	function F.calculate(recipe, technology, allowed, current_rs)
		F.current_tech = technology
		F.current_recipes = current_rs
		unlock_tech_defaults()
		F.calculated = {}
		prepare(recipe)
		recalculate(recipe.name)
		unlock_item_defaults(allowed)
		return F.calculated
	end

	function F.queue.add(recipe_name, trace, last_when_loop)
		if F.queue.a[recipe_name] then
			F.queue.q[F.queue.a[recipe_name]] = nil
		end
		F.queue.s = F.queue.s + 1
		F.queue.q[F.queue.s] = {recipe_name, trace, last_when_loop}
		F.queue.a[recipe_name] = F.queue.s
	end

	function F.queue.run()
		if F.queue.i ~= 0 then
			return
		end
		while F.queue.i < F.queue.s do
			F.queue.i = F.queue.i + 1
			if F.queue.q[F.queue.i] then
				local temp = F.queue.q[F.queue.i]
				recalculate(temp[1], temp[2], temp[3])
				F.queue.q[F.queue.i] = nil
				F.queue.a[temp[1]] = nil
			end
		end
		F.queue.s = 0
		F.queue.i = 0
	end

	function F.has_category(cat, tech)
		return F.unlocked_categories[cat] and F.unlocked_categories[cat][tech]
	end

	function F.is_allowed(item, allowed)
		for pre_tech, _ in pairs(allowed) do
			if F.unlocked_itemsTBN[item] and F.unlocked_itemsTBN[item][pre_tech] then
				return true
			end
		end
		return false
	end

	function F.recalculate_value(r)
		local value = 0
		for key, amt in pairs(r) do
			if amt > 0 and F.rawTBN[key] then
				value = value + F.rawTBN[key].value * amt
			end
		end
		r.value = value
		return r
	end

	function F.get_all()
		return {raw = F.rawTBN, default = F.default, waiting = F.waiting, prepared = F.prepared}
	end

	return F
end

return resourcesModule
