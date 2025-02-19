pchest={}

local tubelibEnabled = minetest.global_exists("tubelib")

minetest.register_craft({
	output = "hook:pchest",
	recipe = {
		{"default:stick","default:stick","default:stick"},
		{"default:stick","default:chest", "default:diamondblock"},
		{"default:stick","default:stick","default:stick"},
	}
})

pchest.infotext = function(player_name, description)
	return description..", owned by " .. player_name
end

pchest.setpchest=function(pos,user,item)
	local meta = minetest.get_meta(pos)
	local player_name = user:get_player_name()
	meta:set_string("owner", player_name)
	meta:set_int("state", 0)
	meta:get_inventory():set_size("main", 32)
	meta:get_inventory():set_size("trans", 1)

	local description = "Portable locked chest"
	if item.meta.description then
		description = item.meta.description
	end
	meta:set_string("description", description)

	local tubelib = "true"
	if item.meta.tubelib then
		tubelib = item.meta.tubelib
	end
	meta:set_string("tubelib", tubelib)

	pchest.setformspec(meta)
	meta:set_string("infotext", pchest.infotext(player_name, description))
end

pchest.setformspec = function (meta)
	local fieldspec = ""
	if tubelibEnabled then
		fieldspec = "checkbox[4,0;toggle_tubelib;Enable tubelib interaction;"..meta:get_string("tubelib").."]"
	end
	meta:set_string("formspec",
		"size[8,9]" ..
		fieldspec..
		"field[0.25,0.5;4,0.5;"..
		"description_textbox;Item description (press enter to save):;".. meta:get_string("description") .."]"..
		"list[context;main;0,1;8,4;]" ..
		"list[context;trans;0,0;0,0;]" ..
		"list[current_player;main;0,5.3;8,4;]" ..
		"listring[current_player;main]" ..
		"listring[current_name;main]")
end

minetest.register_tool("hook:pchest", {
	description = "Portable locked chest",
	inventory_image = "hook_extras_chest3.png",
	on_place = function(itemstack, user, pointed_thing)
		if minetest.is_protected(pointed_thing.above,user:get_player_name()) or hook.slingshot_def(pointed_thing.above,"walkable") then
			return itemstack
		end
		local p=minetest.dir_to_facedir(user:get_look_dir())
		local item=itemstack:to_table()
		minetest.set_node(pointed_thing.above, {name = "hook:pchest_node",param1="",param2=p})
		pchest.setpchest(pointed_thing.above,user,item)

		minetest.sound_play("default_place_node_hard", {pos=pointed_thing.above, gain = 1.0, max_hear_distance = 5})

		if not (item.meta or item.metadata) then
			itemstack:take_item()
			return itemstack
		end
		if item.meta.items then
			local its = minetest.deserialize(item.meta.items or "") or {}
			local items = {}
			for i,it in pairs(its) do
				table.insert(items,ItemStack(it))
			end

			minetest.get_meta(pointed_thing.above):get_inventory():set_list("main",items)
		elseif item.metadata ~= "" then
			local meta=minetest.deserialize(item["metadata"])
			local s=meta.stuff
			local its=meta.stuff.split(meta.stuff,",",",")
			local nmeta=minetest.get_meta(pointed_thing.above)
			for i,it in pairs(its) do
				if its~="" then
					nmeta:get_inventory():set_stack("main",i, ItemStack(it))
				end
			end
		end
		itemstack:take_item()
		return itemstack
	end
})

