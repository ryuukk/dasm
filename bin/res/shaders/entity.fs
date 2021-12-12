

//#define BLENDED
//#define ALPHA_TEST

in vec3 v_normal;

#ifdef BLENDED
in float v_opacity;
#ifdef ALPHA_TEST
in float v_alphaTest;
#endif
#endif


#ifdef TEXTURE
in vec2 v_diffuseUV;
uniform sampler2D u_diffuseTexture;
#endif

uniform vec4 u_fogColor;
in float v_fog;

out vec4 v_fragColor;

void main()
{
	vec3 normal = v_normal;

	vec4 emissive = vec4(0.0);
	vec4 diffuse = vec4(1.0, 1.0, 1.0, 1.0);
	
	#ifdef TEXTURE
		diffuse = texture(u_diffuseTexture, v_diffuseUV);
        
        //if (diffuse.x > 0.0)
        //{
        //    diffuse.x = normal.x;
        //}
	#else
		diffuse.xyz = normal;
	#endif

	v_fragColor.rgb = diffuse.rgb + emissive.rgb;

	// fog
	vec3 old = v_fragColor.rgb;
	v_fragColor.rgb = mix(v_fragColor.rgb, u_fogColor.rgb, v_fog);

	//v_fragColor.rgb = old;

	#ifdef BLENDED
		v_fragColor.a = diffuse.a * v_opacity;
		#ifdef ALPHA_TEST
			if (v_fragColor.a <= v_alphaTest)
				discard;
		#endif
	#else
		v_fragColor.a = 1.0;
	#endif
}