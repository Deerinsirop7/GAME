extends Node
## Все игровые данные: палитры, питомцы, жильё, предметы.
## Хочешь добавить предмет — допиши словарь в ITEMS и нарисуй спрайт в tools/gen_sprites.py.

const PET_ORDER := ["dog", "cat", "parrot", "fish"]
var PETS := {
	"dog": {"name": "Собака", "default": "Бобик", "sound": "pet_dog", "toy": "Мячик",
		"coats": ["Рыжий", "Золотистый", "Пятнистый", "Чёрный"],
		"coat_colors": [Color("c4844e"), Color("eab664"), Color("f0eae0"), Color("4a4042")],
		"decay": {"hunger": 1.1, "joy": 1.2, "energy": 1.0, "clean": 1.1}, "likes_water": true},
	"cat": {"name": "Кот", "default": "Мурзик", "sound": "pet_cat", "toy": "Пёрышко",
		"coats": ["Рыжий", "Серый", "Чёрный", "Сиамский"],
		"coat_colors": [Color("f09848"), Color("9898a6"), Color("423c48"), Color("f2e2c6")],
		"decay": {"hunger": 1.0, "joy": 0.9, "energy": 0.9, "clean": 0.7}, "likes_water": false},
	"parrot": {"name": "Попугай", "default": "Кеша", "sound": "pet_parrot", "toy": "Колокольчик",
		"coats": ["Зелёный", "Голубой", "Жако", "Розовый"],
		"coat_colors": [Color("70c05c"), Color("58a0e4"), Color("9c9ca4"), Color("f6c4d0")],
		"decay": {"hunger": 1.0, "joy": 1.2, "energy": 0.9, "clean": 0.8}, "likes_water": true},
	"fish": {"name": "Рыбка", "default": "Немо", "sound": "pet_fish", "toy": "Палец",
		"coats": ["Золотая", "Лимонная", "Кои", "Петушок"],
		"coat_colors": [Color("fa8e3c"), Color("fad650"), Color("faf6f0"), Color("5078dc")],
		"decay": {"hunger": 0.8, "joy": 0.8, "energy": 0.7, "clean": 1.2}, "likes_water": true},
}

var HOUSES := [
	{"name": "Палатка", "price": 0, "desc": "Полосатая палатка под открытым небом. С неё всё начинается.",
		"windows": [Vector2(0, -12)]},
	{"name": "Шалаш", "price": 150, "desc": "Бревенчатый домик. В дождь питомец больше не пачкается.",
		"windows": [Vector2(-17, -18), Vector2(17, -17)]},
	{"name": "Маленький дом", "price": 600, "desc": "Настоящий дом: светлая комната, место для кровати и шкафа.",
		"windows": [Vector2(-23, -23), Vector2(23, -23)]},
	{"name": "Уютный дом", "price": 1500, "desc": "Просторный дом с крыльцом, вторым окном и местом для камина.",
		"windows": [Vector2(0, -70), Vector2(-34, -44), Vector2(34, -44), Vector2(-36, -20), Vector2(36, -20)]},
]

## scene: "out" — двор, "in" — комната. pos — нижний центр спрайта в координатах мира 320x180.
## flat — лежит на полу/висит на стене (всегда под персонажами). glow — смещение ночного света.
var ITEMS := {
	"mailbox": {"name": "Почтовый ящик", "desc": "Вдруг придёт письмо? Уют +1.", "price": 30,
		"scene": "out", "pos": Vector2(304, 148), "comfort": 1, "req": 0},
	"flowers": {"name": "Клумба", "desc": "Цветы радуют глаз. Уют +1.", "price": 40,
		"scene": "out", "pos": Vector2(232, 140), "comfort": 1, "req": 0},
	"gnome": {"name": "Садовый гном", "desc": "Охраняет двор с серьёзным видом. Уют +1.", "price": 50,
		"scene": "out", "pos": Vector2(288, 151), "comfort": 1, "req": 0},
	"lantern": {"name": "Фонарь", "desc": "Светит по ночам. Уют +1.", "price": 60,
		"scene": "out", "pos": Vector2(134, 143), "comfort": 1, "req": 0, "glow": Vector2(0, -22)},
	"bench": {"name": "Скамейка", "desc": "Посидеть и посмотреть на облака. Уют +2.", "price": 90,
		"scene": "out", "pos": Vector2(262, 140), "comfort": 2, "req": 0},
	"rug": {"name": "Ковёр", "desc": "Мягкий и тёплый. Уют +1.", "price": 60,
		"scene": "in", "pos": Vector2(190, 156), "comfort": 1, "req": 0, "flat": true},
	"plant": {"name": "Фикус", "desc": "Зелень в доме. Уют +1.", "price": 50,
		"scene": "in", "pos": Vector2(14, 144), "comfort": 1, "req": 0},
	"pet_bed": {"name": "Лежанка", "desc": "Питомец спит на ней: энергия тратится медленнее, сон быстрее.", "price": 110,
		"scene": "in", "pos": Vector2(232, 153), "comfort": 1, "req": 0, "flat": true},
	"toy_box": {"name": "Ящик игрушек", "desc": "Игры приносят в 1,5 раза больше радости.", "price": 90,
		"scene": "in", "pos": Vector2(104, 150), "comfort": 1, "req": 0},
	"painting": {"name": "Картина", "desc": "Пейзаж с горами. Уют +1.", "price": 70,
		"scene": "in", "pos": Vector2(160, 72), "comfort": 1, "req": 1, "flat": true},
	"lamp": {"name": "Торшер", "desc": "Тёплый свет вечером. Уют +1.", "price": 80,
		"scene": "in", "pos": Vector2(306, 144), "comfort": 1, "req": 1, "glow": Vector2(0, -26)},
	"shelf": {"name": "Книжный шкаф", "desc": "Истории на вечер. Уют +2.", "price": 100,
		"scene": "in", "pos": Vector2(80, 144), "comfort": 2, "req": 2},
	"bed": {"name": "Кровать", "desc": "Твоя кровать: рядом питомцу спится слаще. Уют +2.", "price": 120,
		"scene": "in", "pos": Vector2(282, 144), "comfort": 2, "req": 2},
	"fireplace": {"name": "Камин", "desc": "Треск поленьев и тепло. Уют +3.", "price": 250,
		"scene": "in", "pos": Vector2(40, 144), "comfort": 3, "req": 3, "glow": Vector2(0, -10)},
}
const ITEM_ORDER := ["mailbox", "flowers", "gnome", "lantern", "bench",
	"rug", "plant", "pet_bed", "toy_box", "painting", "lamp", "shelf", "bed", "fireplace"]
