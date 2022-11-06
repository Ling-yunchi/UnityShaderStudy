Shader "Genshin/GenshinCharacterFaceShader"
{
    Properties
    {
        _Diffuse ("Diffuse", Color) = (1,1,1,1)
        _Specular ("Specular", Color) = (1,1,1,1)
        _Gloss ("Gloss", Range(8,256)) = 20
        _MainTex ("Texture", 2D) = "white" {}
        _LightSmooth ("Light Smooth", Range(0,1)) = 0.1
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _ShadowColor ("Shadow Color", Color) = (0.882,0.725,0.698,1)
        _FaceLightMap ("Face Light Map", 2D) = "white" {}
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
            fixed4 _Diffuse;
            fixed4 _Specular;
            float _Gloss;
            float _LightSmooth;
            fixed4 _BaseColor;
            fixed4 _ShadowColor;
            sampler2D _FaceLightMap;

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
                // fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;

                fixed3 worldForward = normalize(i.forward);
                fixed3 worldNormal = normalize(i.worldNormal);
                fixed3 worldLightDir = normalize(_WorldSpaceLightPos0.xyz);

                fixed3 baseColor = tex2D(_MainTex, i.uv).rgb;

                // Custom Lighting
                // fixed3 lDot = dot(worldNormal, worldLightDir);
                // fixed3 lDot = tex2D(_FaceLightMap, i.uv).rgb;
                // float lSmooth = smoothstep(0, _LightSmooth, lDot);
                // float3 lLerp = lerp(_ShadowColor.rgb, _BaseColor.rgb, lSmooth);

                float3 projectLight = worldLightDir - float3(0, 1, 0) * dot(worldLightDir, float3(0, 1, 0));
                float lambert = dot(worldForward, normalize(projectLight));
                fixed lr = cross(worldForward, worldLightDir).y;
                fixed4 lightMapL = tex2D(_FaceLightMap, i.uv);
                fixed4 lightMapR = tex2D(_FaceLightMap, float2(1 - i.uv.x, i.uv.y));
                fixed4 lightMap = lr > 0 ? lightMapL : lightMapR;
                lightMap = lightMap.a > lambert ? 1 - _ShadowColor.a : 1;
                fixed3 lLerp = lerp(_ShadowColor.rgb, _BaseColor.rgb, lightMap.rgb);
                
                fixed3 diffuse = lLerp * baseColor;

                // fixed3 reflectDir = normalize(reflect(-worldLightDir, worldNormal));
                // fixed3 viewDir = normalize(_WorldSpaceCameraPos.xyz - i.worldPos.xyz);
                // fixed3 specular = _LightColor0.rgb * _Specular.rgb * pow(saturate(dot(reflectDir, viewDir)), _Gloss);

                return float4(diffuse, 1);
            }
            ENDCG
        }
    }
}