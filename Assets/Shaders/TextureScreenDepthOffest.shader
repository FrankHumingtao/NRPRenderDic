Shader "Texture/ScreenDepthOffest"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color",Color) = (1,0,0,1)
        _RimOffect("RimOffect",float) = 1
        _Threshold("Threshold",float) = 1
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
            
            
            struct v2f
            {
             float2 uv : TEXCOORD0;
             float clipW :TEXCOORD1;
             float4 vertex : SV_POSITION;
             float3 N_WS : TEXCOORD2;
            };

             sampler2D _MainTex;
             //sampler2D _CameraDepthTexture;

             float4 _MainTex_ST;
             float4 _Color;
             float  _RimOffect;
             float _Threshold;


             v2f vert (appdata_full v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
                o.clipW = o.vertex.w ;                       //有人也写作SrcPos

                o.N_WS = UnityObjectToWorldNormal(v.normal);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
             float3 N_WS = normalize(i.N_WS);
             float3 N_VS = mul(unity_WorldToCamera, N_WS);
             // float3 N_VS = normalize(mul((float3x3)UNITY_MATRIX_V, N_WS));
             //1920*1080的屏幕坐标映射到0到1，需要对坐标的x和y分别除以1920和1080，回归到未拉伸状态
             //_ScreenParams的xy分量记录的就是屏幕的像素宽度和高度
             // float2 screenParams01 = float2(i.vertex.x/_ScreenParams.x,i.vertex.y/_ScreenParams.y);
             //
             // //_RimOffect/i.clipW，这里除w就是手动的透视除法，还要除以_ScreenParams.x 
             // float2 offectSamplePos = screenParams01 + N_VS.xy * _RimOffect ;//float2(_RimOffect/i.clipW,0);
             // float offcetDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offectSamplePos);
             // float trueDepth   = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenParams01);
             //
             // float linear01EyeOffectDepth = Linear01Depth(offcetDepth);
             // float linear01EyeTrueDepth = Linear01Depth(trueDepth);
             float depthDiffer = GetDepthDiffer(i.vertex,N_VS,_RimOffect);
             float rimIntensity = step(_Threshold,depthDiffer);
            float4 rimcol = float4(rimIntensity,rimIntensity,rimIntensity,1)*_Color;

            float4 mainCol = tex2D(_MainTex,i.uv);
            mainCol = mainCol+rimcol;
            // float4 col = float4(rimIntensity,rimIntensity,rimIntensity,1);
            return mainCol;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}
