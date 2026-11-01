package game

import "core:container/intrusive/list"

Character :: struct {
	using node:    csll_Node(^Character),
	id:            int,
	name:          string,
	sprite:        string,
	class:         string,
	level:         int,
	description:   string,
	hp, max_hp:    int,
	base_stats:    Stats,
	bonused_stats: Stats,
	equipment:     [Character_Slot]int,
	inventory:     list.List,
}
Stats :: struct {
	str, dex, con, wis, cha: int,
}

Character_Slot :: enum {
	None,
	Head,
	Torso,
	Right_Arm,
	Left_Arm,
	Right_Leg,
	Left_Leg,
}

Armor_Type :: enum {
	None,
	Light,
	Medium,
	Heavy,
}

Item :: struct {
	node:        list.Node,
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

Inventory_Item :: struct {
	node:   list.Node,
	id:     int,
	amount: int,
}

Item_Category :: enum {
	Potion,
	Food,
	Weapon,
	Armor,
	Material,
}

Item_Library :: struct {
	items: list.List,
}
