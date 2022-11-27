Shader "Genshin/GenshinCharacterBodyShader"
{
    Properties
    {
        _BodyDiffuse ("Body Diffuse", 2D) = "white" {}
        _BodyLightMap ("Body LightMap", 2D) = "white" {}
        _BodyShadowRamp ("Body ShadowRamp", 2D) = "white" {}
        _ShadowSmooth ("Shadow Smooth", Range(0, 1)) = 0.5
        _ShadowRampLerp ("Shadow Ramp Lerp", Range(0,1)) = 0.5
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
            };

            sampler2D _BodyDiffuse;
            float4 _BodyDiffuse_ST;
            sampler2D _BodyLightMap;
            sampler2D _BodyShadowRamp;
            float _ShadowSmooth;
            float _ShadowRampLerp;

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _BodyDiffuse);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(v.vertex, unity_ObjectToWorld).xyz;
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                // fixed3 ambient = UNITY_LIGHTMODEL_AMBIENT.xyz;
                fixed3 worldNormal = normalize(i.worldNormal);

                // 获取主光源方向
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                // 采样
                // light map:
                //  r: 高光遮罩
                //  g: 阴影AO遮罩
                //  b: 镜面反射强调遮罩
                //  a: ramp层级遮罩
                float4 lightMap = tex2D(_BodyLightMap, i.uv);
                // 基本色
                fixed3 baseColor = tex2D(_BodyDiffuse, i.uv).rgb;

                // 半兰伯特光照模型
                fixed3 halfLambert = max(0, dot(worldNormal, worldLightDir)) * 0.5 + 0.5;
                halfLambert = smoothstep(0, _ShadowSmooth, halfLambert);

                // float shadowAO = smoothstep(0.1, lightMap.g, 0.7);
                // float shadowAOMask = 1 - smoothstep(saturate(lightMap.g), 0.2, 0.6);
                float rampU = clamp(halfLambert, 0.00390625, 1 - 0.00390625);
                // 0.03是为了防止rampValue为0
                // 对不同质感的区域进行采样

                float _Day = 0; // 0-0.5 为白天，0.5-1 为夜晚
                float rampVBase = _Day < 0.5 ? 0.5 : 0; // 决定对上半部分还是下半部分采样
                half3 shadowRamp1 = tex2D(_BodyShadowRamp, float2(rampU, 0.45 + rampVBase)).rgb;
                half3 shadowRamp2 = tex2D(_BodyShadowRamp, float2(rampU, 0.35 + rampVBase)).rgb;
                half3 shadowRamp3 = tex2D(_BodyShadowRamp, float2(rampU, 0.25 + rampVBase)).rgb;
                half3 shadowRamp4 = tex2D(_BodyShadowRamp, float2(rampU, 0.15 + rampVBase)).rgb;
                half3 shadowRamp5 = tex2D(_BodyShadowRamp, float2(rampU, 0.05 + rampVBase)).rgb;
                // Skin: [1.0, 1.0] Silk: (0.5,0.7] Metal: (0.3, 0.5] Soft: (0.0, 0.3] Hand: [0.0, 0.0]
                half3 skinRamp = step(abs(lightMap.a - 1), 0.05) * shadowRamp1;
                half3 tightsRamp = step(abs(lightMap.a - 0.7), 0.05) * shadowRamp2;
                half3 metalRamp = step(abs(lightMap.a - 0.5), 0.05) * shadowRamp3;
                half3 softCommonRamp = step(abs(lightMap.a - 0.3), 0.05) * shadowRamp4;
                half3 hardSilkRamp = step(abs(lightMap.a - 0.0), 0.05) * shadowRamp5;
                // 得到最终的阴影颜色
                half3 finalRamp = skinRamp + tightsRamp + metalRamp + softCommonRamp + hardSilkRamp;
                finalRamp = lerp(finalRamp, half3(1, 1, 1), _ShadowRampLerp);
                float3 finalColor = finalRamp * baseColor;

                return float4(finalColor, 1);
            }
            ENDCG
        }
    }
}