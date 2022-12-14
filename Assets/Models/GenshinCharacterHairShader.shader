Shader "Genshin/GenshinCharacterHairShader"
{
    Properties
    {
        [Header(Diffuse)][Space(5)]
        [MainTexture] _HairDiffuse ("Hair Diffuse", 2D) = "white" {}
        _HairLightMap ("Hair LightMap", 2D) = "white" {}
        _HairShadowRamp ("Hair ShadowRamp", 2D) = "white" {}
        _HairShadowRampLayer ("Hair ShadowRamp Layer", Int) = 5
        [KeywordEnum(Day,Night)] _Day ("Day or Night", Int) = 0
        _ShadowSmooth ("Shadow Smooth", Range(0, 1)) = 0.5
        _ShadowAOIntensity ("Shadow AO Intensity", Range(0, 1)) = 0.5
        _ShadowRampLerp ("Shadow Ramp Lerp", Range(0,1)) = 0.5
        [Space(10)]

        [Header(Specular)][Space(5)]
        _MetalMap ("Metal Map", 2D) = "white" {}
        _StepSpecularGloss ("Step Specular Gloss", Range(0, 1)) = 0.5
        _StepSpecularIntensity ("Step Specular Intensity", Range(0, 10)) = 0.2
        _BlinnPhongSpecularGloss ("BlinnPhong Specular Gloss", Range(0.01, 1000)) = 0.5
        _BlinnPhongSpecularIntensity ("BlinnPhong Specular Intensity", Range(0, 10)) = 0.5
        _MetalSpecularIntensity ("Metal Specular Intensity", Range(0, 1)) = 0.5
        _HighlightSpecularGloss ("Highlight Specular Gloss", Range(0.01, 10)) = 0.5
        _HighlightSpecularIntensity ("Highlight Specular Intensity", Range(0, 1)) = 0.5
        [Toggle] _EnableEdgeRim ("Enable Edge Rim", Int) = 0
        _EdgeRimColor ("Edge Rim Color", Color) = (1, 1, 1, 1)
        _EdgeRimThreshold ("Edge Rim Threshold", Range(0, 1)) = 0.5
        [Space(10)]

        [Header(Normal Map)][Space(5)]
        _NormalMap ("Normal Map", 2D) = "bump" {}
        [Space(10)]

        [Header(Outline)][Space(5)]
        _Outline("Thick of Outline",Float) = 0.01
        _Factor("Factor",range(0,1)) = 0.5
        _OutlineLerp("Outline Lerp",range(0,1)) = 0.5
        [Space(10)]

        [Header(Test)][Space(5)]
        [KeywordEnum(None,LightMap_R,LightMap_G,LightMap_B,LightMap_A,UV,VertexColor,BaseColor,BaseColor_A)]
        _TestMode ("Test Mode", Int) = 0
    }
    SubShader
    {
        Tags
        {
            "RenderType"="ForwardBase"
        }
        Cull Off
        ZTest LEqual

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
                float4 vertexColor : COLOR0;
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                fixed3 worldPos : TEXCOORD2;
                float3 worldTangent : TEXCOORD3;
                float3 worldBinormal : TEXCOORD4;
                float4 vertexColor : COLOR0;
            };

            sampler2D _HairDiffuse;
            float4 _HairDiffuse_ST;
            sampler2D _HairLightMap;
            sampler2D _NormalMap;
            sampler2D _HairShadowRamp;
            int _HairShadowRampLayer;
            int _Day;
            float _ShadowSmooth;
            float _ShadowAOIntensity;
            float _ShadowRampLerp;
            int _TestMode;

            sampler2D _MetalMap;
            float _StepSpecularGloss;
            float _StepSpecularIntensity;
            float _BlinnPhongSpecularGloss;
            float _BlinnPhongSpecularIntensity;
            float _MetalSpecularIntensity;
            float _HighlightSpecularGloss;
            float _HighlightSpecularIntensity;
            int _EnableEdgeRim;
            float4 _EdgeRimColor;
            float _EdgeRimThreshold;

            sampler2D _CameraDepthTexture;

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv.xy = TRANSFORM_TEX(v.uv, _HairDiffuse);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.worldNormal = UnityObjectToWorldNormal(v.normal);
                o.worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                o.worldBinormal = cross(o.worldNormal, o.worldTangent) * v.tangent.w;
                o.vertexColor = v.vertexColor;
                return o;
            }

            fixed4 test_mode(int mode, v2f i)
            {
                switch (mode)
                {
                case 1:
                    return tex2D(_HairLightMap, i.uv).r;
                case 2:
                    return tex2D(_HairLightMap, i.uv).g;
                case 3:
                    return tex2D(_HairLightMap, i.uv).b;
                case 4:
                    return tex2D(_HairLightMap, i.uv).a;
                case 5:
                    return float4(i.uv, 1, 1); //uv
                case 6:
                    return i.vertexColor.xyzz; //vertexColor
                case 7:
                    return tex2D(_HairDiffuse, i.uv); //baseColor
                case 8:
                    return tex2D(_HairDiffuse, i.uv).a; //baseColor.a
                default:
                    return 1;
                }
            }

            fixed4 frag(v2f i) : SV_Target
            {
                if (_TestMode != 0)
                    return test_mode(_TestMode, i);

                // fixed3 worldNormal = i.worldNormal;
                // tangent space normal map
                fixed3 normalMap = UnpackNormal(tex2D(_NormalMap, i.uv));
                float3x3 TBN = float3x3(i.worldTangent, i.worldBinormal, i.worldNormal);
                fixed3 worldNormal = normalize(mul(normalMap, TBN));

                // ?????????????????????
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));
                float3 viewDir = normalize(UnityWorldSpaceViewDir(i.worldPos));
                float3 halfVec = normalize(viewDir + worldLightDir);

                // ??????
                // light map:
                //  r: ????????????
                //  g: ??????AO??????
                //  b: ????????????????????????
                //  a: ramp????????????
                float4 lightMap = tex2D(_HairLightMap, i.uv);
                // ?????????
                fixed3 baseColor = tex2D(_HairDiffuse, i.uv).rgb;

                // ????????????????????????
                float halfLambert = dot(worldNormal, worldLightDir) * 0.5 + 0.5;
                halfLambert = smoothstep(0, _ShadowSmooth, halfLambert);

                // ========== Diffuse ==========

                // ??????smoothstep????????????????????????
                float shadowAO = smoothstep(0.2, 0.5, lightMap.g);
                shadowAO = lerp(shadowAO, 1, _ShadowAOIntensity);
                float rampU = clamp(halfLambert, 0.00390625, 1 - 0.00390625);
                // 0.03???????????????rampValue???0
                // ????????????????????????????????????

                // 0-0.5 ????????????0.5-1 ?????????
                float rampVBase = _Day < 0.5 ? 33 : 17; // ?????????????????????????????????????????????
                // float rampPixelU = 0.00390625; // 1/256
                float rampPixelV = 0.03125; // 1/16/2

                // // ??????
                // half3 shadowRamp1 = tex2D(_HairShadowRamp, float2(rampU, 0.45 + rampVBase)).rgb;
                // half3 shadowRamp2 = tex2D(_HairShadowRamp, float2(rampU, 0.35 + rampVBase)).rgb;
                // half3 shadowRamp3 = tex2D(_HairShadowRamp, float2(rampU, 0.25 + rampVBase)).rgb;
                // half3 shadowRamp4 = tex2D(_HairShadowRamp, float2(rampU, 0.15 + rampVBase)).rgb;
                // half3 shadowRamp5 = tex2D(_HairShadowRamp, float2(rampU, 0.05 + rampVBase)).rgb;
                // // Skin: 1.0 Silk: 0.7 Metal: 0.5 Soft: 0.3 Hand: 0.0
                // half3 skinRamp = step(abs(lightMap.a - 1), 0.05) * shadowRamp1;
                // half3 tightsRamp = step(abs(lightMap.a - 0.7), 0.05) * shadowRamp2;
                // half3 metalRamp = step(abs(lightMap.a - 0.5), 0.05) * shadowRamp3;
                // half3 softCommonRamp = step(abs(lightMap.a - 0.3), 0.05) * shadowRamp4;
                // half3 hardSilkRamp = step(abs(lightMap.a - 0.0), 0.05) * shadowRamp5;
                // // ???????????????????????????
                // half3 finalRamp = skinRamp + tightsRamp + metalRamp + softCommonRamp + hardSilkRamp;

                // ??????????????????????????????
                // 0-1 remap 1-_HairShadowRampLayer
                float layer = lerp(1, _HairShadowRampLayer, lightMap.a);
                half3 finalRamp = tex2D(_HairShadowRamp,
                                        float2(rampU, rampPixelV * (rampVBase - 2 * layer))).rgb;
                // return float4(finalRamp, 1);
                finalRamp = finalRamp * shadowAO;
                finalRamp = lerp(finalRamp, half3(1, 1, 1), _ShadowRampLerp);
                float3 diffuse = finalRamp;

                // ========== Specular ==========

                float nl = dot(worldNormal, worldLightDir);
                float nh = dot(worldNormal, halfVec);
                float nv = dot(worldNormal, viewDir);

                // ????????????
                half stepMask = step(0.2, lightMap.r) - step(0.8, lightMap.r);
                // return float4(stepMask, stepMask, stepMask, 1);
                // lightMap.b ????????????
                half stepSpecular = smoothstep(0, 1 - _StepSpecularGloss, saturate(nl)) *
                    _StepSpecularIntensity * stepMask;

                // ??????
                half metalMask = step(0.8, lightMap.r);
                float3 blinnPhongSpecular = pow(max(0, nh), _BlinnPhongSpecularGloss) * _BlinnPhongSpecularIntensity *
                    metalMask;
                // return float4(blinnPhongSpecular, 1);

                float2 metalMapUV = mul((float3x3)UNITY_MATRIX_V, i.worldNormal).xy * 0.5 + 0.5;
                float metalMap = tex2D(_MetalMap, metalMapUV).r;
                float3 metalSpecular = metalMap * _MetalSpecularIntensity * metalMask;

                // ?????????????????????
                half highlightMask = lightMap.b;
                float3 highlightSpecular = smoothstep(0.4, 0.5, pow(max(0, nh), _HighlightSpecularGloss)) *
                    _HighlightSpecularIntensity * highlightMask;
                // return float4(pow(max(0, nh), _HighlightSpecularGloss), 0, 0, 1);
                // return float4(highlightSpecular, 1);

                float3 specular = blinnPhongSpecular + metalSpecular + stepSpecular + highlightSpecular;

                // ========== ??????????????????????????? ==========
                // float2 screenParams = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);
                // float _OffsetMul = 0.5;
                // // ??????????????????
                // float2 screenUV = screenParams + float2(i.worldNormal.xy * _OffsetMul / i.pos.w);
                // // ????????????????????????
                // float offsetDepth = tex2D(_CameraDepthTexture, screenUV).r;
                // // return float4(offsetDepth, offsetDepth, offsetDepth, 1);
                // float trueDepth = tex2D(_CameraDepthTexture, screenParams).r;
                // // return float4(trueDepth, trueDepth, trueDepth, 1);
                // float linear01OffsetDepth = Linear01Depth(trueDepth);
                // float linear01TrueDepth = Linear01Depth(offsetDepth);
                //
                // float depthDiff = linear01OffsetDepth - linear01TrueDepth;
                // // return float4(depthDiff, depthDiff, depthDiff, 1);
                // float rimMask = step(_EdgeRimThreshold, depthDiff);
                // // return float4(rimMask, rimMask, rimMask, 1);
                // float3 rimColor = rimMask * _EdgeRimColor.rgb * _EdgeRimColor.a;
                // // return float4(rimColor, 1);
                if (_EnableEdgeRim)
                {
                    float2 rimScreenUV = float2(i.pos.x / _ScreenParams.x, i.pos.y / _ScreenParams.y);
                    float3 smoothNormal = normalize(UnpackNormalmapRGorAG(i.vertexColor));
                    float3x3 tangentTransform = TBN;
                    float3 worldRimNormal = normalize(mul(smoothNormal, tangentTransform));
                    float2 rimOffsetUV = float2(
                        mul((float3x3)UNITY_MATRIX_V, worldRimNormal).xy * _EdgeRimThreshold * 0.01 / i.pos.w);
                    // return float4(rimOffsetUV, 0, 0);
                    rimOffsetUV = rimScreenUV + rimOffsetUV;

                    float screenDepth = tex2D(_CameraDepthTexture, rimScreenUV).r;
                    float linear01ScreenDepth = LinearEyeDepth(screenDepth);
                    // return float4(linear01ScreenDepth, linear01ScreenDepth, linear01ScreenDepth, 1);
                    float offsetDepth = tex2D(_CameraDepthTexture, rimOffsetUV).r;
                    float linear01OffsetDepth = LinearEyeDepth(offsetDepth);
                    // return float4(linear01OffsetDepth, linear01OffsetDepth, linear01OffsetDepth, 1);
                    float depthDiff = linear01OffsetDepth - linear01ScreenDepth;
                    // return float4(depthDiff, depthDiff, depthDiff, 1);

                    float rimMask = step(0.01, depthDiff);
                    // return float4(rimMask, rimMask, rimMask, 1);
                    float3 rimColor = rimMask * _EdgeRimColor.rgb * _EdgeRimColor.a;
                    diffuse = diffuse + rimColor;
                }

                float3 finalColor = (diffuse + specular) * baseColor;

                return float4(finalColor, 1);
            }
            ENDCG
        }

        Pass
        {
            //??????????????????pass??????
            Tags
            {
                "LightMode" = "Always"
            }
            Cull Front
            ZWrite On
            CGPROGRAM
            #pragma multi_compile_fog
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            float _Outline;
            float _Factor;
            float _OutlineLerp;
            sampler2D _HairDiffuse;

            struct v2f
            {
                float4 pos:SV_POSITION;
                float2 uv:TEXCOORD0;
                UNITY_FOG_COORDS(1)
            };

            v2f vert(appdata_full v)
            {
                v2f o;
                float3 dir = normalize(v.vertex.xyz);
                float3 dir2 = v.normal;
                float D = dot(dir, dir2);
                dir = dir * sign(D);
                dir = dir * _Factor + dir2 * (1 - _Factor);
                v.vertex.xyz += dir * _Outline * 0.001;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = v.texcoord;
                UNITY_TRANSFER_FOG(o, o.pos);
                return o;
            }

            float4 frag(v2f i) :COLOR
            {
                float4 color = tex2D(_HairDiffuse, i.uv);
                color = lerp(color, float4(0, 0, 0, 1), _OutlineLerp);
                UNITY_APPLY_FOG(i.fogCoord, color);
                return color;
            }
            ENDCG
        }
    }
    FallBack "Specular"
}