package game

import "core:container/intrusive/list"
import "core:fmt"

recalc_stats :: proc(c: ^Character, lib: ^Item_Library) {
	c.bonused_stats = compute_stats(c, lib, c.equipment)
}

can_equip :: proc(c: ^Character, lib: ^Item_Library, def: ^Item) -> (ok: bool, reason: string) {
	if def.slot == .None || (def.category != .Armor && def.category != .Weapon) {
		return false, "This item cannot be equipped."
	}
	if c.base_stats.str < def.min_str {
		return false, fmt.tprintf("Requires STR %d (you have %d).", def.min_str, c.base_stats.str)
	}
	if def.class_req != "" && def.class_req != c.class {
		return false, fmt.tprintf("Only for class %s.", def.class_req)
	}
	if def.two_handed && c.equipment[.Left_Arm] != 0 {
		return false, "Unequip the left-hand item first (two-handed weapon)."
	}
	if def.slot == .Left_Arm {
		if right := library_find(lib, c.equipment[.Right_Arm]); right != nil && right.two_handed {
			return false, "Cannot use a left-hand item with a two-handed weapon."
		}
	}
	return true, ""
}

compute_stats :: proc(c: ^Character, lib: ^Item_Library, eq: [Character_Slot]int) -> Stats {
	s := c.base_stats
	set_counts: [16]int
	has_heavy := false

	for slot in Character_Slot {
		if slot == .None || eq[slot] == 0 {continue}
		def := library_find(lib, eq[slot])
		if def == nil {continue}
		s.str += def.bonus.str
		s.dex += def.bonus.dex
		s.con += def.bonus.con
		s.wis += def.bonus.wis
		s.cha += def.bonus.cha
		if def.armor_type == .Heavy {has_heavy = true}
		if def.set_id > 0 && def.set_id < len(set_counts) {
			set_counts[def.set_id] += 1
		}
	}

	if has_heavy {s.dex -= 5}

	if set_counts[1] >= 2 {s.con += 5}
	if set_counts[2] >= 2 {s.con += 5}

	return s
}

equip :: proc(c: ^Character, lib: ^Item_Library, node: ^Inventory_Item) -> string {
	def := library_find(lib, node.id)
	if def == nil {return "Unknown item."}
	if ok, reason := can_equip(c, lib, def); !ok {return reason}

	id := node.id
	inv_remove(c, node, 1)

	if old := c.equipment[def.slot]; old != 0 {
		inv_add(c, lib, old, 1)
	}
	c.equipment[def.slot] = id
	recalc_stats(c, lib)
	return "Equipped."
}

unequip :: proc(c: ^Character, lib: ^Item_Library, slot: Character_Slot) -> string {
	id := c.equipment[slot]
	if id == 0 {return "Slot is empty."}
	c.equipment[slot] = 0
	inv_add(c, lib, id, 1)
	recalc_stats(c, lib)
	return "Unequipped."
}

stats_sum :: proc(s: Stats) -> int {
	return s.str + s.dex + s.con + s.wis + s.cha
}

recommend :: proc(
	c: ^Character,
	lib: ^Item_Library,
	slot: Character_Slot,
) -> (
	best: ^Inventory_Item,
	best_score: int,
) {
	current := stats_sum(c.bonused_stats)
	best_score = 0

	it := list.iterator_head(c.inventory, Inventory_Item, "node")
	for inv in list.iterate_next(&it) {
		def := library_find(lib, inv.id)
		if def == nil || def.slot != slot {continue}
		if ok, _ := can_equip(c, lib, def); !ok {continue}

		eq := c.equipment
		eq[slot] = inv.id
		gain := stats_sum(compute_stats(c, lib, eq)) - current

		set_pieces := 0
		if def.set_id != 0 {
			for s in Character_Slot {
				if s == slot || c.equipment[s] == 0 {continue}
				other := library_find(lib, c.equipment[s])
				if other != nil && other.set_id == def.set_id {set_pieces += 1}
			}
		}

		class_match := 0
		if def.class_req != "" && def.class_req == c.class {class_match = 1}

		score := gain * 2 + set_pieces * 3 + class_match * 3
		if score > best_score {
			best_score = score
			best = inv
		}
	}
	return
}
