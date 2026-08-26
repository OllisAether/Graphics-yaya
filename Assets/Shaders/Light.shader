Shader "berch/Light"
{
  Properties
  {
    [MainColor] _Color("Color", Color) = (1, 1, 1, 1)
  }

  SubShader
  {
    Tags 
    {
      "LightMode"="UniversalForward"
    }

    Pass
    {
      HLSLPROGRAM

      // Define the entry point of the vertex and fragment shader
      #pragma vertex vert
      #pragma fragment frag

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

      struct Attributes {
        float4 positionOS : POSITION;
        float4 normalOS : NORMAL;
      };

      struct Varyings {
        float4 positionHCS : SV_POSITION;
        float3 normal : TEXCOORD0;
      };

      CBUFFER_START(UnityPerMaterial)
        float4 _Color;
      CBUFFER_END

      Varyings vert(Attributes input)
      {
        Varyings output;

        output.positionHCS = TransformObjectToHClip(input.positionOS);
        output.normal = normalize(TransformObjectToWorldNormal(input.normalOS).xyz);

        return output;
      }

      float4 frag(Varyings input) : SV_TARGET
      {
        Light mainLight = GetMainLight();

        half normalDotLight = saturate(dot(input.normal, mainLight.direction));
        return float4(_Color.rgb * mainLight.color * normalDotLight, _Color.a);
      }

      ENDHLSL
    }
  }
}