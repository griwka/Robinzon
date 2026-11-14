class_name Climbable
extends Node3D
## Лиана для лазания: вертикальный отрезок от bottom до top (локальные координаты родителя).
## Сверху игрок выходит на площадку exit. Лезть можно только в перчатках лазальщика.

var bottom := Vector3.ZERO
var top := Vector3(0, 5, 0)
var exit := Vector3.ZERO
var ladder := false
var ladder_yaw := 0.0   # железная лестница (бункер): перчатки не нужны, сил тратится меньше
var ice := false        # ледяная стена (Ледяной остров): нужны ледоруб и перчатки; ladder_yaw — куда смотрит стена
var rest_step := 0.0    # на ледяной стене через каждые rest_step м — зарубка, где можно повисеть и отдышаться
var locked_hint := ""   # не пускает (например, поперёк тропы спит морж) — вот почему
var rock := false       # выступы базальта (стена кратера): нужны перчатки, как для лианы
var hot := false        # на стене жарко (Остров Вулкана): растёт шкала жара
var wind := false       # открытая стена на высоте (Великий маяк): в порыв ветра силы тают втрое быстрее
var holds := ""         # своя модель выступов (стена Великого маяка), нужны перчатки


func _ready() -> void:
	add_to_group("climb")
	var len := top.y - bottom.y
	var segs := int(ceil(len))
	if ice or rock or holds != "":
		for i in segs:
			var im := Models.glb(holds if holds != "" else ("ice_steps" if ice else "rock_holds"))
			if im == null:
				break
			im.position = bottom + Vector3(0, i * len / segs, 0)
			im.scale = Vector3(1.0, len / segs, 1.0)
			im.rotation.y = ladder_yaw
			add_child(im)
		return
	if ladder:
		for i in segs:
			var lm := Models.glb("ladder")
			if lm == null:
				break
			lm.position = bottom + Vector3(0, i * len / segs, 0)
			lm.scale = Vector3(1.0, len / segs, 1.0)
			lm.rotation.y = ladder_yaw
			add_child(lm)
		return
	for i in segs:
		var m := Models.glb("liana")
		if m == null:
			break
		m.position = bottom + Vector3(0, i * len / segs, 0)
		m.scale = Vector3(1.4, len / segs, 1.4)
		m.rotation.y = i * 1.7
		add_child(m)


## Вид опоры для позы лазания (HeroRig.CLIMB): лиана — обхватить, стена — выступы, лестница — стойки и ступеньки.
func kind() -> String:
	if ladder:
		return "ladder"
	return "wall" if ice or rock or holds != "" else "rope"


## Высота одного куска модели опоры (модель в 1 м растянута на длину подъёма); у лестницы на куске три ступеньки.
func seg_height() -> float:
	var h := top.y - bottom.y
	return h / maxf(1.0, ceil(h))


## Висит ли герой у зарубки (высота над низом y_rel): там силы не тратятся, а копятся.
func at_rest(y_rel: float) -> bool:
	if rest_step <= 0.0 or y_rel < rest_step * 0.5:
		return false
	var k := fmod(y_rel, rest_step)
	return k < 0.35 or k > rest_step - 0.35


func world_bottom() -> Vector3:
	return get_parent().to_global(bottom)


func world_top() -> Vector3:
	return get_parent().to_global(top)


func world_exit() -> Vector3:
	return get_parent().to_global(exit)
