//#pragma language glsl3
#ifdef PIXEL
	uniform float threshold = 0.5;
	const vec3 luma = vec3(0.212656, 0.715158, 0.072186);

	vec4 effect(vec4 _, sampler2D image, vec2 uv, vec2 sc) {
		vec4 screen = Texel(image, uv);

		vec3 tex = screen.rgb;
		float bright = dot(tex, luma);

		return mix(screen, vec4(0.0), step(bright, threshold));
	}
#endif