import { MEMORY_BYTES, createDefaultMemoryLayout } from './runtime-memory-layout.js';

export const PHOTOREAL_MESH_MAGIC = 0x504d4256; // PMBV
export const PHOTOREAL_MESH_VERSION = 1;
export const PHOTOREAL_FIELD_SIZE = 256;
export const PHOTOREAL_HEADER_WORDS = 16;
export const PHOTOREAL_MATERIAL_STRIDE_WORDS = 8;
export const PHOTOREAL_TRIANGLE_STRIDE_WORDS = 16;
export const PHOTOREAL_BVH_NODE_STRIDE_WORDS = 12;
export const PHOTOREAL_ACCUM_STRIDE_WORDS = 4;

const WORD_BYTES = 4;
const HEADER_BYTES = PHOTOREAL_HEADER_WORDS * WORD_BYTES;
const MATERIAL_STRIDE_BYTES = PHOTOREAL_MATERIAL_STRIDE_WORDS * WORD_BYTES;
const TRIANGLE_STRIDE_BYTES = PHOTOREAL_TRIANGLE_STRIDE_WORDS * WORD_BYTES;
const BVH_NODE_STRIDE_BYTES = PHOTOREAL_BVH_NODE_STRIDE_WORDS * WORD_BYTES;
const ACCUM_BYTES = PHOTOREAL_FIELD_SIZE * PHOTOREAL_FIELD_SIZE * PHOTOREAL_ACCUM_STRIDE_WORDS * WORD_BYTES;
const LEAF_SIZE = 6;

let cachedScene = null;

function align(value, alignment = 16) {
    return Math.ceil(value / alignment) * alignment;
}

function smoothstep(edge0, edge1, value) {
    const t = Math.min(Math.max((value - edge0) / (edge1 - edge0), 0), 1);
    return t * t * (3 - 2 * t);
}

function mix(a, b, t) {
    return a + (b - a) * t;
}

function sub(a, b) {
    return [a[0] - b[0], a[1] - b[1], a[2] - b[2]];
}

function cross(a, b) {
    return [
        a[1] * b[2] - a[2] * b[1],
        a[2] * b[0] - a[0] * b[2],
        a[0] * b[1] - a[1] * b[0],
    ];
}

function dot(a, b) {
    return a[0] * b[0] + a[1] * b[1] + a[2] * b[2];
}

function length(a) {
    return Math.hypot(a[0], a[1], a[2]);
}

function normalize(a) {
    const len = length(a) || 1;
    return [a[0] / len, a[1] / len, a[2] / len];
}

function triangleBounds(a, b, c) {
    return {
        min: [
            Math.min(a[0], b[0], c[0]),
            Math.min(a[1], b[1], c[1]),
            Math.min(a[2], b[2], c[2]),
        ],
        max: [
            Math.max(a[0], b[0], c[0]),
            Math.max(a[1], b[1], c[1]),
            Math.max(a[2], b[2], c[2]),
        ],
    };
}

function addTriangle(triangles, a, b, c, material, preferredNormal = null) {
    let v1 = b;
    let v2 = c;
    let e1 = sub(v1, a);
    let e2 = sub(v2, a);
    let n = cross(e1, e2);
    if (preferredNormal && dot(n, preferredNormal) < 0) {
        v1 = c;
        v2 = b;
        e1 = sub(v1, a);
        e2 = sub(v2, a);
        n = cross(e1, e2);
    }

    const area2 = length(n);
    if (area2 < 1e-8) return;
    const normal = [n[0] / area2, n[1] / area2, n[2] / area2];
    const bounds = triangleBounds(a, v1, v2);
    triangles.push({
        v0: a,
        e1,
        e2,
        normal,
        material,
        area: area2 * 0.5,
        bounds,
        centroid: [
            (a[0] + v1[0] + v2[0]) / 3,
            (a[1] + v1[1] + v2[1]) / 3,
            (a[2] + v1[2] + v2[2]) / 3,
        ],
    });
}

