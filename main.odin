package game

import "core:container/intrusive/list"
import "core:fmt"
import "core:strings"
import rl "vendor:raylib"

BG :: rl.Color{30, 20, 28, 255}
DIM :: rl.Color{160, 137, 155, 255}
HIGHLIGHT :: rl.Color{160, 137, 155, 255}
SELECTED :: DIM
GREEN :: rl.Color{118, 168, 108, 255}

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
	set_msg("Hello:)")

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
					set_msg(fmt.tprintf("%s was added to %s's inventory.", it.name, ch.name))

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
				if rl.IsKeyPressed(k) && rl.IsKeyDown(.LEFT_SHIFT) {
					set_msg(unequip(ch, &lib, Character_Slot(i + 1)))
					changed = true
				} else if rl.IsKeyDown(k) {
					rec, score := recommend(ch, &lib, Character_Slot(i + 1))
					if rec != nil {
						rd := library_find(&lib, rec.id)
						draw(
							fmt.tprintf(
								"Recommended for %v: \n%s (score %d)",
								Character_Slot(i + 1),
								rd.name,
								score,
							),
							160,
							170,
							GREEN,
							16,
						)
						draw(bonus_text(rd.bonus), 160, 170 + 40, GREEN, 15); break
					} else {
						draw(
							fmt.tprintf("No improvement available for %v.", Character_Slot(i + 1)),
							160,
							170,
							DIM,
							16,
						)
						break
					}
				}
			}
		}

		if changed {save_characters(&party, "characters.json")}

		rl.BeginDrawing()
		rl.ClearBackground(BG)

		rl.DrawRectangle(25, 585, 210, 130, rl.BLACK)
		draw("Controls:", 30, 590, HIGHLIGHT, 15)
		draw("[TAB] - next character", 30, 605, HIGHLIGHT, 15)
		draw("[L]   - go to item", 30, 620, HIGHLIGHT, 15)
		draw("[I]   - go to inventory", 30, 635, HIGHLIGHT, 15)
		draw("[1-6]+Lshft-unequip armour]", 30, 650, HIGHLIGHT, 15)
		draw("[U] 	- use item", 30, 665, HIGHLIGHT, 15)
		draw("[ENTER] - take from library", 30, 680, HIGHLIGHT, 15)
		draw("[ESC] - save & exit", 30, 695, HIGHLIGHT, 15)

		tex, has := textures[ch.sprite]
		if !has {tex = fallback}
		{
			SPRITE_SIZE_x :: 160
			SPRITE_SIZE_y :: 250

			src := rl.Rectangle{0, 0, f32(tex.width), f32(tex.height)}
			dst := rl.Rectangle{5, 10, SPRITE_SIZE_x, SPRITE_SIZE_y}
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

		rl.DrawRectangle(20, 265, 130, 30, rl.BLACK)
		draw(fmt.tprintf("HP %d/%d", ch.hp, ch.max_hp), 25, 270, GREEN, 22)

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
				HIGHLIGHT,
				16,
			)
		}

		current := party.characters.tail.next
		cha_name_y: i32 = 0
		for {
			c := current.value

			color := DIM
			if current == party.active {
				color = rl.WHITE
			}
			draw(fmt.tprintf("%s", c.name), 25, 300 + cha_name_y, color, 25)

			if party.characters.tail == current {break}
			current = current.next
			cha_name_y += 22
		}

		selected_def: ^Item

		item_default_color := DIM

		rl.DrawRectangle(500, 20, 250, 680, rl.BLACK)
		draw("Inventory:", 540, 40, HIGHLIGHT if !in_library else DIM, 30)

		inv_y: i32 = 90
		if ch.inventory.head == nil {
			draw("(empty)", 510, inv_y, DIM)
		}
		i := 0
		inv_it := list.iterator_head(ch.inventory, Inventory_Item, "node")
		for inv in list.iterate_next(&inv_it) {
			d := library_find(&lib, inv.id)

			color := item_default_color
			if d != nil && d.slot != .None {
				if ok, _ := can_equip(ch, &lib, d); ok {
					color = GREEN
				} else {
					color = DIM
				}
			}
			if !in_library && i == sel {
				rl.DrawRectangle(505, inv_y - 2, 240, 24, SELECTED)
				selected_def = d
				color = rl.WHITE
			}
			name := d.name if d != nil else "???"
			draw(fmt.tprintf("%dx %s", inv.amount, name), 510, inv_y, color)
			inv_y += 25
			i += 1
		}

		rl.DrawRectangle(765, 20, 250, 680, rl.BLACK)
		draw("Item library:", 790, 40, HIGHLIGHT if in_library else DIM, 30)

		lib_x: i32 = 790
		lib_y: i32 = 90
		j := 0
		lib_it := list.iterator_head(lib.items, Item, "node")
		for item in list.iterate_next(&lib_it) {
			color := item_default_color
			if in_library && j == lib_sel {
				rl.DrawRectangle(lib_x - 20, lib_y - 2, 240, 24, SELECTED)
				selected_def = item
				color = rl.WHITE
			}
			draw(fmt.tprintf("%s", item.name), 790 - 10, lib_y, color)
			lib_y += 25
			j += 1
		}

		item_info_x: i32 = 25
		item_info_y: i32 = 450
		draw("Selected item:", item_info_x, item_info_y - 25, HIGHLIGHT, 20)
		if selected_def != nil {
			d := selected_def
			draw(
				fmt.tprintf("%s [%v]", d.name, d.category),
				item_info_x,
				item_info_y,
				rl.WHITE,
				16,
			)
			draw(fmt.tprintf("%s", d.description), item_info_x, item_info_y + 20, DIM, 16)
			// draw(bonus_text(d.bonus), item_info_x, item_info_y + 60, rl.WHITE, 16)

			if d.slot != .None {
				draw(
					fmt.tprintf(
						"Slot: %v  Min STR: %d  Armor: %v",
						d.slot,
						d.min_str,
						d.armor_type,
					),
					item_info_x,
					item_info_y + 40,
					DIM,
					16,
				)
				if ok, reason := can_equip(ch, &lib, d); !ok {
					draw(
						fmt.tprintf("Cannot equip: \n%s", reason),
						item_info_x,
						item_info_y + 60,
						rl.RED,
						16,
					)
				}
			}
		}
		draw(msg, 25, 565, rl.SKYBLUE, 16)

		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
	save_characters(&party, "characters.json")
}
