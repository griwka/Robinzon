// Мультяшный шейдер листвы: двусторонний, светится на просвет, расступается перед игроком.
// Весь код — в toon_common.gdshaderinc (общий с моделями).
shader_type spatial;
render_mode cull_disabled;

#define FOLIAGE
#include "res://shaders/toon_common.gdshaderinc"
