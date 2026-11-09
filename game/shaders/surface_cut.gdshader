shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;
#define CUTOUT
#include "res://shaders/surface_inc.gdshaderinc"