function addQuad(triangles, a, b, c, d, material, preferredNormal) {
    addTriangle(triangles, a, b, c, material, preferredNormal);
    addTriangle(triangles, a, c, d, material, preferredNormal);
}

function productRadius(t) {
    let radius;
    if (t < 0.07) {
        radius = mix(0.24, 0.64, smoothstep(0, 0.07, t));
    } else if (t < 0.56) {
        radius = 0.64 - t * 0.08;
    } else if (t < 0.73) {
        radius = mix(0.59, 0.30, smoothstep(0.56, 0.73, t));
    } else if (t < 0.88) {
        radius = 0.24;
    } else {
        radius = mix(0.32, 0.36, smoothstep(0.88, 1.0, t));
    }

    const grooveA = 1 - 0.045 * Math.exp(-Math.pow((t - 0.20) * 30, 2));
    const grooveB = 1 - 0.035 * Math.exp(-Math.pow((t - 0.40) * 32, 2));
    const shoulderCut = 1 - 0.028 * Math.exp(-Math.pow((t - 0.68) * 38, 2));
    return radius * grooveA * grooveB * shoulderCut;
}

function createProductMesh(triangles) {
    const segments = 56;
    const rings = 38;
    const vertices = [];

    for (let j = 0; j < rings; j++) {
        const t = j / (rings - 1);
        const y = 0.08 + t * 1.74;
        const baseRadius = productRadius(t);
        const twist = t * 0.34;
        const row = [];

        for (let s = 0; s < segments; s++) {
            const theta = (s / segments) * Math.PI * 2 + twist;
            const panel = 1 + Math.cos(theta * 12) * 0.032 + Math.cos(theta * 24 + t * 4.0) * 0.012;
            const bevel = s % 2 === 0 ? 1.006 : 0.994;
            const radius = baseRadius * panel * bevel;
            row.push([Math.cos(theta) * radius, y, Math.sin(theta) * radius]);
        }
        vertices.push(row);
    }

    for (let j = 0; j < rings - 1; j++) {
        const t = (j + 0.5) / (rings - 1);
        const material = t < 0.13 ? 2 : 1;
        for (let s = 0; s < segments; s++) {
            const next = (s + 1) % segments;
            const v00 = vertices[j][s];
            const v10 = vertices[j][next];
            const v01 = vertices[j + 1][s];
            const v11 = vertices[j + 1][next];
            const preferred = normalize([
                v00[0] + v10[0] + v01[0] + v11[0],
                0,
                v00[2] + v10[2] + v01[2] + v11[2],
            ]);
            addTriangle(triangles, v00, v01, v11, material, preferred);
            addTriangle(triangles, v00, v11, v10, material, preferred);
        }
    }

    const bottom = [0, 0.08, 0];
    const top = [0, 1.92, 0];
    for (let s = 0; s < segments; s++) {
        const next = (s + 1) % segments;
        addTriangle(triangles, bottom, vertices[0][next], vertices[0][s], 2, [0, -1, 0]);
        addTriangle(triangles, top, vertices[rings - 1][s], vertices[rings - 1][next], 1, [0, 1, 0]);
    }
}

function createStudioScene() {
    const triangles = [];

    addQuad(
        triangles,
        [-7.0, 0, -6.0],
        [7.0, 0, -6.0],
        [7.0, 0, 8.0],
        [-7.0, 0, 8.0],
        0,
        [0, 1, 0],
    );
    createProductMesh(triangles);

    const lx0 = -1.9;
    const lx1 = 0.7;
    const lz0 = 0.35;
    const lz1 = 1.85;
    const ly = 2.85;
    addQuad(
        triangles,
        [lx0, ly, lz0],
        [lx1, ly, lz0],
        [lx1, ly, lz1],
        [lx0, ly, lz1],
        3,
        [0, -1, 0],
    );

    return triangles;
}

function unionBounds(items) {
    const min = [Infinity, Infinity, Infinity];
    const max = [-Infinity, -Infinity, -Infinity];
    for (const item of items) {
        const bounds = item.bounds;
        for (let axis = 0; axis < 3; axis++) {
            min[axis] = Math.min(min[axis], bounds.min[axis]);
            max[axis] = Math.max(max[axis], bounds.max[axis]);
        }
    }
    return { min, max };
}

