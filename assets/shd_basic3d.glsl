varying vec3 normal;

#ifdef VERTEX
	uniform mat4 model;
	uniform mat4 view;
	uniform mat4 projection;

	attribute vec3 VertexNormal;

	mat3 cofactor(mat4 _m) {
		return mat3(
			_m[1][1]*_m[2][2]-_m[1][2]*_m[2][1],
			_m[1][2]*_m[2][0]-_m[1][0]*_m[2][2],
			_m[1][0]*_m[2][1]-_m[1][1]*_m[2][0],
			_m[0][2]*_m[2][1]-_m[0][1]*_m[2][2],
			_m[0][0]*_m[2][2]-_m[0][2]*_m[2][0],
			_m[0][1]*_m[2][0]-_m[0][0]*_m[2][1],
			_m[0][1]*_m[1][2]-_m[0][2]*_m[1][1],
			_m[0][2]*_m[1][0]-_m[0][0]*_m[1][2],
			_m[0][0]*_m[1][1]-_m[0][1]*_m[1][0]
		);
	}

	vec4 position(mat4 matrix, vec4 vertex) {
		normal = cofactor(model) * VertexNormal;
		return projection * view * model * vertex;
	}
#endif

#ifdef PIXEL
	vec3 colorA = vec3(1.0, 0.0, 0.0);
	vec3 colorB = vec3(0.0, 0.0, 1.0);

	vec4 effect(vec4 color, sampler2D tex, vec2 uv, vec2 sc) {
		float diffuse = floor(dot(normal, vec3(0.0, 0.78, -0.78))*8.0)/8.0;
		vec4 cout = color;
		cout.rgb *= mix(colorA, colorB, diffuse);
		return cout;
	}
#endif