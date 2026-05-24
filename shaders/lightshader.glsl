uniform vec4 LightColor;

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords)
{
	return color * LightColor * Texel(tex, texture_coords);
}
