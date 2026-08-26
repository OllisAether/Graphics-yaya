Shader "berch/Holographic"
{
  Properties
  {
    [Header(Main)]
    [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)
    [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}
    _Metallic ("Metallic", Range(0,1)) = 0
    _MetallicMap ("Metallic Mask", 2D) = "white" {}
    _SpecColor ("Specular Color", Color) = (1,1,1,1) 
    _SpecularStrength ("Specular Strength", Range(0,2)) = 1
    _Shininess ("Shinines", Float ) = 100
    _Roughness ("Roughness", Range(0,1)) = 0.35
    _Anisotropy ("Anisotropy", Range(-1,1)) = 0
    _AnisotropyTangent ("Anisotropy Tangent", Range(0,1)) = 0
    _ReflectionStrength ("Reflection Strength", Range(0,2)) = 1
    [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
    _NormalStrength ("Strength", Range(0,2)) = 1
    _HolographicMask ("Holographic Mask", 2D) = "white" {}

    _SpecularIterations ("Specular Iterations", Range(1, 10)) = 2
    _SpecularOffset ("Specular Offset", Range(0.01, 1)) = 1
    _DispersionFactor ("Dispersion Factor", Range(0.01, 1)) = 1
  }

  SubShader
  {
    Pass
    {
      Tags
      {
        "Lightmode" = "UniversalForward"
      }

      HLSLPROGRAM

      #pragma vertex vert
      #pragma fragment frag

      #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
      #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
      #pragma multi_compile _ _SHADOWS_SOFT

      #pragma multi_compile _ _ADDITIONAL_LIGHTS
      #pragma multi_compile _ _CLUSTER_LIGHT_LOOP
      #pragma multi_compile_fragment _ _ADDITIONAL_LIGHTS_SHADOWS
      #pragma multi_compile_fragment _ _ENVIRONMENTREFLECTIONS_OFF
      #pragma multi_compile_fragment _ _REFLECTION_PROBE_BLENDING
      #pragma multi_compile_fragment _ _REFLECTION_PROBE_BOX_PROJECTION
      #pragma multi_compile_fragment _ _REFLECTION_PROBE_ATLAS
      #pragma multi_compile_fragment _ REFLECTION_PROBE_ROTATION

      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
      #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

      CBUFFER_START(UnityPerMaterial)
        float4 _BaseColor;
        float _Metallic;
        float _ReflectionStrength;
        float4 _SpecColor;
        float _SpecularStrength;
        float _Shininess;
        float _Roughness;
        float _Anisotropy;
        float _AnisotropyTangent;
        float _NormalStrength;

        float4 _BaseMap_ST;
        float4 _NormalMap_ST;
        float4 _HolographicMask_ST;
        float4 _MetallicMap_ST;

        float _SpecularIterations;
        float _SpecularOffset;
        float _DispersionFactor;
      CBUFFER_END

      TEXTURE2D(_BaseMap);
      SAMPLER(sampler_BaseMap);

      TEXTURE2D(_NormalMap);
      SAMPLER(sampler_Normal    TEXTURE2D(_HolographicMask);
      SAMPLER(sampler_HolographicMask);

      TEXTURE2D(_MetallicMap);
      SAMPLER(sampler_MetallicMap);

      struct Attributes
      {
        float3 positionOS : POSITION;
        float3 normalOS : NORMAL;
        float2 uv : TEXCOORD0;
        float4 tangentOS : TANGENT;
      };

      struct Varyings
      {
        float4 positionCS : SV_POSITION;
        float2 uv           : TEXCOORD0;
        float2 maskUV       : TEXCOORD6;
        float2 metallicUV   : TEXCOORD7;
        float3 positionWS   : TEXCOORD1;
        float3 normalWS     : TEXCOORD2;
        float3 tangentWS    : TEXCOORD3;
        float3 bitangentWS  : TEXCOORD4;
        float4 shadowCoord  : TEXCOORD5; 
      };


      Varyings vert(Attributes input)
      {
        Varyings output;

        // Get the position of the vertex in different spaces
        VertexPositionInputs positions = GetVertexPositionInputs(input.positionOS.xyz);
        VertexNormalInputs normals = GetVertexNormalInputs(input.normalOS, input.tangentOS);

        output.positionCS = positions.positionCS;
        output.positionWS = positions.positionWS;
        output.normalWS =    normals.normalWS;
        output.tangentWS = normals.tangentWS;
        output.bitangentWS = normals.bitangentWS;
        output.uv = TRANSFORM_TEX(input.uv, _BaseMap);
        output.maskUV = TRANSFORM_TEX(input.uv, _HolographicMask);
        output.metallicUV = TRANSFORM_TEX(input.uv, _MetallicMap);
        output.shadowCoord = GetShadowCoord(positions);

        return output;
      }

      float3 DecodeNormalMap(float2 uv)
      {
        float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, uv);
        float3 normalTS = UnpackNormalScale(packedNormal, _NormalStrength);

        return normalize(normalTS);
      }

      float3 TangentToWorld(
        float3 normalTS,
        float3 tangentWS,
        float3 bitangentWS,
        float3 normalWS
      )
      {
        float3x3 tangentToWorld = float3x3( 
          normalize(tangentWS),
          normalize(bitangentWS),
          normalize(normalWS)
        );

        return normalize(mul(normalTS, tangentToWorld));
      }

      float3 AnisotropicReflectionDirection(
        float3 reflectionDirection,
        float3 tangentWS,
        float3 bitangentWS,
        float3 normalWS
      )
      {
        float3 tangent = normalize(tangentWS);
        float3 bitangent = normalize(bitangentWS);
        float3 normal = normalize(normalWS);
        float tangentAngle = _AnisotropyTangent * 6.28318530718;
        float sine = sin(tangentAngle);
        float cosine = cos(tangentAngle);
        float3 anisotropyTangent = normalize(tangent * cosine + bitangent * sine);
        float3 anisotropyBitangent = normalize(-tangent * sine + bitangent * cosine);
        float3 reflectionTS = float3(
          dot(reflectionDirection, anisotropyTangent),
          dot(reflectionDirection, anisotropyBitangent),
          dot(reflectionDirection, normal)
        );
        float tangentRoughness = max(0.05, 1.0 + _Anisotropy);
        float bitangentRoughness = max(0.05, 1.0 - _Anisotropy);

        reflectionTS.xy /= float2(tangentRoughness, bitangentRoughness);
        return normalize(
          reflectionTS.x * anisotropyTangent +
          reflectionTS.y * anisotropyBitangent +
          reflectionTS.z * normal
        );
      }

      float3 CalculateSpecularReflection(
        float3 normalWS,
        float3 tangentWS,
        float3 bitangentWS,
        float3 viewDirWS,
        float3 LightDirWS,
        float3 LightColor,
        float attenuation,
        float3 specularColor
      )
      {
        float3 reflectionDir = reflect(-LightDirWS, normalWS);
        reflectionDir = AnisotropicReflectionDirection(
          reflectionDir,
          tangentWS,
          bitangentWS,
          normalWS
        );
        float specularPower = max(1.0, _Shininess * (1.0 - _Roughness));
          
        return attenuation * LightColor * specularColor *
          pow(max(0.0, dot(reflectionDir, viewDirWS)), specularPower);
      }

      float3 CalculateSpecularReflectionWithOffset(
        float3 normalWS,
        float3 normalTS,
        Varyings input,
        float3 viewDirWS,
        float3 LightDirWS,
        float3 LightColor,
        float attenuation,
        float2 offset,
        float3 specularColor
      )
      {
        float3 offsetNormalTS = normalize(normalTS + float3(offset, 0));
        float3 offsetNormalWS = TangentToWorld(
          offsetNormalTS,
          normalize(input.tangentWS),
          normalize(input.bitangentWS),
          normalize(input.normalWS)
        );

        return CalculateSpecularReflection(
          offsetNormalWS,
          input.tangentWS,
          input.bitangentWS,
          viewDirWS,
          LightDirWS,
          LightColor,
          attenuation,
          specularColor
        );
      }

      float3 CalculateEnvironmentReflectionWithOffset(
        float3 normalTS,
        Varyings input,
        float3 viewDirWS,
        float perceptualRoughness,
        float3 reflectionColor,
        float2 offset
      )
      {
        float3 offsetNormalTS = normalize(normalTS + float3(offset, 0));
        float3 offsetNormalWS = TangentToWorld(
          offsetNormalTS,
          normalize(input.tangentWS),
          normalize(input.bitangentWS),
          normalize(input.normalWS)
        );
        float3 reflectionDirection = reflect(-viewDirWS, offsetNormalWS);
          if (abs(_Anisotropy) > 0.001)
          {
            reflectionDirection = AnisotropicReflectionDirection(
              reflectionDirection,
              input.tangentWS,
              input.bitangentWS,
              offsetNormalWS
            );
          }

        return GlossyEnvironmentReflection(
          reflectionDirection,
          input.positionWS,
          perceptualRoughness,
          1.0,
          GetNormalizedScreenSpaceUV(input.positionCS)
        ) * reflectionColor * _ReflectionStrength;
      }

      float3 CalculateLight(
        float3 normalWS,
        float3 normalTS,
        Varyings input,
        float3 viewDirWS,
        float3 LightDirWS,
        float3 LightColor,
        float attenuation,
        float3 albedo,
        float metallic,
        float holographicMask
      )
      {
        float NDotL = dot(normalWS, LightDirWS);
        float3 specularF0 = lerp(_SpecColor.rgb * 0.04, albedo, metallic);
        float3 specularColor = specularF0 * _SpecularStrength;

        float3 DiffRefl = attenuation * LightColor * albedo * (1.0 - metallic) * max(0.0,NDotL);

        float3 SpecRefl = float3(0,0,0);

        if (NDotL >= 0)
        {
          for (int x = -_SpecularIterations; x <= _SpecularIterations; x++)
          {
            for (int y = -_SpecularIterations; y <= _SpecularIterations; y++)
            {
              float2 offset = float2(x, y) * _SpecularOffset;
              float gaussianWeight = exp(-dot(offset, offset) / (2 * _SpecularOffset * _SpecularOffset)) / (2 * 3.14159265359 * _SpecularOffset * _SpecularOffset);

              SpecRefl += float3(
                CalculateSpecularReflectionWithOffset(
                  normalWS,
                  normalTS,
                  input,
                  viewDirWS,
                  LightDirWS,
                  LightColor,
                  attenuation,
                  offset * (1 + _DispersionFactor),
                  specularColor
                ).r,
                CalculateSpecularReflectionWithOffset(
                  normalWS,
                  normalTS,
                  input,
                  viewDirWS,
                  LightDirWS,
                  LightColor,
                  attenuation,
                  offset,
                  specularColor
                ).g,
                CalculateSpecularReflectionWithOffset(
                  normalWS,
                  normalTS,
                  input,
                  viewDirWS,
                  LightDirWS,
                  LightColor,
                  attenuation,
                  offset * (1 - _DispersionFactor),
                  specularColor
                ).b
              ) * gaussianWeight;
            }
          }
        }

        return DiffRefl + SpecRefl * holographicMask;
      }

      float4 frag(Varyings input) : SV_TARGET
      {
        float3 normalTS = DecodeNormalMap(input.uv);

        float3 normalWS = TangentToWorld(
          normalTS,
          input.tangentWS,
          input.bitangentWS,
          input.normalWS
        );

        float3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

        float4 baseColor = SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, input.uv) * _BaseColor;
        float metallic = _Metallic * SAMPLE_TEXTURE2D(
          _MetallicMap,
          sampler_MetallicMap,
          input.metallicUV
        ).r;
        float holographicMask = SAMPLE_TEXTURE2D(
          _HolographicMask,
          sampler_HolographicMask,
          input.maskUV
        ).r;
        float3 ambientLight = SampleSH(input.positionWS) * baseColor.rgb * (1.0 - metallic);
        float perceptualRoughness = _Roughness;
        float3 specularF0 = lerp(_SpecColor.rgb * 0.04, baseColor.rgb, metallic);
        float viewFresnel = pow(1.0 - saturate(dot(normalWS, viewDirWS)), 5.0);
        float3 reflectionColor = (specularF0 + (1.0 - specularF0) * viewFresnel) * _SpecularStrength;
        float3 environmentReflection = float3(0, 0, 0);

        for (int x = -_SpecularIterations; x <= _SpecularIterations; x++)
        {
          for (int y = -_SpecularIterations; y <= _SpecularIterations; y++)
          {
            float2 offset = float2(x, y) * _SpecularOffset;
            float gaussianWeight = exp(-dot(offset, offset) / (2 * _SpecularOffset * _SpecularOffset)) / (2 * 3.14159265359 * _SpecularOffset * _SpecularOffset);
            float distance = length(offset);

            environmentReflection += float3(
              CalculateEnvironmentReflectionWithOffset(
                normalTS,
                input,
                viewDirWS,
                min(perceptualRoughness + distance * _DispersionFactor, 1),
                reflectionColor,
                offset * (1 + _DispersionFactor)
              ).r,
              CalculateEnvironmentReflectionWithOffset(
                normalTS,
                input,
                viewDirWS,
                min(perceptualRoughness + distance * _DispersionFactor, 1),
                reflectionColor,
                offset
              ).g,
              CalculateEnvironmentReflectionWithOffset(
                normalTS,
                input,
                viewDirWS,
                min(perceptualRoughness + distance * _DispersionFactor, 1),
                reflectionColor,
                offset * (1 - _DispersionFactor)
              ).b
            ) * gaussianWeight;
          }
        }

        float3 finalColor = ambientLight + environmentReflection * holographicMask;

        //Main Light
        Light mainLight = GetMainLight(input.shadowCoord);

        finalColor += CalculateLight(
          normalWS,
          normalTS,
          input,
          viewDirWS,
          normalize(mainLight.direction),
          mainLight.color, 
          mainLight.distanceAttenuation * mainLight.shadowAttenuation,
          baseColor.rgb,
          metallic,
          holographicMask
        );

        // Additional Lights
        #ifdef _ADDITIONAL_LIGHTS

        uint additionalLightCount = GetAdditionalLightsCount();

        #if USE_CLUSTER_LIGHT_LOOP
          InputData inputData = (InputData)0;
          inputData.positionWS = input.positionWS;
          inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
        #endif

        LIGHT_LOOP_BEGIN(additionalLightCount)
        {
          #if !USE_CLUSTER_LIGHT_LOOP
            lightIndex = GetPerObjectLightIndex(lightIndex);
          #endif

          Light light = GetAdditionalPerObjectLight(lightIndex, input.positionWS);

          finalColor += CalculateLight(
            normalWS,
            normalTS,
            input,
            viewDirWS,
            normalize(light.direction),
            light.color,
            light.distanceAttenuation * light.shadowAttenuation,
            baseColor.rgb,
            metallic,
            holographicMask
          );
        }
        LIGHT_LOOP_END

        #endif

        return float4(finalColor, _BaseColor.a);
      }
      ENDHLSL
    }

    Pass
    {
      Name "ShadowCaster"
      Tags { "LightMode" = "ShadowCaster" }

      ZWrite On
      ZTest LEqual
      ColorMask 0

      HLSLPROGRAM

      #pragma vertex ShadowPassVertex
      #pragma fragment ShadowPassFragment

      #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW

      #include "Packages/com.unity.render-pipelines.universal/Shaders/ShadowCasterPass.hlsl"

      ENDHLSL
    }
  }

}
