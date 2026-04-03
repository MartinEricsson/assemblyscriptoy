// Shader source aggregator - imports individual shader files as raw text
// Each shader is stored in ./shaders/<name>.as

// === Getting started ===
import starterRaw from './shaders/starter.as?raw';

// === Flagship demos (f32, GPU-heavy) ===
import flagshipSdfSceneRaw from './shaders/flagship_sdf_scene.as?raw';
import flagshipMandelbrotRaw from './shaders/flagship_mandelbrot.as?raw';
import flagshipCloudsRaw from './shaders/flagship_clouds.as?raw';
import flagshipFireRaw from './shaders/flagship_fire.as?raw';
import cornellBoxGiRaw from './shaders/cornell_box_gi.as?raw';

export const shaderFlagshipSdfScene = flagshipSdfSceneRaw;
export const shaderFlagshipMandelbrot = flagshipMandelbrotRaw;
export const shaderFlagshipClouds = flagshipCloudsRaw;
export const shaderFlagshipFire = flagshipFireRaw;
export const shaderCornellBoxGi = cornellBoxGiRaw;

// === Getting started ===
export const shaderStarter = starterRaw;
