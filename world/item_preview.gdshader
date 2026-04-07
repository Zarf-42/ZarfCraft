shader_type spatial;
render_mode diffuse_lambert, unshaded;

uniform sampler2D texture_albedo : filter_nearest, repeat_enable;

void fragment() {
    // UV contains raw tiling coords (0→width, 0→height)
    // fract() wraps them into 0→1 within one tile repeat
    vec2 tiled = fract(UV);

    // UV2 contains atlas tile info:
    // x = tile left edge in 0-1 UV space
    // y = tile width in 0-1 UV space
    // Atlas is one row tall so V always spans 0→1 fully
    float tile_x = UV2.x;
    float tile_w = UV2.y;

    // Remap tiled UV into the correct atlas sub-region
    vec2 atlas_uv = vec2(tile_x + tiled.x * tile_w, tiled.y);

    ALBEDO    = texture(texture_albedo, atlas_uv).rgb;
}