Shader "Learn/ShaderAnim/Ori_AlphaTest"
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
			"Queue" = "AlphaTest"
			"IgnoreProjector" = "True"
			"RenderType" = "TransparentCutout"
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

			float Remap(float old1 ,float old2,float new1,float new2,float x)
			{
				return new1 + (x - old1) * ( new2 - new1) / (old2 - old1) ;
			}

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				//float2 center;
				fixed4 mask = tex2D(_MaskTex, i.uv);
				//
				//if (mask.r > 0.5) {
				//	center = float2(1, 0.6);
				//}
				//else {
				//	center = float2(i.uv.x, 0);
				//}

				float R = Remap(0.3 , 0.9, 0, 1, mask.r);
				float centerX = (1 - R) * i.uv.x + R;
				float centerY = clamp(R - 0.3, 0, 0.6);
				float2 center = float2(centerX, centerY);

				float2 fragDir = normalize(i.uv - center);   //片段和uv波动中心的方向
				float dis = distance(center, i.uv);		  //片段与uv波动中心的距离

				i.uv += _SinMax * sin(_Time.y * _TimeFactor + dis * _DisFactor) * fragDir * mask.r * mask.r ;
                fixed4 col = tex2D(_MainTex, i.uv);

				if ((col.a - 0.1) < 0.0) {
						discard;
				}

				return col;
            }
            ENDCG
        }
    }
}
