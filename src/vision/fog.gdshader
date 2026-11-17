shader_type canvas_item;
render_mode blend_mul, unshaded;
// Kangur fog of war. Multiplies the world by a brightness field:
//   current visibility (player cone + peripheral disc) → white (unlit)
//   explored memory (coarse grid, only ever grows)      → dim
//   everything else                                     → near-black (~92%)
// Both inputs are light maps (r channel), combined by max, so there is no
// alpha/blend-state trickery: GL Compatibility renders this exactly.

// Half-res, world-anchored SubViewport holding the player's cone + disc.
uniform sampler2D cone_mask : filter_linear, repeat_disable;
// Coarse explored-memory grid (one texel per EXPLORE_CELL world px).
uniform sampler2D explored_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(0.0);   // world px at texel (0,0) of cone_mask
uniform vec2 mask_size = vec2(1.0);     // world px spanned by cone_mask
uniform vec2 memory_origin = vec2(0.0);
uniform vec2 memory_size = vec2(1.0);   // world px spanned by the memory grid
uniform vec2 rect_pos = vec2(0.0);      // this ColorRect's world top-left
uniform vec2 rect_size = vec2(1.0);
uniform float explored_level : hint_range(0.0, 1.0) = 0.35;
uniform float unexplored_level : hint_range(0.0, 1.0) = 0.08;
// Soft edge, in cone-mask texels; widens ray-fan faceting into a CS2D falloff.
uniform float soft_texels = 3.0;

float cone_at(vec2 world) {
	return clamp(texture(cone_mask, (world - mask_origin) / mask_size).r, 0.0, 1.0);
}

void fragment() {
	vec2 world = rect_pos + UV * rect_size;
	float current = cone_at(world);
	// 3x3 tent blur: hides the 30-ray polygon's facets at the shadow edge.
	vec2 t = vec2(soft_texels / mask_size.x, soft_texels / mask_size.y);
	float sum = current * 4.0;
	sum += cone_at(world + vec2(t.x, 0.0));
	sum += cone_at(world - vec2(t.x, 0.0));
	sum += cone_at(world + vec2(0.0, t.y));
	sum += cone_at(world - vec2(0.0, t.y));
	sum += cone_at(world + t) * 0.5;
	sum += cone_at(world - t) * 0.5;
	sum += cone_at(world + vec2(t.x, -t.y)) * 0.5;
	sum += cone_at(world + vec2(-t.x, t.y)) * 0.5;
	float visible = clamp(sum / 8.0, 0.0, 1.0);

	float explored = clamp(
		texture(explored_mask, (world - memory_origin) / memory_size).r, 0.0, 1.0);
	float level = max(visible, explored * explored_level);
	COLOR = vec4(vec3(mix(unexplored_level, 1.0, level)), 1.0);
}