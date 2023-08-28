Shader "EmptyWhite/HairTest"
{
    Properties
    {
        
        _hair_s ("头发高光遮罩", 2D) = "white" {}   //这个要不要改成特殊效果贴图?
        _HighlightTex("头发高光形状",2D) = "white" {}
        [HDR]_HightlightCol("头发高光颜色",Color) = (1,1,1,1)
        [Toggle(HLSTEP_ON)] HlStep_On("高光硬切",int) = 1
        _BaseTex ("基础颜色图", 2D) = "white" {}
        _ShadowRampTex ("阴影映射图",2D) = "white"{}
        _LightMap ("LIM图", 2D) = "white" {}
        _OcclusionRange ("闭塞范围",range(0,0.2))= 0.15
        _OcclusionDensity ("闭塞强度",range(0,1))= 0.5
        _ShadowRange ("阴影范围",range(0,0.5))= 0.3
        _ShadowType ("阴影种类",range(0,1))= 0.95
        
        // 描边
        _OutlineWidth("描线宽度",Range(0,1))=0.24
        _OutLineColor("OutLine Color", Color) = (0.5,0.5,0.5,1)
        
        // 屏幕空间边缘光
        [HDR]_RimColor ("边缘光颜色",Color) = (0,0,1,1)
        _RimOffect("边缘光偏差",float) = 0.005
        _Threshold("阈值",float) = 0.5
        _FresnelScale("FresnelScale",Range(0,1))=0.04
        
    }
    SubShader
    {
        Tags
        {
            "RenderType"="Opaque"
            "MyTags"="Mytag001"
        }
        LOD 100
        

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog
            #pragma shader_feature HLSTEP_ON 
            


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
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD2;
                float3 viewDirWS : TEXCOORD3; //worldView
                float3 posWS : TEXCOORD4;  // worldPos
            };

            sampler2D _hair_s;
            sampler2D _HighlightTex;
            float4 _HightlightCol;
            sampler2D _BaseTex;
            sampler2D _LightMap;
            sampler2D _ShadowRampTex;
            float _OcclusionRange;
            float _OcclusionDensity;
            float _ShadowRange;
            float _ShadowType;

            float4 _RimColor;
            float  _RimOffect;
            float _Threshold;
            float _FresnelScale;


            v2f vert(appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.posWS = mul(unity_ObjectToWorld, v.vertex).xyz; 
                UNITY_TRANSFER_FOG(o, o.vertex);
                o.normalWS = UnityObjectToWorldNormal(v.normal);
                o.viewDirWS = UnityWorldSpaceViewDir(o.posWS);
                return o;
            }

            fixed4 frag(v2f i) : SV_Target
            {
                float3 normalWS = normalize(i.normalWS);
                float3 normalVS = mul(unity_WorldToCamera, normalWS);
                float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDirWS = normalize(i.viewDirWS);

                // 纹理采样
                float4 hightightMask = tex2D(_hair_s, normalVS.xy / 2 + 0.5);
                fixed4 HighlightTex = tex2D(_HighlightTex, i.uv);
                fixed4 baseCol = tex2D(_BaseTex, i.uv);
                fixed4 Lim = tex2D(_LightMap, i.uv);

                // hightightMask可以使用一根ramptex将他的分布更加柔和,但是这样需要在多采样一次太费不考虑
                #ifdef HLSTEP_ON
                hightightMask = 1-step(hightightMask,0.1);
                #endif

                // 边缘光
                float depthDiffer = GetDepthDiffer(i.vertex,normalVS,_RimOffect);
                float fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(normalWS, viewDirWS), 7);
                float rimIntensity = step(_Threshold,depthDiffer);
//                rimIntensity = lerp(0,rimIntensity,fresnel);
                rimIntensity = lerp(0,fresnel,rimIntensity);
                float4 rimColor = One2Four(rimIntensity)*_RimColor;
                
                fixed4 highlightCol = BlendMul(hightightMask,HighlightTex)*_HightlightCol;
                fixed occlusion = 1 - step(Lim.g, _OcclusionRange)*_OcclusionDensity;
                fixed3 halfLambert = saturate(dot(normalWS,lightDirWS))*0.5+0.5;
                fixed4 ShadowRamp = tex2D(_ShadowRampTex, float2(halfLambert.x+_ShadowRange,_ShadowType));
                fixed4 finalcol = BlendMul(baseCol,occlusion)+highlightCol;
                finalcol = BlendMul(finalcol,ShadowRamp);
                finalcol = finalcol+rimColor;
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, finalcol);
                //return float4(halfLambert, 1.0f);
                return finalcol;
            }
            ENDCG
        }
        
        // 描边Pass
        Pass
        {
	        Tags {"LightMode"="ForwardBase"}
            Cull Front
            
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"

            half _OutlineWidth;
            half4 _OutLineColor;

            // 解压
            float3 OctahedronToUnitVector( float2 Oct )
            {
                float3 N = float3( Oct, 1 - dot( 1, abs(Oct) ) );
                if( N.z < 0 )
                {
                    N.xy = ( 1 - abs(N.yx) ) * ( N.xy >= 0 ? float2(1,1) : float2(-1,-1) );
                }
                return normalize(N);
            }

            struct a2v 
	        {
                float4 vertex : POSITION;
                float3 normal : NORMAL;
                float2 uv : TEXCOORD0;
                float4 vertColor : COLOR;
                float4 tangent : TANGENT;
                float2 uv1 : TEXCOORD1;
            };

            struct v2f
	        {
                float4 pos : SV_POSITION;
                float2 uv2 : TEXCOORD0;
            };


            v2f vert (a2v v) 
            {
                v2f o;
		        UNITY_INITIALIZE_OUTPUT(v2f, o);
                float3 newnormalWS = v.vertColor.xyz;
                
                float4 pos = UnityObjectToClipPos(v.vertex.xyz);
                float3 normalVS = mul((float3x3)UNITY_MATRIX_IT_MV, newnormalWS.xyz);
                // 将法线变换到NDC空间
                float3 normalNDC = normalize(TransformViewToProjection(normalVS.xyz))*pos.w;

                float4 nearUpperRight = mul(unity_CameraInvProjection, float4(1, 1, UNITY_NEAR_CLIP_VALUE, _ProjectionParams.y));//将近裁剪面右上角位置的顶点变换到观察空间
                float aspect = abs(nearUpperRight.y / nearUpperRight.x);//求得屏幕宽高比
                normalNDC.x *= aspect;
                
                pos.xy += 0.01*_OutlineWidth*normalNDC.xy;
                o.pos = pos;
                return o;
            }

            half4 frag(v2f i) : SV_TARGET 
	        {
                return _OutLineColor;
            }
            ENDCG
        }// 描边Pass END
    }
    FallBack "Diffuse"
}