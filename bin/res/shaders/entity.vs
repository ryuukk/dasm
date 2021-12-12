

//#define BLENDED
//#define ALPHA_TEST
//#define SKINNED

in vec3 a_position;
in vec3 a_normal;

#ifdef TEXTURE
in vec2 a_texCoord0;
#endif

#ifdef SKINNED
in vec2 a_boneWeight0;
in vec2 a_boneWeight1;
in vec2 a_boneWeight2;
in vec2 a_boneWeight3;
#endif

#ifdef TEXTURE
out vec2 v_diffuseUV;
#endif

#ifdef BLENDED
uniform float u_opacity;
out float v_opacity;
#ifdef ALPHA_TEST
uniform float u_alphaTest;
out float v_alphaTest;
#endif
#endif

out vec3 v_normal;
out float v_fog;

// global
uniform float u_time;
uniform mat4 u_projViewTrans;
uniform vec4 u_cameraPosition;


// object
uniform mat4 u_worldTrans;

#ifdef TEXTURE
uniform sampler2D u_diffuseTexture;
uniform vec4 u_diffuseUVTransform;
#endif

#ifdef SKINNED
uniform mat4[NUM_BONES] u_bones;
#endif


void main()
{
	#ifdef SKINNED
		mat4 skinning = mat4(0.0);
		skinning += (a_boneWeight0.y) * u_bones[int(a_boneWeight0.x)];
		skinning += (a_boneWeight1.y) * u_bones[int(a_boneWeight1.x)];
		skinning += (a_boneWeight2.y) * u_bones[int(a_boneWeight2.x)];
		skinning += (a_boneWeight3.y) * u_bones[int(a_boneWeight3.x)];
		vec4 pos = u_worldTrans * skinning * vec4(a_position, 1.0);
	#else
		vec4 pos = u_worldTrans * vec4(a_position, 1.0);
	#endif

	gl_Position = u_projViewTrans * pos;

	#ifdef TEXTURE
	v_diffuseUV = u_diffuseUVTransform.xy + a_texCoord0 * u_diffuseUVTransform.zw; 
	#endif

	#ifdef BLENDED
		v_opacity = u_opacity;
		#ifdef ALPHA_TEST
			v_alphaTest = u_alphaTest;
		#endif //alphaTestFlag
	#endif


	#ifdef SKINNED	
		vec3 normal = normalize((u_worldTrans * skinning * vec4(a_normal, 0.0)).xyz);
	#else
		vec3 normal = normalize((transpose(inverse(mat3(u_worldTrans)))) * a_normal);
	#endif

	v_normal = normal;

	// fog
	vec3 flen = u_cameraPosition.xyz - pos.xyz;
	float fog = dot(flen, flen) * u_cameraPosition.w;
	v_fog = min(fog, 1.0);
}