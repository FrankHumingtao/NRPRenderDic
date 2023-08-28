Shader "Unlit/TangentChannel"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _OutlineWidth ("_OutlineWidth" , float) = 0.1
        _OutLineColor("outColor",Color) = (0,0,0,1)
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
            
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv1 : TEXCOORD1;
                float3 normal : NORMAL;
                float4 tangent : TANGENT;
                
            };

            struct v2f
            {
                float4 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float3 normalWS : TEXCOORD1;
                float3 normalnewWS : TEXCOORD2;
            };

            sampler2D _MainTex;


            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv.xy = v.uv;
                o.uv.zw = v.uv1;
                UNITY_TRANSFER_FOG(o,o.vertex);
                float3 worldPos = mul(unity_ObjectToWorld, v.vertex).xyz; 
                fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;

                float3x3 TBN = float3x3(worldTangent,worldBinormal,worldNormal);
                float3 newnormalTS = OctahedronToUnitVector(o.uv.zw);
                float3 newnormalWS = mul(TBN,newnormalTS);
                o.normalnewWS = newnormalWS;
                o.normalWS = worldNormal;
                
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                float3 ndirnewWS = i.normalnewWS;
                float3 ndirWS = i.normalWS;
                
                fixed4 col = tex2D(_MainTex, i.uv);
                // apply fog
                UNITY_APPLY_FOG(i.fogCoord, col);
                return float4(1,1,1,1);
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
                o.uv2 = v.uv1;
                // float3 newNormalTS = v.vertColor.xyz;
                //
                // fixed3 worldNormal = UnityObjectToWorldNormal(v.normal);
                // fixed3 worldTangent = UnityObjectToWorldDir(v.tangent.xyz);
                // fixed3 worldBinormal = cross(worldNormal, worldTangent) * v.tangent.w;
                //
                // float3x3 TBN = float3x3(worldTangent,worldBinormal,worldNormal);
                // float3 newnormalWS = mul(newNormalTS,TBN);
                
                float3 newnormalWS = v.tangent.xyz;
                
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
