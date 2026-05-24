uniform vec2 LightPosition;

vec4 position(mat4 transform_projection, vec4 vertex_position)
{
	float z = vertex_position.z;
	return transform_projection * vec4(vertex_position.xy - LightPosition.xy * z, 0.0, 1.0 - z);
}
