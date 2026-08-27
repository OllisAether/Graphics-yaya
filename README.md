# Holographic / Iridescent Shader

This Unity project explores a holographic material effect inspired by Blender Guru's [YouTube video](https://youtu.be/RwwFIpX7djc) showing a similar technique in Blender.

## Concept

The goal is to create a reusable holographic material for objects such as collectible cards, packaging, product finishes, and vehicle paint. I wanted to achieve a holographic effect that responds to the scene's lighting and camera angle, rather than overlaying a rainbow by using the reflection vector to map from a static rainbow texture. The shader duplicates the specular highlights, offsets them, and applies RGB dispersion to create a spectral separation of the highlights. The result is a holographic effect that changes as the object, camera, or lighting changes.

## Technical Description

The implementation is contained in [`Assets/Shaders/Holographic.shader`](Assets/Shaders/Holographic.shader), a custom ShaderLab/HLSL shader for Unity's Universal Render Pipeline (URP).

The shader combines several techniques:

- A physically based base surface with base color, metallic, roughness, and normal inputs.
- A separate holographic coat with its own strength, roughness, mask, and normal map.
- URP's BRDF helpers for direct specular lighting, so the holographic highlights respond to real scene lights.
- Fresnel-based environment reflections on the base surface, making the material more reflective at shallow angles.
- Highlight duplication by evaluating the specular response from several light directions.
- Dispersion, where each neighboring highlight is offset and assigned a different spectral color.
- Anisotropic stretching and rotation of the offset pattern to create directional holographic streaks.
- Main-light shadows and additional URP lights.

## Example Scene

The project examples are under `Assets/Scenes/Holographic`. The examples are set up with a directional light and a skybox and three additional spotlights to show off the effect.

1. Open an example scene under `Assets/Scenes/Holographic`.
2. Play the scene and use the mouse controls to inspect the material from different angles.

The examples include:

- **Suzanne**: The default Blender Suzanne model. It shows the effect on a simple model with a single material.
- **MURMY Business Card**: A simple business card model with a holographic coat on top of a base surface.
- **Hatsune Miku Studimon Card**: A more complex card with a holographic coat on top of a base surface. The holographic coat uses a separate normal map to shape the highlights. The base surface uses a normal map to create a subtle embossed effect.
- **Mazda Miata mx-5**: A car model with a holographic car paint material. It shows the effect on a complex model with multiple materials.
- **VS-Code open time**: A screenshot showing how long I have been working on this project. It has a holographic coat on top of a base surface with a separate normal map to shape little stars.

## Runtime Controls

Hold `Left Mouse Button` and drag to rotate the camera around the object.

Use `Scroll Wheel` to zoom in and out.

## Parameters and Material Breakdown

### Base Surface

The base surface uses familiar physically based material inputs:

- **Base color**
- **Base texture**
- **Metallic**
- **Roughness**
- **Normal map**
- **Shininess**
- **Fresnel**

### Holographic Coat

The holographic coat is a specular layer that sits on top of the base surface and uses its own normal map to shape the highlights. The coat's roughness controls are separate from the base surface, allowing you to tune the holographic response independently.

### Dispersion and Anisotropy

Each duplicated highlight is split into multiple iterations. Every iteration receives a slightly different offset and a different color across the red, green, and blue channels. Combining those colored specular responses produces the characteristic spectral separation of a holographic material.

The main controls are:

- **Holographic Iterations**: Defines the number of neighboring highlight samples
- **Holographic Offset**: Defines how far the neighboring samples are offset from the original highlight
- **Dispersion Iterations**: Defines how many times the color is split across the RGB channels
- **Dispersion Factor**: Defines how much the color is separated across the RGB channels
- **Holo Anisotropy**: Defines the direction of the highlight stretching across the surface
- **Holo Anisotropy Rotation**: Defines the rotation of the highlight stretching across the surface

The material also exposes **Holographic Strength**, **Holographic Map**, **Holographic Normal Map**, and **Holographic Normal Strength**. These control where the coat appears, how strongly it contributes, and how its surface detail shapes the specular response.

## Intended Use

The idea of this shader mainly stems from the desire to make Pokemon cards holographic in Unity. However, as per requirement of the assignment, I do not own the rights to any Pokemon intellectual property. Therefore, I have created my own original holographic card design of a Studimon card. The shader can be used for any holographic material, such as collectible cards, packaging, product finishes, and vehicle paint.

## Challenges

The main technical challenge was getting anisotropy to behave correctly. The shader builds a local tangent and bitangent frame from the surface normal, rotates the 2D offset, and then stretches it according to the anisotropy value before applying it to the light direction. A fallback reference axis is used when the normal is close to world up to avoid a parallel cross product. Tuning the offset, rotation, and stretching together was necessary to produce directional highlights without inconsistent patterns across the model. This was especially apparent before along UV seams, where the tangent and bitangent directions can flip across the seam.

## Performance

Higher iteration counts will increase the number of specular samples and therefore the number of lighting calculations. This is then even multiplied by the number of dispersion iterations. The effect is still visible with a single iteration and 6 dispersion iterations.

## Sources and References

- [Blender Guru YouTube reference](https://youtu.be/RwwFIpX7djc), used as inspiration for the holographic highlight technique. This Unity implementation is a custom URP ShaderLab/HLSL version that adds separate base and holographic material inputs, light-aware dispersion, anisotropic highlight control, and support for Unity scene lighting.
- [Mazda Miata mx-5](https://sketchfab.com/3d-models/mazda-miata-mx-5-e074e29ccc3847dca74ed5e9cb92d3e7) by [Black Snow](https://sketchfab.com/BlackSnow02), licensed under [CC Attribution](https://creativecommons.org/licenses/by/4.0/).
