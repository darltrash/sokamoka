//#pragma language glsl3

#ifdef PIXEL
	uniform float threshold = 0.5;
    uniform Image MainTex;

	const vec3 luma = vec3(0.212656, 0.715158, 0.072186);

    void effect()
    {
        vec4 screen = Texel(MainTex, VaryingTexCoord.xy) * VaryingColor;

		vec3 tex = screen.rgb;
		float bright = dot(tex, luma) * screen.a;

        love_Canvases[0] = mix(vec4(0.0), screen, step(bright, threshold));
        love_Canvases[1] = mix(screen, vec4(0.0, 0.0, 0.0, screen.a), step(bright, threshold));
    }
#endif