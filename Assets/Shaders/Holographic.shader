Shader "berch/Holographic"
{
  Properties
  {
    [Header(Main Surface Properties)]
    [MainColor] _BaseColor ("Base Color", Color) = (1, 1, 1, 1)
    [NoScaleOffset][MainTexture] _BaseMap ("Base Map", 2D) = "white" {}

    [Header(Metallic Properties)]
    _Metallic ("Metallic", Range(0, 1)) = 0
    [NoScaleOffset]_MetallicMap ("Metallic Map", 2D) = "white" {}

    [Header(Roughness Properties)]
    _Roughness ("Roughness", Range(0, 1)) = 0.35
    [NoScaleOffset]_RoughnessMap ("Roughness Map", 2D) = "white" {}
    _Shininess ("Shininess", Range(0, 1)) = 1

    [Header(Normal Properties)]
    [NoScaleOffset][Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
    _NormalStrength ("Strength", Range(0, 2)) = 1

    [Header(Fresnel Properties)]
    _FresnelStrength ("Fresnel Strength", Range(0, 2)) = 1
    _FresnelPower ("Fresnel Power", Range(1, 8)) = 5

    [Header(Holographic Coat)]
    _HoloStrength ("Holographic Strength", Range(0, 1)) = 1
    [NoScaleOffset]_HoloMap ("Holographic Map", 2D) = "white" {}

    [Header(Holographic Normal Properties)]
    [NoScaleOffset][Normal]_HoloNormalMap ("Holographic Normal Map", 2D) = "bump" {}
    _HoloNormalStrength ("Holographic Normal Strength", Range(0, 2)) = 1

    [Header(Holographic Specular Properties)]
    _HoloRoughness ("Holographic Roughness", Range(0, 1)) = 0.35
    [NoScaleOffset]_HoloRoughnessMap ("Holographic Roughness Map", 2D) = "white" {}

    [Space(10)]
    _Anisotropy ("Holo Anisotropy", Range(-1, 1)) = 0
    _AnisotropyRotation ("Holo Anisotropy Rotation", Range(0,1)) = 0

    // [Space(10)]
    // _EnvironmentReflectionStrength ("Environment Reflection Strength", Range(0, 2)) = 1

    [Header(Holographic Iteration Properties)]
    _HoloIterations ("Holographic Iterations", Int) = 1
    _HoloOffset ("Holographic Offset", Range(0.01, 1)) = 1
    [Space(10)]
    _DispersionIterations ("Dispersion Iterations", Int) = 3
    _DispersionFactor ("Dispersion Factor", Range(0, 5)) = 1
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
        float4 _BaseMap_ST;

        float _Metallic;
        float4 _MetallicMap_ST;

        float _Roughness;
        float4 _RoughnessMap_ST;

        float _Shininess;

        float4 _NormalMap_ST;
        float _NormalStrength;

        float _FresnelStrength;
        float _FresnelPower;

        // Holographic Properties
        float _HoloStrength;
        float4 _HoloMap_ST;

        float _HoloRoughness;
        float4 _HoloRoughnessMap_ST;

        float4 _HoloNormalMap_ST;
        float _HoloNormalStrength;

        float _Anisotropy;
        float _AnisotropyRotation;

        // float _EnvironmentReflectionStrength;

        int _HoloIterations;
        float _HoloOffset;
        int _DispersionIterations;
        float _DispersionFactor;
      CBUFFER_END

      TEXTURE2D(_BaseMap);
      SAMPLER(sampler_BaseMap);

      TEXTURE2D(_MetallicMap);
      SAMPLER(sampler_MetallicMap);

      TEXTURE2D(_RoughnessMap);
      SAMPLER(sampler_RoughnessMap);

      TEXTURE2D(_NormalMap);
      SAMPLER(sampler_NormalMap);

      TEXTURE2D(_HoloMap);
      SAMPLER(sampler_HoloMap);

      TEXTURE2D(_HoloRoughnessMap);
      SAMPLER(sampler_HoloRoughnessMap);

      TEXTURE2D(_HoloNormalMap);
      SAMPLER(sampler_HoloNormalMap);

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

        output.uv = input.uv;
        output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);

        return output;
      }

      float3 DecodeNormalMap(float2 uv)
      {
        float4 packedNormal = SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv);
        float3 normalTS = UnpackNormalScale(packedNormal, _NormalStrength);

        return normalize(normalTS);
      }


      float3 DecodeHoloNormalMap(float2 uv)
      {
        float4 packedNormal = SAMPLE_TEXTURE2D(_HoloNormalMap, sampler_HoloNormalMap, uv);
        float3 normalTS = UnpackNormalScale(packedNormal, _HoloNormalStrength);

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

      float3 OffsetHoloDirection(
        float3 directionWS,
        float3 normalWS,
        float2 offset
      )
      {
        float angle = _AnisotropyRotation * 6.2831853;
        float sine = sin(angle);
        float cosine = cos(angle);
        float2 rotatedOffset = float2(
          offset.x * cosine - offset.y * sine,
          offset.x * sine + offset.y * cosine
        );
        rotatedOffset *= float2(
          1.0 + _Anisotropy,
          1.0 - _Anisotropy
        );
        rotatedOffset = float2(
          rotatedOffset.x * cosine + rotatedOffset.y * sine,
          -rotatedOffset.x * sine + rotatedOffset.y * cosine
        );

        float3 referenceAxis = abs(normalWS.y) < 0.999 ?
          float3(0, 1, 0) : float3(1, 0, 0);
        float3 offsetTangent = normalize(cross(referenceAxis, normalWS));
        float3 offsetBitangent = normalize(cross(normalWS, offsetTangent));

        return normalize(
          directionWS +
          offsetTangent * rotatedOffset.x +
          offsetBitangent * rotatedOffset.y
        );
      }

      // Isolated specular reflection calculation
      float3 CalculateSpecularReflection(
        Light light,
        float3 normalWS,
        float3 viewDirWS,
        float3 specularLightDirection,
        float3 albedo,
        float metallic,
        float roughness
      )
      {
        BRDFData brdfData;
        half alpha = 1.0;
        InitializeBRDFData(
          albedo,
          saturate(metallic),
          float3(0.04, 0.04, 0.04),
          1.0 - saturate(roughness),
          alpha,
          brdfData
        );

        half NDotL = saturate(dot(normalWS, light.direction));
        half specularTerm = DirectBRDFSpecular(
          brdfData,
          normalWS,
          specularLightDirection,
          viewDirWS
        );

        return light.distanceAttenuation * light.shadowAttenuation *
          light.color * brdfData.specular * specularTerm * NDotL;
      }

      float3 CalculateEnvironmentReflection(
        Varyings input,
        float3 normalWS,
        float3 viewDirWS,
        float3 reflectionDirection,
        float roughness,
        float3 albedo,
        float metallic
      )
      {
        float3 f0 = lerp(
          float3(0.04, 0.04, 0.04),
          albedo,
          saturate(metallic)
        );

        float fresnelTerm = pow(
          1.0 - saturate(dot(normalWS, viewDirWS)),
          _FresnelPower
        );

        float3 fresnelColor = f0 +
          (1.0 - f0) * fresnelTerm * _FresnelStrength;

        return GlossyEnvironmentReflection(
          reflectionDirection,
          input.positionWS,
          saturate(roughness),
          1.0,
          GetNormalizedScreenSpaceUV(input.positionCS)
        ) * fresnelColor;
      }

      // Holographic coat calculation
      // The juice happens here, where we calculate the holographic effect.
      float3 CalculateHoloCoat(
        Varyings input,
        Light light,
        float3 normalWS,
        float3 viewDirWS,
        float3 albedo,
        float metallic,
        float roughness
      )
      {
        float3 holoCoat = float3(0,0,0);

        // === Sample Textures ===
        float holoStrength = _HoloStrength * SAMPLE_TEXTURE2D(
          _HoloMap,
          sampler_HoloMap,
          TRANSFORM_TEX(input.uv, _HoloMap)
        ).r;

        float holoRoughness = _HoloRoughness * SAMPLE_TEXTURE2D(
          _HoloRoughnessMap,
          sampler_HoloRoughnessMap,
          TRANSFORM_TEX(input.uv, _HoloRoughnessMap)
        ).r;

        float3 holoNormalTS = DecodeHoloNormalMap(
          TRANSFORM_TEX(input.uv, _HoloNormalMap)
        );

        float3 holoNormalWSOffset = TangentToWorld(
          holoNormalTS,
          input.tangentWS,
          input.bitangentWS,
          input.normalWS
        );
        // ============

        float reflectionStrength = 1.0 /
          ((1.0 + _HoloIterations * 2.0) * (1.0 + _HoloIterations * 2.0) * (1.0 + _DispersionIterations));

        for(int x = -_HoloIterations; x <= _HoloIterations; x++)
        {
          for(int y = -_HoloIterations; y <= _HoloIterations; y++)
          {
            // Prevent the center reflection from being calculated multiple times
            int dispersionIterations = lerp(1, _DispersionIterations, saturate(abs(x) + abs(y)));

            // Calculate the dispersion effect by iterating,
            // giving each iteration a different offset and color based on the iteration index
            for (int i = 0; i < dispersionIterations; i++)
            {
              float t = (float)i / (float)(dispersionIterations);
              float dispersionOffset = t * _DispersionFactor;

              float2 offset = float2(x, y) * (_HoloOffset * (1 + dispersionOffset));

              float3 holoLightDirection = OffsetHoloDirection(
                light.direction,
                input.normalWS,
                offset
              );

              float3 dispersionColor = lerp(float3(1, 1, 1), float3(
                saturate(abs(3 - t * 6) - 1),
                saturate(-abs(t * 6 - 2) + 2),
                saturate(-abs(t * 6 - 4) + 2)
              ), saturate(dispersionIterations - 1));

              holoCoat += CalculateSpecularReflection(
                light,
                holoNormalWSOffset,
                viewDirWS,
                holoLightDirection,
                float4(1, 1, 1, 1),
                1.0,
                saturate(holoRoughness * (1.0 + length(offset)))
              ) * reflectionStrength * dispersionColor;

              // holoCoat += CalculateEnvironmentReflection(
              //   input,
              //   holoNormalWSOffset,
              //   viewDirWS,
              //   OffsetHoloDirection(
              //     reflect(-viewDirWS, holoNormalWSOffset),
              //     input.normalWS,
              //     offset
              //   ),
              //   saturate(holoRoughness * (1.0 + length(offset))),
              //   float4(1, 1, 1, 1),
              //   1.0
              // ) * reflectionStrength * dispersionColor * _EnvironmentReflectionStrength;
            }
          }
        }

        return holoCoat * holoStrength;
      }

      float3 CalculateLight(
        Varyings input,
        Light light,
        float3 normalWS,
        float3 viewDirWS,
        float3 albedo,
        float metallic,
        float roughness
      )
      {
        float NDotL = dot(normalWS, light.direction);

        float3 DiffRefl = light.distanceAttenuation * light.shadowAttenuation *
          light.color * albedo * (1.0 - metallic) * max(0.0, NDotL);

        float3 SpecRefl = float3(0,0,0);

        if (NDotL >= 0)
        {
          SpecRefl = CalculateSpecularReflection(
            light,
            normalWS,
            viewDirWS,
            light.direction,
            albedo,
            metallic,
            roughness
          ) * _Shininess;
        }

        float3 holoCoat = CalculateHoloCoat(
          input,
          light,
          normalWS,
          viewDirWS,
          albedo,
          metallic,
          roughness
        );

        return DiffRefl + SpecRefl + holoCoat;
      }

      float4 frag(Varyings input) : SV_TARGET
      {
        float3 normalTS = DecodeNormalMap(TRANSFORM_TEX(input.uv, _NormalMap));
        float3 normalWS = TangentToWorld(
          normalTS,
          input.tangentWS,
          input.bitangentWS,
          input.normalWS
        );

        float3 viewDirWS = normalize(GetWorldSpaceViewDir(input.positionWS));

        float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D(
          _BaseMap,
          sampler_BaseMap,
          TRANSFORM_TEX(input.uv, _BaseMap)
        );

        float metallic = _Metallic * SAMPLE_TEXTURE2D(
          _MetallicMap,
          sampler_MetallicMap,
          TRANSFORM_TEX(input.uv, _MetallicMap)
        ).r;

        float roughness = _Roughness * SAMPLE_TEXTURE2D(
          _RoughnessMap,
          sampler_RoughnessMap,
          TRANSFORM_TEX(input.uv, _RoughnessMap)
        ).r;

        float3 ambientDiffuse = SampleSH(normalWS) * baseColor.rgb * (1.0 - metallic);
        float3 environmentReflection = CalculateEnvironmentReflection(
          input,
          normalWS,
          viewDirWS,
          reflect(-viewDirWS, normalWS),
          roughness,
          baseColor.rgb,
          metallic
        ) * _Shininess;

        float3 finalColor = ambientDiffuse + environmentReflection;

        //Main Light
        Light mainLight = GetMainLight(input.shadowCoord);

        finalColor += CalculateLight(
          input,
          mainLight,
          normalWS,
          viewDirWS,
          baseColor.rgb,
          metallic,
          roughness
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
            input,
            light,
            normalWS,
            viewDirWS,
            baseColor.rgb,
            metallic,
            roughness
          );
        }
        LIGHT_LOOP_END

        #endif

        return float4(finalColor, baseColor.a);
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
