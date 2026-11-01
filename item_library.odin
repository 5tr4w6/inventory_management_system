package game

import "core:container/intrusive/list"

library_add :: proc(lib: ^Item_Library, it: ^Item) {
	list.push_back(&lib.items, &it.node)
}

library_find :: proc(lib: ^Item_Library, id: int) -> ^Item {
	it := list.iterator_head(lib.items, Item, "node")
	for item in list.iterate_next(&it) {
		if item.id == id {return item}
	}
	return nil
}
lib_count :: proc(lib: ^Item_Library) -> int {
	n := 0
	it := list.iterator_head(lib.items, Item, "node")
	for _ in list.iterate_next(&it) {n += 1}
	return n
}

lib_at :: proc(lib: ^Item_Library, index: int) -> ^Item {
	i := 0
	it := list.iterator_head(lib.items, Item, "node")
	for item in list.iterate_next(&it) {
		if i == index {return item}
		i += 1
	}
	return nil
}