function centroidBounds(items) {
    const min = [Infinity, Infinity, Infinity];
    const max = [-Infinity, -Infinity, -Infinity];
    for (const item of items) {
        for (let axis = 0; axis < 3; axis++) {
            min[axis] = Math.min(min[axis], item.centroid[axis]);
            max[axis] = Math.max(max[axis], item.centroid[axis]);
        }
    }
    return { min, max };
}

function longestAxis(bounds) {
    const ex = bounds.max[0] - bounds.min[0];
    const ey = bounds.max[1] - bounds.min[1];
    const ez = bounds.max[2] - bounds.min[2];
    if (ey > ex && ey > ez) return 1;
    if (ez > ex && ez > ey) return 2;
    return 0;
}

function buildTree(items) {
    const bounds = unionBounds(items);
    if (items.length <= LEAF_SIZE) {
        return { bounds, triangles: items, left: null, right: null, size: 1 };
    }

    const axis = longestAxis(centroidBounds(items));
    const sorted = [...items].sort((a, b) => a.centroid[axis] - b.centroid[axis]);
    const mid = Math.max(1, Math.floor(sorted.length / 2));
    const left = buildTree(sorted.slice(0, mid));
    const right = buildTree(sorted.slice(mid));
    return { bounds, triangles: null, left, right, size: 1 + left.size + right.size };
}

function buildThreadedBvh(sourceTriangles) {
    const root = buildTree(sourceTriangles);
    const nodes = [];
    const triangles = [];

    function flatten(node, missIndex) {
        const index = nodes.length;
        nodes.push(null);

        if (node.triangles) {
            const first = triangles.length;
            triangles.push(...node.triangles);
            nodes[index] = {
                bounds: node.bounds,
                first,
                count: node.triangles.length,
                miss: missIndex,
            };
            return index;
        }

        const rightIndex = index + 1 + node.left.size;
        flatten(node.left, rightIndex);
        flatten(node.right, missIndex);
        nodes[index] = {
            bounds: node.bounds,
            first: 0,
            count: 0,
            miss: missIndex,
        };
        return index;
    }

    flatten(root, -1);
    return { nodes, triangles };
}

function buildPhotorealMeshScene() {
    if (cachedScene) return cachedScene;

    const materials = [
        [0.84, 0.82, 0.77, 0.78, 0.00, 0.00, 0.00, 0.00],
        [0.82, 0.72, 0.58, 0.42, 0.72, 0.00, 0.00, 0.00],
        [0.035, 0.038, 0.045, 0.46, 0.35, 0.00, 0.00, 0.00],
        [1.00, 0.93, 0.78, 0.10, 0.00, 10.5, 9.0, 6.2],
    ];
    const bvh = buildThreadedBvh(createStudioScene());

    cachedScene = {
        materials,
        triangles: bvh.triangles,
        nodes: bvh.nodes,
    };
    return cachedScene;
}

