package game

Party :: struct {
	characters: csll(Character),
	active:     ^csll_Node(Character),
}

party_add :: proc(p: ^Party, c: ^Character) -> ^Character {
	n := csll_push_back(&p.characters, c)
	if p.active == nil {p.active = n}
	return &n.value
}

party_active :: proc(p: ^Party) -> ^csll_Node(Character) {
	if p.active == nil {return nil}
	return p.active
}

party_next :: proc(p: ^Party) {
	if (p.active != nil) {
		p.active = p.active.next
	}
}
