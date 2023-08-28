Shader "EmptyWhite/BodyTest"
{
    Properties
    {
        _MetalTex("卡通金属贴图",2D) = "white" {}
        _BaseTex ("基础颜色图", 2D) = "white" {}
        _ShadowRampTex ("阴影映射图",2D) = "white"{}
        _LightMap ("LIM图", 2D) = "white" {}
        
        _OcclusionRange ("闭塞范围",range(0,0.2))= 0.15
        _OcclusionDensity ("闭塞强度",range(0,1))= 0.5 
        _ShadowRange ("阴影范围",range(0,0.5))= 0.3
        _ShadowType ("阴影种类",range(0,1))= 0.95
        
        _Gloss ("金属光泽度",range(8.0,256)) = 20
        
        _Color ("Color",Color) = (1,0,0,1)
        _RimOffect("RimOffect",float) = 1
        _Threshold("Threshold",float) = 0.5
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"
            #include "CgincLib/MyCginc.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal :NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertexCS : SV_POSITION;
                float3 normalWS : TEXCOORD2;
                float3 vertexWS : TEXCOORD3;
                float scrPos : TEXCOORD4;
            };

            sampler2D _MetalTex;
            sampler2D _BaseTex;
            sampler2D _LightMap;
            sampler2D _ShadowRampTex;
            float _OcclusionRange;
            float _OcclusionDensity;
            float _ShadowRange;
            float _ShadowType;
            float _Gloss;
            
            float4 _Color;
            float  _RimOffect;
            float _Threshold;

            v2f vert(appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertexWS = mul(unity_ObjectToWorld, v.vertex);
                o.vertexCS = UnityObjectToClipPos(v.vertex);
                UNITY_TRANSFER_FOG(o, o.vertex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.scrPos = o.vertexCS.w ;
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                float3 normalWS = normalize(i.normalWS);
                float3 normalVS = mul(unity_WorldToCamera, normalWS);
                
                float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDirWS = normalize(_WorldSpaceCameraPos.xyz-i.vertexWS);
                float3 halfDir = normalize(lightDirWS+viewDirWS);
                // 纹理采样
                float4 matCap = tex2D(_MetalTex, normalVS.xy / 2 + 0.5);
                fixed4 baseCol = tex2D(_BaseTex, i.uv);
                float4 Lim = tex2D(_LightMap, i.uv);

                // float2 screenParams01 = float2(i.vertexCS.x/_ScreenParams.x,i.vertexCS.y/_ScreenParams.y);
                // float2 offectSamplePos = screenParams01 + normalVS.xy * _RimOffect ;
                // float offcetDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offectSamplePos);
                // float trueDepth   = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenParams01);
                //
                // float linear01EyeOffectDepth = Linear01Depth(offcetDepth);
                // float linear01EyeTrueDepth = Linear01Depth(trueDepth);
                // float depthDiffer = linear01EyeOffectDepth - linear01EyeTrueDepth;
                // float rimIntensity = step(_Threshold,depthDiffer);
                // float4 rimcol = float4(depthDiffer,depthDiffer,depthDiffer,1);
                
                fixed occlusion = 1 - step(Lim.g, _OcclusionRange)*_OcclusionDensity;
                fixed3 halfLambert = saturate(dot(normalWS,lightDirWS))*0.5+0.5;
                fixed4 ShadowRamp = tex2D(_ShadowRampTex, float2(halfLambert.x+_ShadowRange,_ShadowType));
                float metalRange = step(Lim.r, 0.3);
                float matcapRange = step(Lim.r,0.03);
                matcapRange = metalRange - matcapRange;
                // 做两层 一层只有matcap,一层matcap加metal
                float4 matcapCol = BlendAdd(matCap,1-matcapRange);
                float4 metalCol = lerp(float4(0,0,0,0),matCap,1-metalRange);
                fixed sepcular = (0,1,pow(max(0,dot(normalWS,halfDir)),_Gloss)*0.5+0.5);
                // 这个1.2 和 pow的数值可以做为参数
                sepcular = pow(lerp(float4(0,0,0,0),sepcular,1-metalRange)*1.2,2);
                //float4 test = BlendAdd(One2Four(sepcular),One2Four(1-metalRange));
                metalRange = BlendAdd(metalRange,sepcular);
                // metal=lerp(sepcular,0,metal);
                metalCol = (BlendAdd(metalCol,metalRange));
                float4 finalCol = lerp(metalCol,matcapCol,matcapRange);
                finalCol = BlendMul(finalCol,baseCol)*ShadowRamp;
                finalCol = BlendMul(occlusion,finalCol);
                UNITY_APPLY_FOG(i.fogCoord, finalcol);

                 float4 testValue = One2Four(offcetDepth) ;
                return rimcol;
                
            }
            ENDCG
        }
    }
}
