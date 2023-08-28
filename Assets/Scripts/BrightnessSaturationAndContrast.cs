using UnityEngine;
using System.Collections;

public class BrightnessSaturationAndContrast : PostEffectsBase {

    public Shader briSatConShader_BLUR;
    public Shader briSatConShader_ADD;
    private Material briSatConMaterial_BLUR;
    private Material briSatConMaterial_ADD;
    public Material materialBLUR {  
        get {
            briSatConMaterial_BLUR = CheckShaderAndCreateMaterial(briSatConShader_BLUR, briSatConMaterial_BLUR);
            return briSatConMaterial_BLUR;
        }  
    }
    
    public Material materialADD {  
        get {
            briSatConMaterial_ADD = CheckShaderAndCreateMaterial(briSatConShader_ADD, briSatConMaterial_ADD);
            return briSatConMaterial_ADD;
        }  
    }

    [Range(0.0f, 3.0f)]
    public float addAlpha = 1.0f;
    
    // 模糊相关参数
    [Range(0, 4)]
    public int iterations = 3;
	
    // Blur spread for each iteration - larger value means more blur
    [Range(0.2f, 3.0f)]
    public float blurSpread = 0.6f;
	
    [Range(1, 8)]
    public int downSample = 2;
    

    void OnRenderImage(RenderTexture src, RenderTexture dest) {
        if (materialBLUR != null) {
            materialADD.SetFloat("_AddAlpha", addAlpha);
            
            int rtW = src.width/downSample;
            int rtH = src.height/downSample;

            RenderTexture buffer0 = RenderTexture.GetTemporary(rtW, rtH, 0);
            buffer0.filterMode = FilterMode.Bilinear;

            Graphics.Blit(src, buffer0);

            for (int i = 0; i < iterations; i++) {
                materialBLUR.SetFloat("_BlurSize", 1.0f + i * blurSpread);

                RenderTexture buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // Render the vertical pass
                Graphics.Blit(buffer0, buffer1, materialBLUR, 0);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
                buffer1 = RenderTexture.GetTemporary(rtW, rtH, 0);

                // Render the horizontal pass
                Graphics.Blit(buffer0, buffer1, materialBLUR, 1);

                RenderTexture.ReleaseTemporary(buffer0);
                buffer0 = buffer1;
            }
            
            materialADD.SetTexture("_BlurTex",buffer0);

            //Graphics.Blit(buffer0, dest);
            Graphics.Blit(src, dest,materialADD);
            RenderTexture.ReleaseTemporary(buffer0);
        } else {
            Graphics.Blit(src, dest);
        }
    }
}