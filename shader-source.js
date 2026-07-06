// Demo catalog - shader sources are loaded on demand to keep the initial bundle small.

export const demoGroups = {
    start: 'getting started',
    foundations: 'visual foundations',
    compiler: 'compiler showcase',
    persistent: 'persistent memory',
    advanced: 'advanced rendering',
};

const autoParallel = ['AUTO PARALLEL'];

export const demoCatalog = {
    starter: {
        name: 'Starter Template',
        group: 'start',
        description: 'The minimum pixel loop, memory layout, and animation input contract.',
        features: autoParallel,
        load: () => import('./shaders/starter.as?raw'),
    },
    coordinateLab: {
        name: 'Coordinate Lab',
        group: 'start',
        description: 'Four compact studies of gradients, grids, distance, and polar coordinates.',
        features: autoParallel,
        load: () => import('./shaders/coordinate_lab.as?raw'),
    },
    xorTextureZoo: {
        name: 'XOR Texture Zoo',
        group: 'foundations',
        description: 'Eight integer and bitwise texture formulas in one editable atlas.',
        features: autoParallel,
        load: () => import('./shaders/xor_texture_zoo.as?raw'),
    },
    truchetMosaic: {
        name: 'Truchet Mosaic',
        group: 'foundations',
        description: 'A shifting maze built from hashed tile orientation and arc geometry.',
        features: autoParallel,
        load: () => import('./shaders/truchet_mosaic.as?raw'),
    },
    plasma: {
        name: 'Plasma',
        group: 'foundations',
        description: 'Layered waves separated cleanly from cosine palette mapping.',
        features: autoParallel,
        load: () => import('./shaders/plasma.as?raw'),
    },
    metaballs: {
        name: 'Metaballs',
        group: 'foundations',
        description: 'Moving implicit fields that merge into softly shaded organic forms.',
        features: autoParallel,
        load: () => import('./shaders/metaballs.as?raw'),
    },
    voronoiGlass: {
        name: 'Voronoi Stained Glass',
        group: 'foundations',
        description: 'Animated cells, luminous borders, and refraction-like color offsets.',
        features: autoParallel,
        load: () => import('./shaders/voronoi_stained_glass.as?raw'),
    },
    precisionJulia: {
        name: 'Precision Julia Orbit Traps',
        group: 'compiler',
        description: 'A morphing Julia set that intentionally exercises numeric demotion.',
        features: ['AUTO PARALLEL', 'F64 DEMOTION', 'I64'],
        load: () => import('./shaders/precision_julia.as?raw'),
    },
    simdKaleidoscope: {
        name: 'SIMD Neon Kaleidoscope',
        slug: 'simd-neon',
        group: 'compiler',
        description: 'A vectorized neon tunnel driven by direct Gasm math intrinsics.',
        features: ['AUTO PARALLEL', 'SIMD', 'MATH M0'],
        compileOptions: { mathExtension: 'M0' },
        assemblyScriptOptions: { enable: ['simd'] },
        load: () => import('./shaders/simd_neon_kaleidoscope.as?raw'),
    },
    voxelRaycaster: {
        name: 'Voxel Raycaster',
        group: 'compiler',
        description: 'Amanatides-Woo grid traversal through a procedural voxel landscape.',
        features: autoParallel,
        load: () => import('./shaders/voxel_raycaster.as?raw'),
    },
    persistentLife: {
        name: 'Persistent Life',
        group: 'persistent',
        description: 'Conway Life with GPU-resident ping-pong state.',
        features: ['AUTO PARALLEL', 'PERSISTENT'],
        load: () => import('./shaders/persistent_life.as?raw'),
    },
    persistentHeat: {
        name: 'Persistent Heat Diffusion',
        group: 'persistent',
        description: 'Retained heat diffusion with animated sources.',
        features: ['AUTO PARALLEL', 'PERSISTENT'],
        load: () => import('./shaders/persistent_heat.as?raw'),
    },
    persistentCyclic: {
        name: 'Persistent Cyclic Automata',
        group: 'persistent',
        description: 'Sixteen-state cellular waves that chase across a toroidal field.',
        features: ['AUTO PARALLEL', 'PERSISTENT'],
        load: () => import('./shaders/persistent_cyclic.as?raw'),
    },
    rippleTank: {
        name: 'Interactive Ripple Tank',
        group: 'persistent',
        description: 'Pointer-driven refraction over procedural wet cobblestone.',
        features: ['AUTO PARALLEL', 'PERSISTENT', 'I16 MEMORY', 'POINTER'],
        clock: 'step',
        load: () => import('./shaders/interactive_ripple_tank.as?raw'),
    },
    grayScottCoral: {
        name: 'Gray-Scott Coral Lab',
        group: 'persistent',
        description: 'Paint reaction chemicals into a growing coral-like simulation.',
        features: ['AUTO PARALLEL', 'PERSISTENT', 'U16 MEMORY', 'POINTER'],
        load: () => import('./shaders/gray_scott_coral.as?raw'),
    },
    flowFieldInk: {
        name: 'Flow-Field Ink',
        group: 'persistent',
        description: 'Colored ink transported through a procedural curl field.',
        features: ['AUTO PARALLEL', 'PERSISTENT', 'F32 STATE', 'POINTER'],
        load: () => import('./shaders/flow_field_ink.as?raw'),
    },
    flagshipSdfScene: {
        name: 'Raymarched SDF Scene',
        group: 'advanced',
        description: 'Distance fields, soft shadows, ambient occlusion, fog, and reflection.',
        features: autoParallel,
        load: () => import('./shaders/flagship_sdf_scene.as?raw'),
    },
    rigidBallsSdf: {
        name: 'Rigid Ball SDF Physics',
        group: 'advanced',
        description: 'Elastic wall-bounce rigid spheres raymarched as signed distance fields.',
        features: ['AUTO PARALLEL', 'SDF', 'PHYSICS'],
        load: () => import('./shaders/rigid_balls_sdf.as?raw'),
    },
    flagshipMandelbrot: {
        name: 'Deep Mandelbrot Zoom',
        group: 'advanced',
        description: 'A supersampled, smoothly colored fractal stress test.',
        features: autoParallel,
        load: () => import('./shaders/flagship_mandelbrot.as?raw'),
    },
    flagshipClouds: {
        name: 'Volumetric Clouds',
        group: 'advanced',
        description: 'Layered volumetric clouds, atmospheric light, and reflective water.',
        features: autoParallel,
        load: () => import('./shaders/flagship_clouds.as?raw'),
    },
    flagshipFire: {
        name: 'Turbulent Fire',
        group: 'advanced',
        description: 'Domain-warped volumetric flame, sparks, glow, and tone mapping.',
        features: autoParallel,
        load: () => import('./shaders/flagship_fire.as?raw'),
    },
    proceduralPlanet: {
        name: 'Procedural Planet',
        group: 'advanced',
        description: 'A rotating world with displaced terrain, ocean, atmosphere, and volumetric clouds.',
        features: ['AUTO PARALLEL', 'MATH M0'],
        compileOptions: { mathExtension: 'M0' },
        load: () => import('./shaders/procedural_planet.as?raw'),
    },
    cornellBoxGi: {
        name: 'Cornell Box (Path Tracing)',
        group: 'advanced',
        description: 'A high-sample path tracer that computes a fresh estimate each frame.',
        features: autoParallel,
        load: () => import('./shaders/cornell_box_gi.as?raw'),
    },
    progressivePathTracer: {
        name: 'Progressive Path Tracer',
        group: 'advanced',
        description: 'A material study that accumulates global illumination across frames.',
        features: ['AUTO PARALLEL', 'PERSISTENT', 'PROGRESSIVE'],
        load: () => import('./shaders/progressive_path_tracer.as?raw'),
    },
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