export function initializePhotorealMeshMemory({
    memoryI32,
    memoryF32,
    memoryBytes = MEMORY_BYTES,
    layout = createDefaultMemoryLayout(memoryBytes),
} = {}) {
    if (!memoryI32 || !memoryF32) {
        throw new Error('Photoreal mesh memory initialization requires both i32 and f32 views.');
    }
    if (memoryI32.buffer !== memoryF32.buffer) {
        throw new Error('Photoreal mesh memory views must share the same ArrayBuffer.');
    }
    if (!layout.state) {
        throw new Error('Photoreal mesh memory initialization requires a persistent state region.');
    }

    const scene = buildPhotorealMeshScene();
    const stateStart = layout.state.byteOffset;
    const stateEnd = layout.state.byteOffset + layout.state.byteLength;
    const materialOffset = align(stateStart + HEADER_BYTES);
    const triangleOffset = align(materialOffset + scene.materials.length * MATERIAL_STRIDE_BYTES);
    const nodeOffset = align(triangleOffset + scene.triangles.length * TRIANGLE_STRIDE_BYTES);
    const accumOffset = align(nodeOffset + scene.nodes.length * BVH_NODE_STRIDE_BYTES);
    const endOffset = accumOffset + ACCUM_BYTES;

    if (endOffset > stateEnd || endOffset > memoryBytes) {
        throw new Error(
            `Photoreal mesh scene needs ${endOffset - stateStart} state bytes, `
            + `but only ${Math.min(stateEnd, memoryBytes) - stateStart} are available.`,
        );
    }

    memoryI32.fill(0, stateStart / WORD_BYTES, stateEnd / WORD_BYTES);

    const header = stateStart / WORD_BYTES;
    memoryI32[header] = PHOTOREAL_MESH_MAGIC;
    memoryI32[header + 1] = PHOTOREAL_MESH_VERSION;
    memoryI32[header + 2] = scene.materials.length;
    memoryI32[header + 3] = scene.triangles.length;
    memoryI32[header + 4] = scene.nodes.length;
    memoryI32[header + 5] = materialOffset;
    memoryI32[header + 6] = triangleOffset;
    memoryI32[header + 7] = nodeOffset;
    memoryI32[header + 8] = accumOffset;
    memoryI32[header + 9] = PHOTOREAL_FIELD_SIZE * PHOTOREAL_FIELD_SIZE;
    memoryI32[header + 10] = ACCUM_BYTES;

    for (let materialIndex = 0; materialIndex < scene.materials.length; materialIndex++) {
        const dst = materialOffset / WORD_BYTES + materialIndex * PHOTOREAL_MATERIAL_STRIDE_WORDS;
        const material = scene.materials[materialIndex];
        for (let i = 0; i < PHOTOREAL_MATERIAL_STRIDE_WORDS; i++) {
            memoryF32[dst + i] = material[i];
        }
    }

    for (let triIndex = 0; triIndex < scene.triangles.length; triIndex++) {
        const dst = triangleOffset / WORD_BYTES + triIndex * PHOTOREAL_TRIANGLE_STRIDE_WORDS;
        const tri = scene.triangles[triIndex];
        memoryF32[dst] = tri.v0[0];
        memoryF32[dst + 1] = tri.v0[1];
        memoryF32[dst + 2] = tri.v0[2];
        memoryF32[dst + 3] = tri.e1[0];
        memoryF32[dst + 4] = tri.e1[1];
        memoryF32[dst + 5] = tri.e1[2];
        memoryF32[dst + 6] = tri.e2[0];
        memoryF32[dst + 7] = tri.e2[1];
        memoryF32[dst + 8] = tri.e2[2];
        memoryF32[dst + 9] = tri.normal[0];
        memoryF32[dst + 10] = tri.normal[1];
        memoryF32[dst + 11] = tri.normal[2];
        memoryI32[dst + 12] = tri.material;
        memoryF32[dst + 13] = tri.area;
    }

    for (let nodeIndex = 0; nodeIndex < scene.nodes.length; nodeIndex++) {
        const dst = nodeOffset / WORD_BYTES + nodeIndex * PHOTOREAL_BVH_NODE_STRIDE_WORDS;
        const node = scene.nodes[nodeIndex];
        memoryF32[dst] = node.bounds.min[0] - 0.0005;
        memoryF32[dst + 1] = node.bounds.min[1] - 0.0005;
        memoryF32[dst + 2] = node.bounds.min[2] - 0.0005;
        memoryF32[dst + 3] = node.bounds.max[0] + 0.0005;
        memoryF32[dst + 4] = node.bounds.max[1] + 0.0005;
        memoryF32[dst + 5] = node.bounds.max[2] + 0.0005;
        memoryI32[dst + 6] = node.first;
        memoryI32[dst + 7] = node.count;
        memoryI32[dst + 8] = node.miss;
    }

    return {
        byteLength: endOffset - stateStart,
        materialCount: scene.materials.length,
        triangleCount: scene.triangles.length,
        nodeCount: scene.nodes.length,
        materialOffset,
        triangleOffset,
        nodeOffset,
        accumOffset,
        endOffset,
    };
}
