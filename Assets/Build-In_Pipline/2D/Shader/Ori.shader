Shader "Learn/ShaderAnim/ori"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_MaskTex("anim mask", 2D) = "white" {}
		_SinMax("SinMax", float) = 0.2
		_DisFactor("DisFactor", float) = 0.2
		_TimeFactor("TimeFactor", float) = 0.2
    }
    SubShader
    {
        Tags { 
			"RenderType" = "Opaque"
		}

        Pass
        {
			Tags{ "LightMode" = "ForwardBase" }

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
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
			sampler2D _MaskTex;
            float4 _MainTex_ST;
			float4 _MaskTex_ST;

			float _SinMax;
			float _DisFactor;
			float _TimeFactor;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float2 mid;
				fixed4 mask = tex2D(_MaskTex, i.uv);
				if (mask.r > 0.5) {
					mid = float2(1, 0.6);
				}
				else {
					mid = float2(i.uv.x, 0);
				}

				float2 fragDir = normalize(i.uv - mid);   //片段和uv波动中心的方向
				float dis = distance(mid, i.uv);		  //片段与uv波动中心的距离

				i.uv += _SinMax * sin(_Time.y * _TimeFactor + dis * _DisFactor) * fragDir * mask.r * mask.r ;
                fixed4 col = tex2D(_MainTex, i.uv);

				return col;
            }
            ENDCG
        }
    }
}
