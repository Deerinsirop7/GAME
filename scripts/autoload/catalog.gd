extends Node
## Все игровые данные: палитры, питомцы, жильё, предметы.
## Хочешь добавить предмет — допиши словарь в ITEMS и нарисуй спрайт в tools/gen_sprites.py.

const HAIR_STYLES := ["short", "long", "ponytail", "bob", "buns", "spiky"]
const HAIR_STYLE_NAMES := ["Короткая", "Длинная", "Хвостик", "Каре", "Пучки", "Ёжик"]
const GENDERS := ["boy", "girl"]
const GENDER_NAMES := ["Мальчик", "Девочка"]

var HAIR_COLORS: Array[Color] = [
	Color("6b4630"), Color("37323d"), Color("ffe08a"), Color("ff7a4a"),
	Color("d9a577"), Color("ff8cc6"), Color("7ab6ff"), Color("f4f0ea"),
]
var EYE_COLORS: Array[Color] = [
	Color("3f7fd6"), Color("4f9a45"), Color("7a4a2a"), Color("8a5bc9"), Color("3a3a48"), Color("d08a2a"),
]
var SKIN_TONES: Array[Color] = [
	Color("ffe4cf"), Color("f7cfab"), Color("e2ab7f"), Color("c08659"), Color("8f5b3b"), Color("5f3b27"),
]

const PET_ORDER := ["dog", "cat", "parrot", "fish"]
var PETS := {
	"dog": {"name": "Собака", "default": "Бобик", "sound": "pet_dog",
		"decay": {"hunger": 1.1, "joy": 1.2, "energy": 1.0, "clean": 1.1}, "likes_water": true},
	"cat": {"name": "Кот", "default": "Мурзик", "sound": "pet_cat",
		"decay": {"hunger": 1.0, "joy": 0.9, "energy": 0.9, "clean": 0.7}, "likes_water": false},
	"parrot": {"name": "Попугай", "default": "Кеша", "sound": "pet_parrot",
		"decay": {"hunger": 1.0, "joy": 1.2, "energy": 0.9, "clean": 0.8}, "likes_water": true},
	"fish": {"name": "Рыбка", "default": "Немо", "sound": "pet_fish",
		"decay": {"hunger": 0.8, "joy": 0.8, "energy": 0.7, "clean": 1.2}, "likes_water": true},
}

var HOUSES := [
	{"name": "Палатка", "price": 0, "desc": "Полосатая палатка под открытым небом. С неё всё начинается.",
		"windows": [Vector2(0, -12)], "interior": false},
	{"name": "Шалаш", "price": 150, "desc": "Деревянный домик. В дождь питомец больше не пачкается.",
		"windows": [Vector2(-17, -18), Vector2(17, -17)], "interior": false},
	{"name": "Маленький дом", "price": 600, "desc": "Настоящий дом с комнатой. Открывает мебель для интерьера.",
		"windows": [Vector2(-22, -22), Vector2(22, -22)], "interior": true},
	{"name": "Уютный дом", "price": 1500, "desc": "Просторный дом с крыльцом, вторым окном и местом для камина.",
		"windows": [Vector2(0, -68), Vector2(-33, -43), Vector2(33, -43), Vector2(-35, -19), Vector2(35, -19)], "interior": true},
]

## scene: "out" — двор, "in" — комната. pos — нижний центр спрайта в координатах мира 320x180.
## flat — лежит на полу/висит на стене (всегда под персонажами). glow — смещение ночного света.
var ITEMS := {
	"mailbox": {"name": "Почтовый ящик", "desc": "Вдруг придёт письмо? Уют +1.", "price": 30,
		"scene": "out", "pos": Vector2(304, 148), "comfort": 1, "req": 0},
	"flowers": {"name": "Клумба", "desc": "Цветы радуют глаз. Уют +1.", "price": 40,
		"scene": "out", "pos": Vector2(146, 146), "comfort": 1, "req": 0},
	"gnome": {"name": "Садовый гном", "desc": "Охраняет двор с серьёзным видом. Уют +1.", "price": 50,
		"scene": "out", "pos": Vector2(258, 150), "comfort": 1, "req": 0},
	"lantern": {"name": "Фонарь", "desc": "Светит по ночам. Уют +1.", "price": 60,
		"scene": "out", "pos": Vector2(130, 144), "comfort": 1, "req": 0, "glow": Vector2(0, -22)},
	"bench": {"name": "Скамейка", "desc": "Посидеть и посмотреть на облака. Уют +2.", "price": 90,
		"scene": "out", "pos": Vector2(282, 146), "comfort": 2, "req": 0},
	"plant": {"name": "Фикус", "desc": "Зелень в комнате. Уют +1.", "price": 50,
		"scene": "in", "pos": Vector2(16, 142), "comfort": 1, "req": 2},
	"rug": {"name": "Ковёр", "desc": "Мягкий и тёплый. Уют +1.", "price": 60,
		"scene": "in", "pos": Vector2(184, 153), "comfort": 1, "req": 2, "flat": true},
	"painting": {"name": "Картина", "desc": "Пейзаж с горами. Уют +1.", "price": 70,
		"scene": "in", "pos": Vector2(160, 74), "comfort": 1, "req": 2, "flat": true},
	"lamp": {"name": "Торшер", "desc": "Тёплый свет вечером. Уют +1.", "price": 80,
		"scene": "in", "pos": Vector2(304, 142), "comfort": 1, "req": 2, "glow": Vector2(0, -26)},
	"toy_box": {"name": "Ящик игрушек", "desc": "Игры приносят в 1,5 раза больше радости.", "price": 90,
		"scene": "in", "pos": Vector2(138, 150), "comfort": 1, "req": 2},
	"shelf": {"name": "Книжный шкаф", "desc": "Истории на вечер. Уют +2.", "price": 100,
		"scene": "in", "pos": Vector2(108, 142), "comfort": 2, "req": 2},
	"pet_bed": {"name": "Лежанка", "desc": "Энергия тратится медленнее, сон восстанавливает быстрее.", "price": 110,
		"scene": "in", "pos": Vector2(230, 152), "comfort": 1, "req": 2, "flat": true},
	"bed": {"name": "Кровать", "desc": "Спится слаще: сон восстанавливает быстрее. Уют +2.", "price": 120,
		"scene": "in", "pos": Vector2(268, 142), "comfort": 2, "req": 2},
	"fireplace": {"name": "Камин", "desc": "Треск поленьев и тепло. Уют +3.", "price": 250,
		"scene": "in", "pos": Vector2(60, 142), "comfort": 3, "req": 3, "glow": Vector2(0, -10)},
}
const ITEM_ORDER := ["mailbox", "flowers", "gnome", "lantern", "bench",
	"plant", "rug", "painting", "lamp", "toy_box", "shelf", "pet_bed", "bed", "fireplace"]
