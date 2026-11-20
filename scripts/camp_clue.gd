class_name CampClue
extends Node3D
## Две точки осмотра на готовой модели старого лагеря: остывший очаг и журнал.

var hearth := false


static func place_in(camp: Node3D) -> void:
	if Game.stat("solved", "camp_rubbing") > 0:
		return
	for is_hearth: bool in [true, false]:
		if is_hearth and Game.flags.get("camp_charcoal", false):
			continue
		var clue := CampClue.new()
		clue.hearth = is_hearth
		# Положения очага и подставки в Blender-модели old_camp (Z в Blender — высота).
		clue.position = Vector3(2.0, 0.15, -0.6) if is_hearth else Vector3(1.5, 0.95, 1.6)
		camp.add_child(clue)
		clue.add_to_group("interactable")
		clue.add_to_group("camp_clues")


func interact_point() -> Vector3:
	return global_position


func tool_hint() -> String:
	return ""


func get_hint() -> String:
	if hearth:
		return "Разгрести золу в старом очаге"
	return "Проявить запись угольком" if Game.flags.get("camp_charcoal", false) else "Рассмотреть лист на подставке"


func interact(_player: Node) -> void:
	if not is_in_group("interactable") or Game.stat("solved", "camp_rubbing") > 0:
		return
	if hearth:
		Game.flags["camp_charcoal"] = true
		Game.dialogue_requested.emit([["player", "Под мокрой золой сухой уголёк. Мягкий, пачкает пальцы. Таким хорошо снимать отпечатки с бумаги."]], Callable())
	elif not Game.flags.get("camp_charcoal", false):
		Game.dialogue_requested.emit([["player", "Верхний лист вырван. На нижнем остались вмятины от карандаша. Если потереть бумагу угольком, буквы проступят."]], Callable())
		return
	else:
		Game.dialogue_requested.emit([["narrator", "Ты проводишь угольком плашмя. Лист темнеет, и на нём проступают светлые буквы: «Северный берег. Шлюпку вытащил на камни»."]], Callable())
		Game.bump("solved", "camp_rubbing")
	remove_from_group("interactable")
	remove_from_group("camp_clues")
	queue_free()
