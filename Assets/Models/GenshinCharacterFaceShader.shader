Shader "Genshin/GenshinCharacterFaceShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _ShadowColor ("Shadow Color", Color) = (0.882,0.725,0.698,1)
        _FaceLightMap ("Face Light Map", 2D) = "white" {}
        _FaceShadowAlpha ("Face Shadow Alpha", Range(0,1)) = 0.5
    }
    SubShader
    {
        Tags
        {
            "RenderType"="ForwardBase"
        }

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "UnityCG.cginc"
            #include "Lighting.cginc"

            struct a2v
            {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                fixed3 worldPos : TEXCOORD2;
                fixed3 forward : TEXCOORD3;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            fixed4 _BaseColor;
            fixed4 _ShadowColor;
            sampler2D _FaceLightMap;
            float _FaceShadowAlpha;

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(v.vertex, unity_ObjectToWorld).xyz;
                o.forward = UnityObjectToWorldNormal(fixed3(0, 0, 1));
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                fixed3 worldForward = normalize(i.forward);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 baseColor = tex2D(_MainTex, i.uv).rgb;

                float3 projectLight = worldLightDir - float3(0, 1, 0) * dot(worldLightDir, float3(0, 1, 0));
                float lambert = dot(worldForward, normalize(projectLight)) * 0.5 + 0.5;
                fixed lr = cross(worldForward, worldLightDir).y;
                fixed4 lightMapL = tex2D(_FaceLightMap, i.uv);
                fixed4 lightMapR = tex2D(_FaceLightMap, float2(1 - i.uv.x, i.uv.y));
                fixed4 lightMap = lr > 0 ? lightMapL : lightMapR;
                // 吧lambert作为faceLightMap的采样阈值，大于该阈值则为高光，小于该阈值则为阴影
                lightMap = lightMap.a < lambert ? 1 : 1 - _ShadowColor.a;
                float3 lLerp = lerp(_ShadowColor.rgb, _BaseColor.rgb, lightMap.a);
                float3 alpha = lerp(lLerp, float3(1, 1, 1), _FaceShadowAlpha);
                fixed3 diffuse = alpha * baseColor;

                return float4(diffuse, 1);
            }
            ENDCG
        }
    }
}