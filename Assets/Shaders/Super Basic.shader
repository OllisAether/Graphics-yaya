Shader "berch/Super Basic"
{
  SubShader
  {
    Pass
    {
      HLSLPROGRAM

      // Define the entry point of the vertex and fragment shader
      #pragma vertex vert
      #pragma fragment frag

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

      float4 vert(float4 vertexpos : POSITION) : SV_POSITION
      {
        return TransformObjectToHClip(vertexpos.xyz * (sin(_Time * 10) * 0.3 + 0.7));
      }

      float4 hsv2rgb(float4 hsv) : COLOR {
          float r;
          float g;
          float b;
          float h = hsv.x;
          float s = hsv.y;
          float v = hsv.z;

          int i = floor(h / 60.0);
          float f = h / 60.0 - i;
          float p = v * (1 - s);
          float q = v * (1 - f * s);
          float t = v * (1 - (1 - f) * s);

          if (i % 6 == 0) { r = v, g = t, b = p; }
          else if (i % 6 == 1) { r = q, g = v, b = p; }
          else if (i % 6 == 2) { r = p, g = v, b = t; }
          else if (i % 6 == 3) { r = p, g = q, b = v; }
          else if (i % 6 == 4) { r = t, g = p, b = v; }
          else if (i % 6 == 5) { r = v, g = p, b = q; }

          return float4(r, g, b, 1);
      }

      float4 frag() : COLOR
      {
        return hsv2rgb(float4(0, 1, 1, 0) + float4(1, 0, 0, 0) * ((_Time * 10000) % 360));
      }
      ENDHLSL
    }
  }
}
