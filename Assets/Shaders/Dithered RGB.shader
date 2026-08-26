Shader "berch/Dithered RGB"
{
  Properties
  {
    [MainColor] _Color("Color", Color) = (1, 1, 1, 1)
  
    _Scale("World Scale", Float) = 1
    _Opacity("Opacity", Range(0, 1)) = 1
    _Offset("Discard Y Coordinate", Float) = 0
    _DitherDensity("Dither Density", Int) = 1
    _FadeScale("Fade Scale", Float) = 1
  }

  SubShader
  {
    Tags 
    {
      "RenderType"="Transparent"
      "Queue"="Transparent"
    }

    Pass
    {
      Blend SrcAlpha OneMinusSrcAlpha
      ZWrite On
      
      HLSLPROGRAM

      // Define the entry point of the vertex and fragment shader
      #pragma vertex vert
      #pragma fragment frag

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

      struct Varyings {
        float4 position : SV_POSITION;
        float3 color : TEXCOORD0;
        float4 localPos : TEXCOORD1;
      };

      CBUFFER_START(UnityPerMaterial)
        float _Scale;
        float4 _Color;
        float _Opacity;
        float _Offset;
        int _DitherDensity;
        float _FadeScale;
      CBUFFER_END

      Varyings vert(float4 vertexpos : POSITION)
      {
        Varyings output;
        
        output.position = TransformObjectToHClip(vertexpos.xyz);
        output.color = TransformObjectToWorld(vertexpos.xyz).xyz * _Scale;
        output.localPos = vertexpos;

        return output;
      }

      float getDitherValue(float2 screenPos)
      {
        int x = (int)screenPos.x % 4;
        int y = (int)screenPos.y % 4;

        float4x4 bayerIndex = float4x4(
          float4(00.0/16.0, 12.0/16.0, 03.0/16.0, 15.0/16.0),
          float4(08.0/16.0, 04.0/16.0, 11.0/16.0, 07.0/16.0),
          float4(02.0/16.0, 14.0/16.0, 01.0/16.0, 13.0/16.0),
          float4(10.0/16.0, 06.0/16.0, 09.0/16.0, 05.0/16.0));

        return bayerIndex[y][x];
      }

      float4 frag(Varyings input) : SV_TARGET
      {
        clip(_Offset - input.localPos.y * _FadeScale - getDitherValue(input.position.xy / _DitherDensity));

        return float4(input.color, _Opacity) * _Color;
      }

      ENDHLSL
    }
  }
}
