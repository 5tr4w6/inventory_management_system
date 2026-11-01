package game

import "core:container/intrusive/list"

inv_find :: proc(c: ^Character, id: int) -> ^Inventory_Item {
	it := list.iterator_head(c.inventory, Inventory_Item, "node")
	for inv in list.iterate_next(&it) {
		if inv.id == id {return inv}
	}
	return nil
}

inv_add :: proc(c: ^Character, lib: ^Item_Library, id, amount: int) -> bool {
	def := library_find(lib, id)
	if def == nil || amount <= 0 {return false}

	if def.stackable {
		if existing := inv_find(c, id); existing != nil {
			existing.amount += amount
			return true
		}
		n := new(Inventory_Item)
		n.id = id
		n.amount = amount
		list.push_back(&c.inventory, &n.node)
		return true
	}

	for _ in 0 ..< amount {
		n := new(Inventory_Item)
		n.id = id
		n.amount = 1
		list.push_back(&c.inventory, &n.node)
	}
	return true
}

inv_remove :: proc(c: ^Character, node: ^Inventory_Item, amount: int = 1) -> bool {
	if node == nil || amount <= 0 || amount > node.amount {return false}
	node.amount -= amount
	if node.amount == 0 {
		list.remove(&c.inventory, &node.node)
		free(node)
	}
	return true
}

inv_use :: proc(c: ^Character, lib: ^Item_Library, node: ^Inventory_Item) -> string {
	def := library_find(lib, node.id)
	if def == nil {return "Unknown item."}

	#partial switch def.category {
	case .Potion, .Food:
		c.hp = min(c.hp + def.heal, c.max_hp)
		inv_remove(c, node, 1)
		return "Used."
	case:
		return "This item cannot be used."
	}
}

inv_drop :: proc(c: ^Character, node: ^Inventory_Item, amount: int = 1) -> string {
	if !inv_remove(c, node, amount) {return "Invalid amount."}
	return "Dropped."
}

inv_transfer :: proc(
	from, to: ^Character,
	lib: ^Item_Library,
	node: ^Inventory_Item,
	amount: int = 1,
) -> string {
	if from == to {return "Cannot transfer to the same character."}
	if node == nil || amount <= 0 || amount > node.amount {return "Invalid amount."}
	id := node.id
	inv_remove(from, node, amount)
	inv_add(to, lib, id, amount)
	return "Transferred."
}
inv_count :: proc(c: ^Character) -> int {
	n := 0
	it := list.iterator_head(c.inventory, Inventory_Item, "node")
	for _ in list.iterate_next(&it) {n += 1}
	return n
}

inv_at :: proc(c: ^Character, index: int) -> ^Inventory_Item {
	i := 0
	it := list.iterator_head(c.inventory, Inventory_Item, "node")
	for inv in list.iterate_next(&it) {
		if i == index {return inv}
		i += 1
	}
	return nil
}
