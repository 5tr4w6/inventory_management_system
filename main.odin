package game

import "core:container/intrusive/list"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

BG :: rl.Color{30, 20, 28, 255}
DIM :: rl.Color{75, 55, 71, 255}
HIGHLIGHT :: rl.Color{160, 137, 155, 255}
SELECTED :: rl.Color{70, 45, 80, 255}

msg: string

set_msg :: proc(s: string) {
	delete(msg)
	msg = strings.clone(s)
}

draw :: proc(s: string, x, y: i32, color := rl.WHITE, size: i32 = 20) {
	rl.DrawText(fmt.ctprintf("%s", s), x, y, size, color)
}

bonus_text :: proc(b: Stats) -> string {
	return fmt.tprintf(
		"STR %+d  DEX %+d  CON %+d  WIS %+d  CHA %+d",
		b.str,
		b.dex,
		b.con,
		b.wis,
		b.cha,
	)
}

main :: proc() {
	lib: Item_Library
	party: Party

	if !load_items(&lib, "items.json") {return}
	if !load_characters(&party, &lib, "characters.json") {return}

	rl.InitWindow(1045, 720, "Inventory Management System")
	defer rl.CloseWindow()
	rl.SetTargetFPS(60)

	textures: map[string]rl.Texture2D
	defer {
		for _, t in textures {rl.UnloadTexture(t)}
		delete(textures)
	}
	fallback := rl.LoadTexture("player.png")

	{
		current := party.characters.tail.next
		for {
			c := current.value
			if c.sprite != "" && !(c.sprite in textures) {
				path := fmt.ctprintf("%s", c.sprite)
				if rl.FileExists(path) {
					textures[c.sprite] = rl.LoadTexture(path)
				}
			}

			if party.characters.tail == current {break}
			current = current.next
		}
	}

	sel := 0
	lib_sel := 0
	in_library := false
	slot_keys := [?]rl.KeyboardKey{.ONE, .TWO, .THREE, .FOUR, .FIVE, .SIX}
	set_msg("Hello:)")

	for !rl.WindowShouldClose() {
		changed := false

		if rl.IsKeyPressed(.TAB) {
			party_next(&party)
			sel = 0
		}
		if rl.IsKeyPressed(.L) {in_library = true}
		if rl.IsKeyPressed(.I) {in_library = false}

		active := party_active(&party)
		ch := &active.value
		next_ch := &active.next.value

		if in_library {
			count := lib_count(&lib)
			if rl.IsKeyPressed(.DOWN) && lib_sel < count - 1 {lib_sel += 1}
			if rl.IsKeyPressed(.UP) && lib_sel > 0 {lib_sel -= 1}
			if rl.IsKeyPressed(.ENTER) {
				if it := lib_at(&lib, lib_sel); it != nil {
					inv_add(ch, &lib, it.id, 1)
					set_msg(fmt.tprintf("%s was added to your inventory.", it.name))
					changed = true
				}
			}
		} else {
			count := inv_count(ch)
			if rl.IsKeyPressed(.DOWN) && sel < count - 1 {sel += 1}
			if rl.IsKeyPressed(.UP) && sel > 0 {sel -= 1}
			sel = clamp(sel, 0, max(count - 1, 0))

			if node := inv_at(ch, sel); node != nil {
				if rl.IsKeyPressed(.E) {
					set_msg(equip(ch, &lib, node))
					changed = true
				} else if rl.IsKeyPressed(.U) {
					set_msg(inv_use(ch, &lib, node))
					changed = true
				} else if rl.IsKeyPressed(.D) {
					set_msg(inv_drop(ch, node, 1))
					changed = true
				} else if rl.IsKeyPressed(.T) {
					set_msg(inv_transfer(ch, next_ch, &lib, node, 1))
					changed = true
				}
			}

			for k, i in slot_keys {
				if rl.IsKeyPressed(k) {
					set_msg(unequip(ch, &lib, Character_Slot(i + 1)))
					changed = true
				}
			}
		}

		if changed {save_characters(&party, "characters.json")}

		rl.BeginDrawing()
		rl.ClearBackground(BG)

		rl.DrawRectangle(5, 495, 305, 185, rl.BLACK)

		draw("Controls:", 10, 500, DIM, 15)
		draw("[TAB] - next character", 10, 515, DIM, 15)
		draw("[L]   - go to chest", 10, 530, DIM, 15)
		draw("[I]   - go to inventory", 10, 545, DIM, 15)
		draw("[1-6] - unequip armour]", 10, 560, DIM, 15)
		draw("[U] 	- use item", 10, 575, DIM, 15)
		draw("[ENTER] - take from library", 10, 590, DIM, 15)
		draw("[ESC] - save & exit", 10, 605, DIM, 15)

		tex, has := textures[ch.sprite]
		if !has {tex = fallback}
		{SPRITE_SIZE :: 128

			src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dst := rl.Rectangle{10, 10, SPRITE_SIZE, SPRITE_SIZE}
			rl.DrawTexturePro(tex, src, dst, {0, 0}, 0, rl.WHITE)
		}

		draw(fmt.tprintf("%s  Lv %d", ch.class, ch.level), 160, 10, HIGHLIGHT, 22)
		draw(fmt.tprintf("%s", ch.description), 160, 30, DIM, 18)

		s := ch.bonused_stats
		stat_x: i32 = 170

		rl.DrawRectangle(160, 50, 95, 115, rl.BLACK)
		draw(fmt.tprintf("STR %d", s.str), stat_x, 60)
		draw(fmt.tprintf("DEX %d", s.dex), stat_x, 80)
		draw(fmt.tprintf("CON %d", s.con), stat_x, 100)
		draw(fmt.tprintf("WIS %d", s.wis), stat_x, 120)
		draw(fmt.tprintf("CHA %d", s.cha), stat_x, 140)

		rl.DrawRectangle(10, 145, 130, 30, rl.BLACK)
		draw(fmt.tprintf("HP %d/%d", ch.hp, ch.max_hp), 15, 150, rl.GREEN, 22)

		rl.DrawRectangle(260, 50, 225, 115, rl.BLACK)
		for slot in Character_Slot {
			if slot == .None {continue}
			name := "-"
			if id := ch.equipment[slot]; id != 0 {
				if d := library_find(&lib, id); d != nil {name = d.name}
			}
			draw(
				fmt.tprintf("%d. %v: %s", int(slot), slot, name),
				265,
				55 + (i32(slot) - 1) * 18,
				rl.WHITE,
				16,
			)
		}

		current := party.characters.tail.next
		y: i32 = 0
		for {
			c := current.value

			color := DIM
			if current == party.active {
				color = HIGHLIGHT
			}
			draw(fmt.tprintf("%s", c.name), 15, 200 + y, color, 25)

			if party.characters.tail == current {break}
			current = current.next
			y += 22
		}

		selected_def: ^Item

		rl.DrawRectangle(500, 20, 250, 680, rl.BLACK)
		draw("Inventory:", 530, 40, HIGHLIGHT if !in_library else DIM, 30)

		inv_y: i32 = 90
		if ch.inventory.head == nil {
			draw("(empty)", 510, inv_y, DIM)
		}
		i := 0
		inv_it := list.iterator_head(ch.inventory, Inventory_Item, "node")
		for inv in list.iterate_next(&inv_it) {
			d := library_find(&lib, inv.id)

			color := rl.WHITE
			if d != nil && d.slot != .None {
				if ok, _ := can_equip(ch, &lib, d); ok {
					color = rl.GREEN
				} else {
					color = rl.GRAY
				}
			}
			if !in_library && i == sel {
				rl.DrawRectangle(505, inv_y - 2, 240, 24, SELECTED)
				selected_def = d
				color = rl.YELLOW
			}
			name := d.name if d != nil else "???"
			draw(fmt.tprintf("%dx %s", inv.amount, name), 510, inv_y, color)
			inv_y += 25
			i += 1
		}

		rl.DrawRectangle(780, 20, 250, 680, rl.BLACK)
		draw("Item library:", 810, 40, HIGHLIGHT if in_library else DIM, 30)

		lib_y: i32 = 90
		j := 0
		lib_it := list.iterator_head(lib.items, Item, "node")
		for item in list.iterate_next(&lib_it) {
			color := rl.WHITE
			if in_library && j == lib_sel {
				rl.DrawRectangle(785, lib_y - 2, 240, 24, SELECTED)
				selected_def = item
				color = rl.YELLOW
			}
			draw(fmt.tprintf("%s", item.name), 790, lib_y, color)
			lib_y += 25
			j += 1
		}

		draw("Selected item:", 160, 200, HIGHLIGHT, 20)
		if selected_def != nil {
			d := selected_def
			draw(fmt.tprintf("%s [%v]", d.name, d.category), 160, 220, rl.WHITE, 16)
			draw(fmt.tprintf("%s", d.description), 160, 240, DIM, 16)
			draw(bonus_text(d.bonus), 160, 260, rl.WHITE, 16)
			if d.slot != .None {
				draw(
					fmt.tprintf(
						"Slot: %v  Min STR: %d  Armor: %v",
						d.slot,
						d.min_str,
						d.armor_type,
					),
					160,
					280,
					rl.WHITE,
					16,
				)
				if ok, reason := can_equip(ch, &lib, d); !ok {
					draw(fmt.tprintf("Cannot equip: %s", reason), 160, 340, rl.RED, 16)
				}

				rec, score := recommend(ch, &lib, d.slot)
				if rec != nil {
					rd := library_find(&lib, rec.id)
					draw(
						fmt.tprintf("Recommended for %v: %s (score %d)", d.slot, rd.name, score),
						160,
						300,
						rl.GREEN,
						12,
					)
					draw(bonus_text(rd.bonus), 160, 320, rl.GREEN, 12)
				} else {
					draw(fmt.tprintf("No improvement available for %v.", d.slot), 15, 320, DIM, 12)
				}
			}
		}

		draw(msg, 15, 690, rl.SKYBLUE, 20)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}

	save_characters(&party, "characters.json")
}
