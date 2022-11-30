Shader "Genshin/GenshinCharacterFaceShader"
{
    Properties
    {
        [Header(Diffuse)][Space(5)]
        _FaceDiffuse ("Face Diffuse", 2D) = "white" {}
        _BaseColor ("Base Color", Color) = (1,1,1,1)
        _ShadowColor ("Shadow Color", Color) = (0.882,0.725,0.698,1)
        _FaceLightMap ("Face Light Map", 2D) = "white" {}
        _FaceShadowMap ("Face Shadow Map", 2D) = "white" {}
        _FaceShadowAlpha ("Face Shadow Alpha", Range(0,1)) = 0.5
        [Space(10)]
        
        [Header(Outline)][Space(5)]
        _Outline("Thick of Outline",Float) = 0.01
        _Factor ("Factor", Range(0,1)) = 0.5
        _OutlineLerp ("Outline Lerp", Range(0,1)) = 0.5
        _FaceTo ("Face To", Vector) = (0,0,1,0)
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
                float4 vertexColor : Color;
            };

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 worldNormal : TEXCOORD1;
                fixed3 worldPos : TEXCOORD2;
                fixed3 forward : TEXCOORD3;
                float4 vertexColor : TEXCOORD4;
            };

            sampler2D _FaceDiffuse;
            float4 _FaceDiffuse_ST;
            fixed4 _BaseColor;
            fixed4 _ShadowColor;
            sampler2D _FaceLightMap;
            sampler2D _FaceShadowMap;
            float _FaceShadowAlpha;
            int _TestMode;
            float4 _FaceTo;

            v2f vert(a2v v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _FaceDiffuse);
                o.worldNormal = mul(v.normal, (float3x3)unity_WorldToObject);
                o.worldPos = mul(v.vertex, unity_ObjectToWorld).xyz;
                o.forward = UnityObjectToWorldNormal(_FaceTo.xyz);
                o.vertexColor = v.vertexColor;
                return o;
            }

            fixed4 test_mode(int mode, v2f i)
            {
                switch (mode)
                {
                case 1:
                    return tex2D(_FaceLightMap, i.uv).r;
                case 2:
                    return tex2D(_FaceLightMap, i.uv).g;
                case 3:
                    return tex2D(_FaceLightMap, i.uv).b;
                case 4:
                    return tex2D(_FaceLightMap, i.uv).a;
                case 5:
                    return float4(i.uv, 0, 0); //uv
                case 6:
                    return i.vertexColor.xyzz; //vertexColor
                case 7:
                    return tex2D(_FaceDiffuse, i.uv); //baseColor
                case 8:
                    return tex2D(_FaceDiffuse, i.uv).a; //baseColor.a
                default:
                    return 1;
                }
            }

            fixed4 frag(v2f i) : SV_Target
            {
                if (_TestMode != 0)
                    return test_mode(_TestMode, i);

                fixed3 worldForward = normalize(i.forward);
                // return float4(worldForward, 0);
                fixed3 worldLightDir = normalize(UnityWorldSpaceLightDir(i.worldPos));

                fixed3 baseColor = tex2D(_FaceDiffuse, i.uv).rgb;
                fixed4 shadowColor = tex2D(_FaceShadowMap, i.uv);

                float3 projectLight = worldLightDir - float3(0, 1, 0) * dot(worldLightDir, float3(0, 1, 0));
                float lambert = dot(worldForward, normalize(projectLight)) * 0.5 + 0.5;
                fixed lr = cross(worldForward, worldLightDir).y;
                fixed4 lightMapL = i.uv.y > 0.8 ? 1 : tex2D(_FaceLightMap, i.uv);
                fixed4 lightMapR = i.uv.y > 0.8 ? 1 : tex2D(_FaceLightMap, float2(1 - i.uv.x, i.uv.y));
                fixed4 lightMap = lr > 0 ? lightMapL : lightMapR;
                // 吧lambert作为faceLightMap的采样阈值，大于该阈值则为高光，小于该阈值则为阴影
                lightMap = lightMap.a < lambert ? 1 : 1 - _ShadowColor.a;
                float3 lLerp = lerp(_ShadowColor.rgb * shadowColor.rgb, _BaseColor.rgb, lightMap.a);
                float3 alpha = lerp(lLerp, float3(1, 1, 1), _FaceShadowAlpha);
                fixed3 diffuse = alpha * baseColor;

                return float4(diffuse, 1);
            }
            ENDCG
        }

        Pass
        {
            //处理光照前的pass渲染
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
            sampler2D _FaceDiffuse;

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
                float4 color = tex2D(_FaceDiffuse, i.uv);
                color = lerp(color, float4(0, 0, 0, 1), _OutlineLerp);
                UNITY_APPLY_FOG(i.fogCoord, color);
                return color;
            }
            ENDCG
        }
    }
    FallBack "Specular"
}