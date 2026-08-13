# Physics demos roadmap

This document records possible independent additions to the Physics gallery. It is not a release commitment and intentionally does not create disabled or “coming soon” entries in the product UI.

## Current foundation

The initial section contains two fixed 3D Position-Based Fluids benchmarks built from SPH kernels:

- **Hydrostatic Column** tests equilibrium, density error, and residual velocity.
- **Dam Break** tests transient flow, boundary response, and volume preservation.

Both retain the playground’s current constraints: one 65,536-work-item dispatch per rendered frame, a 256×256 output, one linear 4 MiB memory buffer, and equivalent AssemblyScript/Wasm and Gasm/WebGPU execution. The existing **Rigid Ball SDF Physics** showcase is also grouped under Physics, unchanged.

## Candidate independent demos

### Material Point Method

Demonstrate particle-to-grid and grid-to-particle transfers with a collapsing granular or elastic material. This is the most natural follow-up to PBF because it makes a contrasting particle/grid numerical method visible.

Likely prerequisite: revisit multi-pass execution or deliberately stage transfers across rendered frames, as the PBF demos do.

### Lattice Boltzmann flow

Use a D2Q9 lattice to show flow around an obstacle, vorticity, and pressure diagnostics. A 2D benchmark fits the current persistent-memory model well and provides a methodologically distinct fluid simulation.

Likely prerequisite: reserve enough ping-pong state for distribution functions and define stable CPU-mode performance targets.

### Finite-element elasticity

Visualize a small tetrahedral or triangular mesh under load, including strain or stress diagnostics. The demo should emphasize assembly, boundary conditions, and solver convergence rather than only deformation aesthetics.

Likely prerequisite: choose a compact iterative solver that can be staged deterministically without global atomics.

### N-body gravity

Compare direct all-pairs gravitational integration with a future acceleration structure, using conserved energy and angular momentum as visible diagnostics.

Likely prerequisite: define whether the first version remains an all-pairs benchmark or justifies reusable tree/grid infrastructure.

## Section principles

- Each entry should stand alone rather than form a mandatory curriculum.
- The numerical method and diagnostics should be inspectable by specialists.
- Visual polish supports the method; it does not substitute for validation.
- CPU/Wasm behavior should remain meaningful unless a future design explicitly changes that contract.
- Runtime architecture should be expanded only when a demo cannot be represented honestly within the existing execution model.
