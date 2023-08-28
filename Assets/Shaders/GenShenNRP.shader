Shader "EmptyWhite/GenShiNRP"
{
    Properties
    {
        _MapCapTex("MapCap图",2D) = "white" {}
        _BaseTex ("基础颜色图", 2D) = "white" {}
        _ShadowRampTex ("阴影映射图",2D) = "white"{}
        _LightMap ("LIM图", 2D) = "white" {}
        
        // 身体渲染
        _OcclusionRange ("闭塞范围",range(0,0.2))= 0.15
        _OcclusionDensity ("闭塞强度",range(0,1))= 0.5 
        _ShadowRange ("阴影范围",range(0,0.5))= 0.3
        _ShadowType ("阴影种类",range(0,1))= 0.95
        
        _Gloss ("金属光泽度",range(8.0,256)) = 20
        
        // 描边
        _OutlineWidth("描线宽度",Range(0,1))=0.24
        _OutLineColor("OutLine Color", Color) = (0.5,0.5,0.5,1)
        
        // 屏幕空间边缘光
        _RimColor ("边缘光颜色",Color) = (1,0,0,1)
        _RimOffect("边缘光偏差",float) = 0.005
        _Threshold("阈值",float) = 0.5
        _FresnelScale("FresnelScale",Range(0,1))=0.04
        
        
        _testFloat("测试用",float) =1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100
        
        // 主要渲染Pass
        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            
            #include "UnityCG.cginc"
            #include "CgincLib/MyCginc.cginc"
            

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float clipW : TEXCOORD1;
                float4 vertex : SV_POSITION;  // vertex
                float3 noramlWS : TEXCOORD2; //worldNormal
                float3 viewDirWS : TEXCOORD3; //worldView
                float3 reflecDirWS : TEXCOORD4;
                float3 posWS : TEXCOORD5;  // worldPos
            };

            
            sampler2D _MapCapTex;
            sampler2D _BaseTex;
            sampler2D _LightMap;
            sampler2D _ShadowRampTex;

            float _OcclusionRange;
            float _OcclusionDensity;
            float _ShadowRange;
            float _ShadowType;
            float _Gloss;
            
            float4 _RimColor;
            float  _RimOffect;
            float _Threshold;
            float _FresnelScale;

            sampler2D _SDFTex;
            float4 _shadowCol;
            float _LerpMax;
            


            float _testFloat;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);  //o.vertex = UnityObjectToClipPos(v.vertex);
                o.posWS = mul(unity_ObjectToWorld, v.vertex).xyz;  //o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.uv = v.uv;
                o.clipW = o.vertex.w;
                o.noramlWS = UnityObjectToWorldNormal(v.normal);
                o.viewDirWS = UnityWorldSpaceViewDir(o.posWS);
                o.reflecDirWS = reflect(-o.viewDirWS,o.noramlWS);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // 变量准备
                float3 normalWS = normalize(i.noramlWS);
                float3 normalVS = mul(unity_WorldToCamera, normalWS);
                float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz);
                float3 viewDirWS = normalize(i.viewDirWS);
                float3 reflecDirWS = normalize(i.reflecDirWS);
                float3 halfDir = normalize(lightDirWS+viewDirWS);

                // 纹理
                fixed4 baseCol = tex2D(_BaseTex, i.uv);
                fixed4 matCap = tex2D(_MapCapTex, normalVS.xy / 2 + 0.5);
                float4 Lim = tex2D(_LightMap, i.uv);

                float4 mainCol = baseCol;

                // 边缘光
                float depthDiffer = GetDepthDiffer(i.vertex,normalVS,_RimOffect);
                float fresnel = _FresnelScale + (1 - _FresnelScale) * pow(1 - dot(normalWS, viewDirWS), 7);
                float rimIntensity = step(_Threshold,depthDiffer);
                rimIntensity = lerp(0,rimIntensity,fresnel);
                float4 rimColor = One2Four(rimIntensity)*_RimColor;

                // 基本代码
                fixed occlusion = 1 - step(Lim.g, _OcclusionRange)*_OcclusionDensity;
                fixed3 halfLambert = saturate(dot(normalWS,lightDirWS))*0.5+0.5;
                fixed4 ShadowRamp = tex2D(_ShadowRampTex, float2(halfLambert.x+_ShadowRange,_ShadowType));
                
                // 身体渲染代码
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
                mainCol = lerp(metalCol,matcapCol,matcapRange);
                mainCol = BlendMul(occlusion,mainCol);
                

                mainCol = BlendMul(mainCol,baseCol)*ShadowRamp;

                
                
                float4 finalCol = mainCol+rimColor;
                return finalCol;
            }
            
            ENDCG
        }// 主要渲染Pass END
        
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
