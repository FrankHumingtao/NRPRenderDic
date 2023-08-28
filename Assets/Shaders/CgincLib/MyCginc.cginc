#ifndef MY_SHADER_UTILS_H
#define MY_SHADER_UTILS_H


#include "UnityCG.cginc"

sampler2D  _CameraDepthTexture ;

// PS图层效果区
// 叠加效果
fixed4 BlendAdd(fixed4 baseColor, fixed4 blendColor) {
    return baseColor + blendColor * blendColor.a;
}
// 强光效果 使用了step函数, 避免了使用if的情况。
fixed4 BlendHardLight(fixed4 baseColor, fixed4 blendColor)
{
    float stepValue = step(0.5,blendColor.r);
    return lerp(2 * baseColor * blendColor, 1 - 2 * (1 - baseColor) * (1 - blendColor), stepValue);
}
//正片叠底效果 这个一半简单不用专门写一个函数,我为了明确我是在做正片叠底效果所以封装了一个函数
fixed4 BlendMul(fixed4 baseColor, fixed4 blendColor)
{
    return baseColor*blendColor;
}

float GetDepthDiffer(float4 vertex,float3 normalVS,float Offect)
{
    float2 screenParams01 = float2(vertex.x/_ScreenParams.x,vertex.y/_ScreenParams.y);

    float2 offectSamplePos = screenParams01 + normalVS.xx* Offect;
    float offcetDepth = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, offectSamplePos);
    float trueDepth   = SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, screenParams01);

    float linear01EyeOffectDepth = Linear01Depth(offcetDepth);
    float linear01EyeTrueDepth = Linear01Depth(trueDepth);
    float depthDiffer = linear01EyeOffectDepth - linear01EyeTrueDepth;

    return depthDiffer;
}


// 用于方便测试的函数
fixed4 One2Four(fixed one)
{
    return fixed4(one,one,one,1);
}
fixed4 Three2Four(fixed3 three)
{
    return fixed4(three,1);
}
fixed3 One2Three(fixed one)
{
    return fixed3(one,one,one);
}



#endif

