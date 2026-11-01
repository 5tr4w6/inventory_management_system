package game

csll_Node :: struct($T: typeid) {
	next:  ^csll_Node(T),
	value: T,
}

csll :: struct($T: typeid) {
	tail: ^csll_Node(T),
}

csll_push_back :: proc(l: ^csll($T), c: ^T) -> ^csll_Node(T) {
	n := new(csll_Node(T))
	n.value = c^

	if l.tail == nil {
		n.next = n

		l.tail = n
	} else {
		n.next = l.tail.next

		l.tail.next = n
		l.tail = n
	}
	return n
}
