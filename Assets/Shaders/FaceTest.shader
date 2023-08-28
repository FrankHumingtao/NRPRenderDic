Shader "EmptyWhite/FaceTest"
{
    Properties
    {
        _SDFTex ("SDF图", 2D) = "white" {}
        _BaseTex ("_BaseTex", 2D) = "white" {}
        _shadowCol ("_shadowCol",Color) = (1,1,1,1)
        _ShadowRampTex ("阴影映射图",2D) = "white"{}
        _LerpMax ("lerpmax",float) = 1
        
        // 描边
        _OutlineWidth("描线宽度",Range(0,1))=0.24
        _OutLineColor("OutLine Color", Color) = (0.5,0.5,0.5,1)
        
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
                
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _SDFTex;
            sampler2D _ShadowRampTex;
            float4 _shadowCol;
            sampler2D _BaseTex;
            float _LerpMax;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = v.uv;
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {

                
                half4 baseTex = tex2D(_BaseTex,i.uv);
                
                float3 lightDirWS = normalize(_WorldSpaceLightPos0.xyz);
                fixed3 frontDir = normalize(UnityObjectToWorldDir(float3(0,0,1)));
                fixed3 upDir = normalize(UnityObjectToWorldDir(float3(0,1,0)));
                float3 Left = normalize(cross(upDir, frontDir));

                float FrontDotL = -dot(frontDir,lightDirWS);
                float LeftDotL = dot(Left,lightDirWS);

                // 用step避开if判断语句
                float3 faceUV_ST = lerp(float3(1,1,1),float3(0,-1,1),step(LeftDotL,0));
                float4 SDFTex = tex2D(_SDFTex,float2((faceUV_ST.x-i.uv.x)*faceUV_ST.y,i.uv.y));
                SDFTex = step(SDFTex,FrontDotL);
                
                float4 finalCol= lerp(baseTex,baseTex*_shadowCol,SDFTex);
                
                return finalCol;
                
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
}
