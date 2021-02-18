Shader "Learn/ShaderAnim/TV"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_NoiseTex("NoiseTex", 2D) = "white" {}
		_MaskTex("Mask",2D) = "white" {}
		_Offset("offset", float) = 0.02
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
				float2 uvNoise : TEXCOORD1;
				float2 uvMask : TEXCOORD2;
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
			sampler2D _NoiseTex;
			sampler2D _MaskTex;
            float4 _MainTex_ST;
			float4 _NoiseTex_ST;
			float4 _MaskTex_ST;

			float _Offset;

			inline float random(float2 uv) {
				return frac(sin(dot(uv, float2(12.9398, 78.233))) * 437583.5453);
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uvNoise = TRANSFORM_TEX(v.uv, _NoiseTex);
				o.uvMask = TRANSFORM_TEX(v.uv, _MaskTex);
                return o;
            }

			fixed4 frag(v2f i) : SV_Target
			{
				i.uvMask.y += _Time.y * 0.1;
				fixed4 mask = tex2D(_MaskTex, i.uvMask);
				if (mask.r < 0.3) {
					discard;
				}

				i.uvNoise.y =  i.uvNoise.y + _Time.y * 0.1;
				i.uvNoise.x =  0;
				

				fixed4 noise = tex2D(_NoiseTex, i.uvNoise);
				noise.r = (noise.r - 0.5) * 2;

				float randomV = random(i.uvNoise);
				randomV = pow(randomV, 20);

				if (randomV < 0.4) {
					randomV = 0;
				}

				i.uv.x += noise.r * _Offset;
				i.uv.x *= (1 + randomV);

				fixed4 col = tex2D(_MainTex, i.uv);
                return col;
            }
            ENDCG
        }
    }
}
