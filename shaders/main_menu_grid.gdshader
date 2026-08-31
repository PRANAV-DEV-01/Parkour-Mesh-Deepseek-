shader_type canvas_item;
// Cyberpunk main-menu background: dark navy/black with a faint digital grid,
// subtle scanlines and a slow vertical scroll to give the menu a live feel.

uniform vec4 base_color : source_color = vec4(0.008, 0.012, 0.03, 1.0);
uniform vec4 grid_color : source_color = vec4(0.12, 0.9, 1.0, 1.0);
uniform vec4 horizon_glow : source_color = vec4(0.1, 0.5, 0.9, 1.0);
uniform float cell_size : hint_range(16.0, 160.0) = 56.0;
uniform float scroll_speed : hint_range(0.0, 200.0) = 20.0;
uniform float grid_strength : hint_range(0.0, 1.0) = 0.22;
uniform float scanline_freq : hint_range(20.0, 400.0) = 110.0;
uniform float scanline_alpha : hint_range(0.0, 0.4) = 0.07;

void fragment() {
	vec2 uv = UV;

	// Base dark navy/black.
	vec3 col = base_color.rgb;

	// Slow vertical scroll for the grid (live-menu feel).
	float t = TIME * scroll_speed;
	vec2 gp = uv;
	gp.y += t; // scroll downward over time

	float cell = 1.0 / cell_size; // normalized cell size
	vec2 grid_uv = gp / cell;

	vec2 grid_frac = abs(fract(grid_uv) - 0.5);
	vec2 grid_dist = grid_frac / fwidth(grid_uv);
	float grid_line = 1.0 - min(min(grid_dist.x, grid_dist.y), 1.0);

	// Faint horizon glow near the center/bottom.
	float horizon = smoothstep(0.75, 0.0, abs(uv.y - 0.68));

	// Composite grid + horizon glow.
	float g = grid_line * grid_strength;
	col += grid_color.rgb * g;
	col += horizon_glow.rgb * horizon * 0.18;

	// Scanlines (horizontal dark lines).
	float scan = 0.5 + 0.5 * sin(uv.y * scanline_freq * 6.28318);
	col *= 1.0 - scanline_alpha * (1.0 - scan) * 2.0;

	COLOR = vec4(col, 1.0);
}
