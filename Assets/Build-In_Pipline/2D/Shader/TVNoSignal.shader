Shader "Learn/ShaderAnim/TVNoSignal"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
		_SignalAmount("Signal Amount", Range(0,1)) = 0.1
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
                float4 vertex : SV_POSITION;
            };

			float RandomRange(float2 seed,  float max,  float min)
			{
				float random =   frac(sin(dot(seed, float2(12.9898, 78.233)))*43758.5453) ;
				return lerp (min, max, random);
			}

            sampler2D _MainTex;
            float4 _MainTex_ST;

			float _SignalAmount;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
				o.uvNoise = v.uv;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
				float2 mul = i.uvNoise.xy * _SinTime.x;
				float ran = RandomRange(mul, 1, 0);

				fixed4 noise = fixed4(ran, ran, ran,1);
                fixed4 col =  lerp(tex2D(_MainTex, i.uv), noise, _SignalAmount);

                return col;
            }
            ENDCG
        }
    }
}
