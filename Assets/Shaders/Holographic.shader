Shader "berch/Holographic"
{
  Properties
  {
    [Header(Main Surface Properties)]
    [MainColor] _BaseColor ("Base Color", Color) = (1,1,1,1)
    [MainTexture] _BaseMap ("Base Map", 2D) = "white" {}

    [Header(Metallic Properties)]
    _Metallic ("Metallic", Range(0,1)) = 0
    _MetallicMap ("Metallic Map", 2D) = "white" {}

    [Header(Roughness Properties)]
    _Roughness ("Roughness", Range(0,1)) = 0.35
    _RoughnessMap ("Roughness Map", 2D) = "white" {}

    [Header(Normal Properties)]
    [Normal] _NormalMap ("Normal Map", 2D) = "bump" {}
    _NormalStrength ("Strength", Range(0,2)) = 1

    [Header(Holographic Coat)]
    _HoloStrength ("Holographic Strength", Range(0,1)) = 1
    _HoloMap ("Holographic Map", 2D) = "white" {}

    [Header(Holographic Normal Properties)]
    _HoloNormalMap ("Holographic Normal Map", 2D) = "bump" {}
    _HoloNormalStrength ("Holographic Normal Strength", Range(0,2)) = 1

    [Header(Holographic Specular Properties)]
    _Anisotropy ("Anisotropy", Range(-1,1)) = 0
    _AnisotropyRotation ("Anisotropy Rotation", Range(0,1)) = 0

    _SpecularReflectionStrength ("Specular Reflection Strength", Range(0,2)) = 1
    _EnvironmentReflectionStrength ("Environment Reflection Strength", Range(0,2)) = 1

    _HoloIterations ("Holographic Iterations", Int) = 1
    _HoloOffset ("Holographic Offset", Range(0.01, 1)) = 1
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
        float4 _BaseMap_ST;

        float _Metallic;
        float4 _MetallicMap_ST;

        float _Roughness;
        float4 _RoughnessMap_ST;

        float4 _NormalMap_ST;
        float _NormalStrength;

        // Holographic Properties
        float _HoloStrength;
        float4 _HoloMap_ST;

        float4 _HoloNormalMap_ST;
        float _HoloNormalStrength;

        float _Anisotropy;
        float _AnisotropyRotation;

        float _SpecularReflectionStrength;
        float _EnvironmentReflectionStrength;

        int _HoloIterations;
        float _HoloOffset;
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

      // Isolated specular reflection calculation
      float3 CalculateSpecularReflection(
        float3 normalWS,
        float3 tangentWS,
        float3 bitangentWS,
        float3 viewDirWS,
        float3 lightDirWS,
        float3 lightColor,
        float attenuation,
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

        half NDotL = saturate(dot(normalWS, lightDirWS));
        half specularTerm = DirectBRDFSpecular(
          brdfData,
          normalWS,
          lightDirWS,
          viewDirWS
        );

        return attenuation * lightColor * brdfData.specular *
          specularTerm * NDotL * _SpecularReflectionStrength;
      }

      float3 CalculateEnvironmentReflection(
        float3 positionWS,
        float3 normalWS,
        float3 viewDirWS,
        float roughness,
        float3 albedo,
        float metallic,
        float reflectionStrength,
        float2 normalizedScreenSpaceUV
      )
      {
        float3 reflectionDirection = reflect(-viewDirWS, normalWS);
        float3 f0 = lerp(
          float3(0.04, 0.04, 0.04),
          albedo,
          saturate(metallic)
        );
        float fresnelTerm = pow(
          1.0 - saturate(dot(normalWS, viewDirWS)),
          5.0
        );
        float3 fresnelColor = f0 + (1.0 - f0) * fresnelTerm;

        return GlossyEnvironmentReflection(
          reflectionDirection,
          positionWS,
          saturate(roughness),
          1.0,
          normalizedScreenSpaceUV
        ) * fresnelColor * reflectionStrength;
      }

      float3 CalculateLight(
        float3 positionWS,
        float3 normalWS,
        float3 tangentWS,
        float3 bitangentWS,
        float3 viewDirWS,
        float3 lightDirWS,
        float3 lightColor,
        float attenuation,
        float3 albedo,
        float metallic,
        float roughness
      )
      {
        float NDotL = dot(normalWS, lightDirWS);

        float3 DiffRefl = attenuation * lightColor * albedo * (1.0 - metallic) * max(0.0, NDotL);

        float3 SpecRefl = float3(0,0,0);

        if (NDotL >= 0)
        {
          SpecRefl = CalculateSpecularReflection(
            normalWS,
            tangentWS,
            bitangentWS,
            viewDirWS,
            lightDirWS,
            lightColor,
            attenuation,
            albedo,
            metallic,
            roughness
          );
        }

        return DiffRefl + SpecRefl;
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
          input.positionWS,
          normalWS,
          viewDirWS,
          roughness,
          baseColor.rgb,
          metallic,
          _EnvironmentReflectionStrength,
          GetNormalizedScreenSpaceUV(input.positionCS)
        );

        float3 finalColor = ambientDiffuse + environmentReflection;

        //Main Light
        Light mainLight = GetMainLight(input.shadowCoord);

        finalColor += CalculateLight(
          input.positionWS,
          normalWS,
          input.tangentWS,
          input.bitangentWS,
          viewDirWS,
          mainLight.direction,
          mainLight.color,
          mainLight.distanceAttenuation * mainLight.shadowAttenuation,
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
            input.positionWS,
            normalWS,
            input.tangentWS,
            input.bitangentWS,
            viewDirWS,
            light.direction,
            light.color,
            light.distanceAttenuation * light.shadowAttenuation,
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
