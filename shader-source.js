// Demo catalog — shader sources are loaded on demand to keep the initial bundle small.

export const demoCatalog = {
    starter: { name: 'Starter Template', load: () => import('./shaders/starter.as?raw') },
    xorTextureZoo: { name: 'XOR Texture Zoo', load: () => import('./shaders/xor_texture_zoo.as?raw') },
    plasma: { name: 'Plasma', load: () => import('./shaders/plasma.as?raw') },
    metaballs: { name: 'Metaballs', load: () => import('./shaders/metaballs.as?raw') },
    voxelRaycaster: { name: 'Voxel Raycaster', load: () => import('./shaders/voxel_raycaster.as?raw') },
    persistentLife: { name: 'Persistent Life', load: () => import('./shaders/persistent_life.as?raw') },
    persistentHeat: { name: 'Persistent Heat Diffusion', load: () => import('./shaders/persistent_heat.as?raw') },
    persistentCyclic: { name: 'Persistent Cyclic Automata', load: () => import('./shaders/persistent_cyclic.as?raw') },
    flagshipSdfScene: { name: 'Raymarched SDF Scene', load: () => import('./shaders/flagship_sdf_scene.as?raw') },
    flagshipMandelbrot: { name: 'Deep Mandelbrot Zoom', load: () => import('./shaders/flagship_mandelbrot.as?raw') },
    flagshipClouds: { name: 'Volumetric Clouds', load: () => import('./shaders/flagship_clouds.as?raw') },
    flagshipFire: { name: 'Turbulent Fire', load: () => import('./shaders/flagship_fire.as?raw') },
    cornellBoxGi: { name: 'Cornell Box (Path Tracing)', load: () => import('./shaders/cornell_box_gi.as?raw') },
};

const sourceCache = new Map();

export async function loadDemoSource(demoId) {
    if (sourceCache.has(demoId)) return sourceCache.get(demoId);

    const entry = demoCatalog[demoId];
    if (!entry) throw new Error(`Unknown demo: ${demoId}`);

    const mod = await entry.load();
    const code = mod.default;
    sourceCache.set(demoId, code);
    return code;
}
