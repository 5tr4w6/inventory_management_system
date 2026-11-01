package game

import "core:container/intrusive/list"
import "core:encoding/json"
import "core:fmt"
import "core:os"

Item_DTO :: struct {
	id:          int,
	name:        string,
	description: string,
	category:    Item_Category,
	slot:        Character_Slot,
	armor_type:  Armor_Type,
	two_handed:  bool,
	min_str:     int,
	stackable:   bool,
	set_id:      int,
	bonus:       Stats,
	heal:        int,
	class_req:   string,
}

Items_File :: struct {
	items: []Item_DTO,
}

Inventory_DTO :: struct {
	id:     int,
	amount: int,
}

Equipment_DTO :: struct {
	head, torso, right_arm, left_arm, right_leg, left_leg: int,
}

Character_DTO :: struct {
	id:          int,
	name:        string,
	sprite:      string,
	class:       string,
	level:       int,
	description: string,
	hp, max_hp:  int,
	stats:       Stats,
	equipment:   Equipment_DTO,
	inventory:   []Inventory_DTO,
}

Characters_File :: struct {
	characters: []Character_DTO,
}

load_items :: proc(lib: ^Item_Library, path: string) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Failed to read %s: %v", path, read_err)
		return false
	}
	defer delete(data)

	file: Items_File
	if err := json.unmarshal(data, &file); err != nil {
		fmt.eprintfln("Failed to parse %s: %v", path, err)
		return false
	}
	if len(file.items) == 0 {
		fmt.eprintfln("%s has no \"items\" array (or it is empty).", path)
		return false
	}

	for dto in file.items {
		it := new(Item)
		it.id = dto.id
		it.name = dto.name
		it.description = dto.description
		it.category = dto.category
		it.slot = dto.slot
		it.armor_type = dto.armor_type
		it.two_handed = dto.two_handed
		it.min_str = dto.min_str
		it.stackable = dto.stackable
		it.set_id = dto.set_id
		it.bonus = dto.bonus
		it.heal = dto.heal
		it.class_req = dto.class_req
		library_add(lib, it)
	}
	delete(file.items)
	return true
}

load_characters :: proc(p: ^Party, lib: ^Item_Library, path: string) -> bool {
	data, read_err := os.read_entire_file(path, context.allocator)
	if read_err != nil {
		fmt.eprintfln("Failed to read %s: %v", path, read_err)
		return false
	}
	defer delete(data)

	file: Characters_File
	if err := json.unmarshal(data, &file); err != nil {
		fmt.eprintfln("Failed to parse %s: %v", path, err)
		return false
	}
	if len(file.characters) == 0 {
		fmt.eprintfln("%s has no \"characters\" array (or it is empty).", path)
		return false
	}

	for dto in file.characters {
		c := new(Character)
		c.id = dto.id
		c.name = dto.name
		c.sprite = dto.sprite
		c.class = dto.class
		c.level = dto.level
		c.description = dto.description
		c.hp = dto.hp
		c.max_hp = dto.max_hp
		c.base_stats = dto.stats
		c.bonused_stats = dto.stats

		c.equipment[.Head] = dto.equipment.head
		c.equipment[.Torso] = dto.equipment.torso
		c.equipment[.Right_Arm] = dto.equipment.right_arm
		c.equipment[.Left_Arm] = dto.equipment.left_arm
		c.equipment[.Right_Leg] = dto.equipment.right_leg
		c.equipment[.Left_Leg] = dto.equipment.left_leg

		for inv in dto.inventory {
			n := new(Inventory_Item)
			n.id = inv.id
			n.amount = inv.amount
			list.push_back(&c.inventory, &n.node)
		}
		delete(dto.inventory)

		saved := party_add(p, c)
		free(c)
		recalc_stats(saved, lib)
	}
	delete(file.characters)
	return true
}
save_characters :: proc(p: ^Party, path: string) -> bool {
	dtos := make([dynamic]Character_DTO, context.temp_allocator)

	if p.characters.tail != nil {
		current := p.characters.tail.next
		for {
			c := current.value

			invs := make([dynamic]Inventory_DTO, context.temp_allocator)
			inv_it := list.iterator_head(c.inventory, Inventory_Item, "node")
			for inv in list.iterate_next(&inv_it) {
				append(&invs, Inventory_DTO{id = inv.id, amount = inv.amount})
			}

			append(
				&dtos,
				Character_DTO {
					id = c.id,
					name = c.name,
					sprite = c.sprite,
					class = c.class,
					level = c.level,
					description = c.description,
					hp = c.hp,
					max_hp = c.max_hp,
					stats = c.base_stats,
					equipment = Equipment_DTO {
						head = c.equipment[.Head],
						torso = c.equipment[.Torso],
						right_arm = c.equipment[.Right_Arm],
						left_arm = c.equipment[.Left_Arm],
						right_leg = c.equipment[.Right_Leg],
						left_leg = c.equipment[.Left_Leg],
					},
					inventory = invs[:],
				},
			)

			if current == p.characters.tail {break}
			current = current.next
		}
	}

	data, merr := json.marshal(
		Characters_File{characters = dtos[:]},
		{pretty = true},
		context.temp_allocator,
	)
	if merr != nil {
		fmt.eprintfln("Failed to serialize: %v", merr)
		return false
	}
	if werr := os.write_entire_file(path, data); werr != nil {
		fmt.eprintfln("Failed to write %s: %v", path, werr)
		return false
	}
	return true
}
