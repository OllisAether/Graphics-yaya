# Holographic / Iridescent Shader

This Unity project explores a holographic material effect inspired by Blender Guru's [YouTube video](https://youtu.be/RwwFIpX7djc) showing a similar technique in Blender.

This is not simply a rainbow gradient layered over a surface. The shader builds the effect from the material's specular highlights. It duplicates the highlights, applies dispersion to separate their color response, and combines the result to create the shifting, holographic look. Because the color comes from the lighting response, the effect behaves more like a real holographic or iridescent material than a static screen-space overlay.

## Controls

Hold `Left Mouse Button` and drag to rotate the camera around the object.

Use `Scroll Wheel` to zoom in and out.

## Material Breakdown

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

**Dispersion**

Each duplicated highlight is split into multiple iterations. Every iteration receives a slightly different offset and a different color across the red, green, and blue channels. Combining those colored specular responses produces the characteristic spectral separation of a holographic material.

The main controls are:

- **Holographic Iterations**: Defines the number of neighboring highlight samples
- **Holographic Offset**: Defines how far the neighboring samples are offset from the original highlight
- **Dispersion Iterations**: Defines how many times the color is split across the RGB channels
- **Dispersion Factor**: Defines how much the color is separated across the RGB channels
- **Holo Anisotropy**: Defines the direction of the highlight stretching across the surface
- **Holo Anisotropy Rotation**: Defines the rotation of the highlight stretching across the surface

## Performance

Not great.

Higher iteration counts will increase the number of specular samples and therefore the number of lighting calculations. This is then even multiplied by the number of dispersion iterations. The effect is still visible with a single iteration and 6 dispersion iterations.

## Compatibility
This material is designed to work with Unity's Universal Render Pipeline (URP).