minetest.register_node("hook:pchest_node", {
	description = "Portable locked chest",
	tiles = {"hook_extras_chest2.png","hook_extras_chest2.png","hook_extras_chest1.png","hook_extras_chest1.png","hook_extras_chest1.png","hook_extras_chest3.png"},
	groups = {dig_immediate = 2, not_in_creative_inventory=1,tubedevice = 1, tubedevice_receiver = 1},
	drop="hook:pchest",
	paramtype2 = "facedir",
	tube = {insert_object = function(pos, node, stack, direction)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		local added = inv:add_item("main", stack)
		return added
	end,
	can_insert = function(pos, node, stack, direction)
		local meta = minetest.get_meta(pos)
		local inv = meta:get_inventory()
		return inv:room_for_item("main", stack)
	end,
	input_inventory = "main",
	connect_sides = {left = 1, right = 1, front = 1, back = 1, top = 1, bottom = 1}},
	allow_metadata_inventory_put = function(pos, listname, index, stack, player)
		local m = minetest.get_meta(pos)
		local owner = m:get_string("owner")
		local inv = m:get_inventory()
		local name = player:get_player_name()
		if owner == name or owner == "" then
			if stack:get_name() == "hook:pchest" then
				minetest.chat_send_player(name, "Not allowed to put in it")
				return 0
			elseif not inv:room_for_item("main",stack) then
				minetest.chat_send_player(name, "Full")
				return 0
			end
			return stack:get_count()
		end
		return 0
	end,
	allow_metadata_inventory_take = function(pos, listname, index, stack, player)
		local owner = minetest.get_meta(pos):get_string("owner")
		if owner==player:get_player_name() or owner=="" then
			return stack:get_count()
		end
		return 0
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		local owner = minetest.get_meta(pos):get_string("owner")
		if owner==player:get_player_name() or owner=="" then
			return count
		end
		return 0
	end,
	can_dig = function(pos, player)
		local m = minetest.get_meta(pos)
		return m:get_string("owner") == "" and m:get_inventory():is_empty("main")
	end,
	on_receive_fields = function(pos, formname, fields, sender)
		local name = sender:get_player_name()
		local meta = minetest.get_meta(pos)
		if name ~= meta:get_string("owner") then
			return false
		end
		if fields.description_textbox then
			meta:set_string("description", fields.description_textbox)
			meta:set_string("infotext", pchest.infotext(name, fields.description_textbox))
		end
		if fields.toggle_tubelib then
			meta:set_string("tubelib", fields.toggle_tubelib)
		end
		pchest.setformspec(meta)
	end,
	on_punch = function(pos, node, player, pointed_thing)
		local meta=minetest.get_meta(pos)
		local name = player:get_player_name()
		local pinv = player:get_inventory()
		if minetest.is_protected(pos,name) or meta:get_string("owner") ~= name or not pinv:room_for_item("main",ItemStack("hook:pchest")) then
			return false
		end
		local inv=meta:get_inventory()
		local items = {}
		for i,v in pairs(inv:get_list("main")) do
			table.insert(items,v:to_table())
		end
		local item = ItemStack("hook:pchest"):to_table()
		item.meta={items=minetest.serialize(items),tubelib=meta:get_string('tubelib'),description=meta:get_string('description')}
		pinv:add_item("main", ItemStack(item))
		minetest.set_node(pos, {name = "air"})
		minetest.sound_play("default_dig_dig_immediate", {pos=pos, gain = 1.0, max_hear_distance = 5,})
	end,
	on_blast = function () end
})

if tubelibEnabled then
	tubelib.register_node("hook:pchest_node", {}, {
		on_pull_item = function(pos, side, player_name)
			local meta = minetest.get_meta(pos)
			if meta:get_string('tubelib') ~= 'true' then
				return nil
			end
			local inv = meta:get_inventory()
			for _, stack in pairs(inv:get_list("main")) do
				if not stack:is_empty() then
					return inv:remove_item("main", stack:get_name())
				end
			end
			return nil
		end,
		on_push_item = function(pos, side, item, player_name)
			local meta = minetest.get_meta(pos)
			if meta:get_string('tubelib') ~= 'true' then
				return false
			end
			local inv = meta:get_inventory()
			if inv:room_for_item("main", item) then
				inv:add_item("main", item)
				return true
			end
			return false
		end,
		on_unpull_item = function(pos, side, item, player_name)
			local inv = minetest.get_meta(pos):get_inventory()
			if inv:room_for_item("main", item) then
				inv:add_item("main", item)
				return true
			end
			return false
		end,
	})
end

minetest.register_lbm({
	name = "hook:pchest_node__description_infotext",
	nodenames = {"hook:pchest_node"},
	action = function(pos, node)
		local meta = minetest.get_meta(pos)
		local player_name = meta:get_string("owner")
		local description = meta:get_string("description")
		meta:set_string("infotext", pchest.infotext(player_name, description))
	end,
})
