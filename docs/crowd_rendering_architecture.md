---DOC:crowd_rendering_architecture.md---

# Crowd Rendering & Performance Architecture

| Document field | Value |
|---|---|
| Specification ID | CROWD-ARCH-001 |
| Revision | 1.0 |
| Date | 2026-09-05 |
| Status | Architecture proposal; performance requires prototype validation |
| Implementation language | Typed GDScript for orchestration and initial simulation; Godot shading language for crowd deformation; optional GDExtension kernels |
| Reference engine | Godot 4.7.2 standard build; matching export templates |
| Development | Apple Silicon macOS, native Metal rendering driver |
| Primary shipping target | Windows x86-64, Forward+, D3D12 and Vulkan tested separately |
| Scope | Crowd rendering, animation, battle simulation boundaries, determinism, memory, asset contract, feasibility gates |

## 0. Decision and feasibility

**800–1,600 animated characters is a credible prototype target in Godot, provided most characters use instanced, texture-driven animation and bounded simulation. It is not a defensible promise of 60 FPS with unrestricted Total War: Warhammer III fidelity, arbitrary equipment, full individual animation trees, physics, vegetation, shadows, and ground-level views.** No benchmark of this game or its assets has been run for this document. All performance numbers below are acceptance budgets or explicitly labeled estimates, not measured engine capabilities.

**Recommended architecture:** authoritative integer structure-of-arrays simulation at 30 ticks/second; separate presentation extraction; spatially partitioned `MultiMeshInstance3D` batches; baked bone animation textures for normal crowd characters; a pool of at most 48 conventional skeletal characters for close views; explicit mesh and animation LOD; bounded contact combat. Start the school deliverable at **800 living models**, qualify **1,600**, and test **1,920** as the actual maximum implied by the squad rules.

There is no verified universal maximum character count. Claiming that Godot tops out at 500, 1,600, or 10,000 without defining assets, passes, hardware, and simulation would be fabricated precision. This document defines how to measure the project's maximum instead.

### 0.1 Correct the population envelope

| Scenario | Calculation | Living models |
|---|---|---:|
| Minimum advertised small-squad battle | 10 squads/side × 2 × 40 | 800 |
| Requested upper target | Product requirement | 1,600 |
| Actual all-small maximum | 16 squads/side × 2 × 60 | 1,920 |
| Medium maximum | 16 × 2 × 40 | 1,280 |
| Large maximum | 16 × 2 × 15 | 480 |
| Giant maximum | 16 × 2 × 1 | 32 |

Use 2,048 living entity slots, 512 corpse presentation slots, 4,096 projectile slots, and 32 squad slots. These are capacities, not permission to spawn more than the qualified battle size. Birds, snakes, and eels may cost much more per model than small bipeds; population is only one workload dimension.

### 0.2 Version and renderer contract

Pin editor, command-line imports, CI, and export templates to the same patch. The official archive lists 4.7.2 as a stable release; this is the selected baseline rather than an assertion that every 4.x release behaves identically. Re-run all gates after any engine upgrade. [Godot 4.7.2 archive](https://godotengine.org/download/archive/4.7.2-stable/)

Forward+ is a rendering method; Metal, Vulkan, and D3D12 are rendering drivers. Mobile is another method that can use these modern drivers, and is a candidate reduced-effects preset. Compatibility is a separate OpenGL path and is outside this specification. Windows projects changed their default driver to D3D12 in 4.6; explicitly select and record the driver instead of relying on defaults. [Renderer overview](https://docs.godotengine.org/en/4.7/tutorials/rendering/renderers.html), [Godot 4.6 release](https://godotengine.org/releases/4.6/)

### 0.3 Hardware and measurement contract

These are proposed qualification machines, not hardware recommendations or verified minimum requirements.

| Profile | CPU / GPU / memory | Required use |
|---|---|---|
| W-N | Ryzen 5 3600 / GTX 1660 Super 6 GB / 16 GB RAM / SSD / Windows 11 | Primary 1080p 60 FPS qualification floor |
| W-A | Ryzen 5 3600 / Radeon RX 6600 8 GB / 16 GB RAM / SSD / Windows 11 | AMD driver and shader correctness |
| M-D | User's actual MacBook Pro | Record chip, GPU cores, RAM, macOS, power mode; development regression only |

Render at **1920×1080 internal resolution**, 100% scale, one gameplay viewport, no editor. Disable VSync and frame limiting for throughput captures; repeat with VSync enabled for presentation. Run export-release builds. Warm up for 60 seconds, record 180 seconds, repeat three times, then run a 20-minute soak. Record cold-start behavior separately so warmup does not hide shipping hitches. Use the slowest qualifying repeat.

| Metric | Gate |
|---|---:|
| Frame interval p50 | ≤14.0 ms |
| Frame interval p95 | ≤16.67 ms |
| Frame interval p99 | ≤20.0 ms |
| Continuous period below 55 FPS | None longer than 1 second |
| Routine simulation tick p99 | ≤4.0 ms at 30 Hz |
| Main-thread CPU work on a tick-bearing frame p95 | ≤12.0 ms |
| GPU frame time p95 | ≤12.5 ms |
| Whole-scene draws, including depth/shadow passes | ≤900 diagnostic target |
| Simulation-owned CPU memory | <100,000,000 bytes |

This operational definition permits occasional frames above 16.67 ms. If the school requirement literally means every frame meets 16.67 ms, replace the p99 gate with **maximum ≤16.67 ms** and expect a smaller supported feature/population envelope. Percentile timing is not a hard real-time guarantee.

CPU and GPU overlap; do not add their total times to estimate frame duration. Nevertheless, a simulation tick and presentation extraction on the same CPU thread add together on that frame. A 4 ms tick at 30 Hz costs 2 ms/frame on average at 60 FPS but still costs 4 ms on tick-bearing frames.

## 1. Normative requirements

`SHALL` is mandatory. `SHOULD` is a recommended optimization subject to a measured gate. Numeric defaults below are project decisions and may be revised only together with benchmark baselines and replay versioning.

| ID | EARS requirement |
|---|---|
| CR-001 | WHILE a battle is running, the simulation SHALL advance only through integer-numbered ticks of duration 1/30 second. |
| CR-002 | WHEN pause is requested, the scheduler SHALL stop before executing another tick and SHALL freeze presentation time at the current completed tick. |
| CR-003 | WHILE paused, camera movement, selection, UI, and order editing SHALL remain operational. |
| CR-004 | WHEN the same initial state and ordered command log are replayed on supported platforms, the authoritative state SHALL produce identical canonical hashes at every tick. |
| CR-005 | WHEN a presentation LOD, camera, batch, or animation sample changes, the simulation state SHALL remain unchanged. |
| CR-006 | WHEN a model changes equipment, its logical weapon statistics and visible equipment SHALL reference the same equipment ID at the committed tick. |
| CR-007 | WHILE a model is outside the camera, its authoritative combat, movement, and morale consequences SHALL continue at their normal simulation cadence. |
| CR-008 | WHEN instance ordering changes, render lookup IDs SHALL continue to identify the same model and pose. |
| CR-009 | IF a capacity is exceeded, the build SHALL reject the scenario or report an explicit overflow; it SHALL NOT silently delete attackers, damage, or commands. |
| CR-010 | WHEN a model dies, its simulation slot SHALL be removed at the end-of-tick lifecycle stage and its corpse presentation SHALL receive an independent pose record. |
| CR-011 | IF qualification fails at 1,600 models, the team SHALL apply the escalation policy in Section 10 before advertising that population. |
| CR-012 | WHEN a shader modifies mesh vertices, the batch bounds SHALL contain every permitted pose, equipment extent, and interpolated root position. |

## 2. Rendering architecture

### 2.1 What MultiMesh does and does not provide

`MultiMesh` repeats a shared mesh. `MultiMeshInstance3D` places that resource in a scene. Use one surface/material per crowd part wherever possible. Each additional surface and render pass can add a draw. A single API primitive is not one total frame draw after shadows and depth rendering.

Hard API constraints: instances share the mesh; blend shapes are ignored; bounds/culling apply to the MultiMesh object; `visible_instance_count` controls a prefix, not an arbitrary visibility mask; custom data exposes four numbers per instance. Enable custom data before setting `instance_count`; changing capacity reallocates the data. Forward+ and Mobile store these numbers at 32-bit precision. [MultiMesh API](https://docs.godotengine.org/en/4.7/classes/class_multimesh.html)

There is no independent `AnimationPlayer`/`Skeleton3D` binding per sub-instance in this API. Attaching a conventional skeleton to a mesh does not manufacture 1,600 independent poses inside a MultiMesh. Ordinary skin-and-skeleton bindings belong to the conventional mesh path. [MeshInstance3D API](https://docs.godotengine.org/en/4.7/classes/class_meshinstance3d.html)

MultiMesh reduces submission overhead, not the geometry, deformation, shading, shadow-map, or texture-fetch work for each visible instance. Spatial splitting is necessary when a single object's bounds would keep offscreen members rendering. [MultiMesh optimization guide](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html)

No per-model scene node, animation tree, collision body, area, navigation agent, timer, or signal connection is permitted in the normal crowd path. Nodes are allowed for batches, squad UI, pooled close-up actors, lights, terrain, and the scheduler.

### 2.2 Separate logical identity from renderer grouping

```text
Commands + immutable catalogs
             |
             v
Authoritative SoA model/squad store -- 30 Hz integer simulation
             |
             v
Previous/current snapshots + animation events
             |
             v
Presentation extraction -- every rendered frame
  interpolation -> visibility -> LOD -> stable visual IDs
             |
       +-----+----------------+------------------+
       v                      v                  v
Body MultiMeshes      Equipment MultiMeshes   Skeletal pool
       |                      |                  |
       +----- shared pose lookup texture --------+
             |
             v
Godot renderer -> Metal / Vulkan / D3D12
```

Simulation arrays do **not** have to be laid out as GPU transform records. Preserve contiguous component columns and stable identity from day one. Presentation gathers these into interleaved float buffers. Forcing squad members to remain contiguous across every renderer category would couple formations to equipment, LOD, visibility, and mesh variations unnecessarily.

Render batch key:

```text
(spatial_cell_x, spatial_cell_z,
 rig_palette_id, mesh_variant_id, mesh_lod,
 material_atlas_id, part_kind, shadow_policy)
```

`part_kind`: BODY=0, MAIN_HAND=1, OFF_HAND=2, HEAD=3, CORPSE=4. Team tint, animation clip, animation phase, and logical squad ID are **not** batch keys. Distinct weapon geometry is a mesh key. A rig with incompatible bind matrices is a different palette, even when bone names match.

Default render cells are 16 m × 16 m in XZ. Evaluate membership each rendered frame from the interpolated root. Batch nodes remain at the cell origin, with local root transforms. For each occupied batch calculate the union of transformed offline animation bounds; enlarge by 0.25 m. Include weapons and previous/current positions. Ordinary translation-only padding cannot cover wings, tails, or spear swings unless their baked bounds are included.

Preallocate batch capacity in multiples of 64; `capacity=64*ceil(peak_members/64)`. Keep empty cached batches for 300 rendered frames before freeing. Cap aggregate allocated slots across body/equipment/corpse batches at 32,768; if approaching the cap, merge adjacent 16 m cells into 32 m cells for presentation, or reclaim empty batches first. Record the extra submitted instances caused by coarser culling. Never change logical formations to meet this limit.

### 2.3 Animation implementation options

| Method | CPU work | GPU work / storage | Equipment and transitions | Decision |
|---|---|---|---|---|
| Conventional skeletal meshes | Per-actor pose evaluation, scene traversal, submission | Engine skinning; mesh/material-dependent passes | Best sockets, IK, layered blends, authoring tools | Close-up pool only; benchmark all-skeletal as baseline |
| Position/normal VAT | Clip/time bookkeeping | Roughly 4 texture fetches/vertex for interpolated position+normal; storage proportional to vertices × frames | Separate mesh VAT per topology; extra socket data for attachments; blends need extra fetches | A/B candidate when bone-texture GPU work is too expensive |
| Bone animation texture, custom vertex skinning | Clip/time bookkeeping; no CPU bone hierarchy evaluation for crowd | 24 matrix texel fetches/vertex with 4 influences and 2 temporal samples; storage proportional to bones × frames | Shared deformation for skinned armor and rigid equipment; limited matrix blends | **Default crowd path** |
| CPU shared pose buckets | Evaluate a few quantized clip/phase skeletons | Reused poses; still solve rendering/submission | Quantization can look synchronized; native integration may help | Secondary experiment, not initial dependency |
| Compute deformation cache | Schedule palette/mesh deformation once per quantized pose | Can reuse deformed vertices across passes; buffers and synchronization | More engineering, memory, motion-vector integration | Escalation only after GPU capture identifies repeated skinning cost |
| Animated impostor atlas | Frame/view selection | A few vertices, alpha-tested pixels, large image atlas | Weak near-camera silhouettes and equipment fidelity | Optional far tier; not initial requirement |

An “animation texture atlas” is a storage arrangement, not a distinct animation algorithm. It can contain vertex positions, bone matrices, or rendered sprites. State which one a tool exports.

Conventional skeletal animation may already deform on the GPU; comparing “skeletal CPU” with “VAT GPU” is misleading. The savings sought here are independent CPU pose evaluation and draw submission, traded against custom shader work and constraints.

### 2.4 Bone texture format: normative contract

Use **linear blend skinning** with a maximum of 64 bones per crowd rig, 4 influences per LOD1 vertex, 2 at LOD2, 1 at LOD3. Large flying/serpentine rigs may use 96 bones in a separately budgeted palette. A 96-bone rig is never silently truncated.

For bone `b`, frame `f`, and mesh-space bind vertex `p`:

```text
S[f,b] = G[f,b] * inverse(B[b])
p_deformed = sum(k=0..K-1, weight[k] * S[f,bone[k]] * vec4(p,1))
```

`G` is posed global bone transform in mesh/model space; `B` is global bind transform in that same space. Bake all axis conversions and mesh-to-skeleton offsets into these matrices. Root locomotion translation and yaw are removed from the clip and supplied by the simulation root transform. Bobbing and local body rotation remain in the pose.

Store the first three rows of each affine matrix in three adjacent `RGBA16F` texels. Texture dimensions are `(3*bone_count, total_baked_frames)`. Texel `(3*b+r,f)` contains row `r`, including translation in its fourth component. No mipmaps, no lossy compression, no sRGB/source-color conversion, nearest integer fetches, no repeat. Compare half-float output against an RGBA32F reference; maximum body vertex error is 2 mm and weapon-tip error 5 mm in the close-up fixture. If the rig fails, use RGBA32F for that palette and account for twice the memory.

Use `Image.FORMAT_RGBAH` for half floats and `Image.FORMAT_RGBAF` for the reference/state images. Import/rebuild data textures explicitly instead of trusting art texture presets. [Image formats](https://docs.godotengine.org/en/4.7/classes/class_image.html)

Presentation pose texture: `RGBA32F`, width 4, height 2,560. Rows 0–2,047 belong to living visual slots; rows 2,048–2,559 belong to corpses. Exactly 64 bytes per row:

| Texel x | RGBA values |
|---:|---|
| 0 | current absolute frame 0, current absolute frame 1, temporal blend [0,1], 0 |
| 1 | outgoing absolute frame 0, outgoing absolute frame 1, outgoing temporal blend, transition weight [0,1] |
| 2 | linear RGB tint, 1 |
| 3 | 0, 0, 0, 0; reserved and zeroed |

`INSTANCE_CUSTOM.x` is the stable visual row. Other components are `(team_id, appearance_id, 0)`; reserve these even if the initial shader only reads x. Visual row is not `INSTANCE_ID`, because batch compaction changes the latter. All body and equipment parts of one model use the same row.

Frame indices refer to the batch's rig palette. Do not put a model in an equipment batch whose palette has a different clip layout. Upload the state texture once per rendered frame after all rows are prepared. `ImageTexture.update(image: Image)` requires matching dimensions, format, and mipmap configuration. At full capacity this is 163,840 bytes/frame, approximately 9.83 MB/s at 60 FPS before staging/copy overhead. This upload can still cause CPU overhead; measure it. [ImageTexture API](https://docs.godotengine.org/en/4.7/classes/class_imagetexture.html)

### 2.5 Shader and mesh attributes

Extract source bone indices/weights offline into `CUSTOM0` and `CUSTOM1`, using four full floats each. Remove ordinary skin arrays from the crowd mesh so there is one deformation path. This deliberately explicit layout also works when moving the data producer to C++. It costs 32 bytes/vertex before later compression.

```gdscript
# Offline/import-time assembly, after vertices/normals/UVs/tangents/indices exist.
func build_crowd_mesh(arrays: Array,
        bone_indices: PackedFloat32Array,
        bone_weights: PackedFloat32Array) -> ArrayMesh:
    var vertex_count: int = arrays[Mesh.ARRAY_VERTEX].size()
    assert(bone_indices.size() == vertex_count * 4)
    assert(bone_weights.size() == vertex_count * 4)
    arrays[Mesh.ARRAY_BONES] = null
    arrays[Mesh.ARRAY_WEIGHTS] = null
    arrays[Mesh.ARRAY_CUSTOM0] = bone_indices
    arrays[Mesh.ARRAY_CUSTOM1] = bone_weights
    var flags: int = (
        Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT
    ) | (
        Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM1_SHIFT
    )
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(
        Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)
    return result
```

`ArrayMesh.add_surface_from_arrays()` accepts custom attribute format flags; full-float custom attributes use packed float arrays. This code is an import construction pattern, not a runtime mesh rebuild. [ArrayMesh API](https://docs.godotengine.org/en/4.7/classes/class_arraymesh.html), [Mesh array formats](https://docs.godotengine.org/en/4.7/classes/class_mesh.html)

The following is the reference four-influence shader. Duplicate as fixed 2-influence and 1-influence variants by changing the loop bound; zero unused weights at import. Provide tangents in the source mesh. Assets must not use animated nonuniform bone scale, shear, or mirrored root scale.

```glsl
shader_type spatial;
render_mode cull_back, depth_draw_opaque;

uniform sampler2D bone_palette : filter_nearest, repeat_disable;
uniform sampler2D pose_state : filter_nearest, repeat_disable;
uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic;
uniform float roughness_value = 0.8;
varying vec3 unit_tint;

mat4 palette_matrix(int bone, int frame) {
    vec4 a = texelFetch(bone_palette, ivec2(3 * bone, frame), 0);
    vec4 b = texelFetch(bone_palette, ivec2(3 * bone + 1, frame), 0);
    vec4 c = texelFetch(bone_palette, ivec2(3 * bone + 2, frame), 0);
    // GLSL constructors take columns; the texture stores rows.
    return mat4(vec4(a.x, b.x, c.x, 0.0),
                vec4(a.y, b.y, c.y, 0.0),
                vec4(a.z, b.z, c.z, 0.0),
                vec4(a.w, b.w, c.w, 1.0));
}

mat4 sample_bone(int bone, vec3 frames) {
    mat4 a = palette_matrix(bone, int(frames.x + 0.5));
    mat4 b = palette_matrix(bone, int(frames.y + 0.5));
    return a * (1.0 - frames.z) + b * frames.z;
}

void vertex() {
    int row = int(INSTANCE_CUSTOM.x + 0.5);
    vec4 now = texelFetch(pose_state, ivec2(0, row), 0);
    vec4 old = texelFetch(pose_state, ivec2(1, row), 0);
    unit_tint = texelFetch(pose_state, ivec2(2, row), 0).rgb;
    mat4 skin = mat4(0.0);
    for (int k = 0; k < 4; k++) {
        float w = CUSTOM1[k];
        if (w > 0.0) {
            int bone = int(CUSTOM0[k] + 0.5);
            mat4 pose = sample_bone(bone, now.xyz);
            if (old.w < 0.9999) {
                mat4 previous_pose = sample_bone(bone, old.xyz);
                pose = previous_pose * (1.0 - old.w) + pose * old.w;
            }
            skin += pose * w;
        }
    }
    vec3 rest_n = NORMAL;
    vec3 rest_t = TANGENT;
    vec3 rest_b = BINORMAL;
    VERTEX = (skin * vec4(VERTEX, 1.0)).xyz;
    mat3 linear_part = mat3(skin[0].xyz, skin[1].xyz, skin[2].xyz);
    vec3 n = normalize(linear_part * rest_n);
    vec3 t0 = linear_part * rest_t;
    vec3 t = normalize(t0 - n * dot(n, t0));
    vec3 b0 = linear_part * rest_b;
    float handedness = dot(cross(n, t), b0) < 0.0 ? -1.0 : 1.0;
    NORMAL = n;
    TANGENT = t;
    BINORMAL = cross(n, t) * handedness;
}

void fragment() {
    ALBEDO = texture(albedo_tex, UV).rgb * unit_tint;
    NORMAL_MAP = texture(normal_tex, UV).rgb;
    ROUGHNESS = roughness_value;
}
```

The shader interface provides custom instance/vertex channels and local-space vertex modification. Texture-driven animation must not rely on shader `TIME`, which continues through scene pause. This shader instead consumes explicit sampled frames. [Spatial shader reference](https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/spatial_shader.html)

The shader uses matrix interpolation, not quaternion interpolation. It is inexpensive to author but can shrink joints during large rotations, and normal transformation is the conventional weighted-linear approximation. The asset error tests are mandatory. A quaternion/translation palette or VAT is the escalation if sword arcs, tails, or wings fail those tests. No GPU result feeds authoritative combat.

Without a transition, four influences require 4 × 2 × 3 = 24 palette texel reads per vertex invocation. During a transition this becomes 48; pose-state reads add three. Texture caching may reduce memory traffic, but this is not a claim of 24 independent memory transactions. Depth and shadow passes may repeat deformation. This is why low-poly LOD and shadow policy matter even after instancing.

### 2.6 Equipment without a batch explosion

Each model stores main-hand, off-hand, body, and head equipment IDs. Catalog ID 0 means empty. Prototype squad composition is exactly 30 swords, 18 spears, and 12 bows for a 60-model mixed squad. Armor uses two body variants; helmets use two head variants plus empty. This is a workload fixture, not a final balance rule.

1. **Color/material variation:** use one material atlas and per-model tint or atlas appearance index. Do not clone a material per soldier. UVs select fixed regions; if texture arrays are introduced, equal layer dimensions/formats are mandatory.
2. **Body armor:** prebuild two merged body+armor meshes per species per LOD. They use the same rig palette. Arbitrary combinations of deforming armor parts are not in the initial scope.
3. **Weapons/shields/helmets:** use separate geometry batches grouped by rig, socket, geometry, cell, and LOD. The root transform and pose row match the body. No per-frame CPU socket matrix evaluation is necessary.
4. **Rigid attachment construction:** transform each weapon vertex into body bind space using `p_bind = B[socket] * O[equipment] * p_weapon`. Give it one influence of weight 1 on `socket`. The skin matrix then yields `G[socket] * O[equipment] * p_weapon`. Normals/tangents use only the corresponding linear transform.
5. **Attachments requiring finger detail:** author the grip into the weapon-family clip. Do not attempt 1,600 procedural hand IK solvers. Different skeleton bind transforms require different prepared attachment meshes/palettes.
6. **Equipment changes:** commit equipment state at the simulation tick, then migrate all affected presentation parts together at the next extraction. During LOD changes the body and its attachments switch atomically.

At LOD3, replace small weapon geometry with a baked silhouette on the body variant only if its projected length is below 6 pixels. A visible spear remains visible even when the owner's body is small. Mixed weapon classes must remain identifiable at tactical inspection scale; collapsing the squad to a single weapon appearance would violate the core mechanic.

### 2.7 Explicit screen-space LOD

LOD uses **render-target pixels**, not window logical pixels and not Retina display pixels. Use projected bounding sphere diameter as a conservative proxy. For camera-space depth `z>0`, sphere diameter `h`, vertical FOV `f`, and render height `H`:

```text
pixels ≈ h * H / (2 * z * tan(f/2))
```

For real implementation project the eight corners of the animated world AABB; use the larger of projected body height and width, clipped safely at the near plane. A near-plane crossing object receives the highest mesh tier. Large wings and long tails are classified by their extent, not their biped standing height. Select `Camera3D.KEEP_HEIGHT` and a 55° vertical FOV for the test camera.

| Tier | Initial projected extent | Geometry ceiling/model including gear | Animation | Shadow policy |
|---|---:|---:|---|---|
| L0 | ≥180 px and admitted to skeletal pool | 12,000 triangles, 3 surfaces | Conventional skeleton, ≤64 bones; 60 Hz evaluation | Real sun shadow |
| L1 | 70–180 px, plus L0 overflow | 3,500 triangles, ≤2,400 body vertices | 4-influence bone texture, 30 Hz baked samples interpolated | Real sun shadow within 45 m |
| L2 | 24–70 px | 1,200 triangles, ≤800 body vertices | 2-influence bone texture, 15 Hz samples interpolated | Real sun shadow only within 25 m |
| L3 | 8–24 px | 350 triangles, ≤250 body vertices | 1-influence simplified mesh, 10 Hz samples | Blob/ground marker; no individual sun shadow |
| L4 | <8 px | Optional 2-triangle view atlas; otherwise retain L3 | 8 Hz sprite frames | No individual sun shadow |

Initial version ships L0–L3. L4 is an optional optimization only after its prototype wins on GPU time and visual readability. Large/giant creatures may use 2× geometry ceilings, but their measured scene contribution still must fit the global budget. This exception is represented in asset metadata and tested; it is not an unbounded override.

For a 1 m extent at 1080p/55°, the approximate distances at 180/70/24/8 pixels are **5.76 / 14.82 / 43.22 / 129.66 m**. Double the extent, double these distances. These are explanatory equivalents; the actual algorithm remains screen-space based.

Hysteresis: promote across threshold `T` only at `pixels >= 1.10*T`; demote only at `pixels < 0.90*T`. Require 0.20 seconds residence before a further tier change, except immediately promote a near-plane crossing. Rank L0 candidates by projected extent descending, distance ascending, then entity ID ascending. Cap at 48. Overflow retains L1 even at close range; this is an explicit fidelity compromise. Giants compete for this pool, with reserved access for up to 16 giant candidates before filling the remaining slots by the same ranking. If giants exceed the reservation, they compete normally.

Do not build an automatic full-skeleton→VAT→simplified→billboard chain merely because it sounds conventional. Our chosen chain is skeleton→bone-texture mesh→reduced bone-texture mesh→optional impostor. **If VAT wins the A/B test, substitute VAT at the same L1–L3 thresholds**, retaining a separate baked asset for each LOD topology. Do not maintain both crowd pipelines in shipping code without a measured need.

Godot's mesh LOD and visibility ranges can help manage geometry, but they do not define this project's per-model animation representation policy. Use explicit batch migration for representation changes. Disable imported automatic LODs for the initial VAT experiment; vertex remapping must not break VAT addressing. [Mesh LOD guide](https://docs.godotengine.org/en/4.7/tutorials/3d/mesh_lod.html), [Visibility ranges guide](https://docs.godotengine.org/en/4.7/tutorials/3d/visibility_ranges.html)

### 2.8 Impostor contract if enabled

Bake 8 azimuths × 3 elevations (15°, 40°, 65°), each with 8 idle frames and 8 locomotion frames. Each tile is 64×64 pixels including a 2-pixel dilated border; useful area is 60×60. There are 384 tiles, packed 16 columns × 24 rows into a 1024×1536 atlas. One RGBA8 atlas is 6,291,456 bytes before mips/compression; approximate full mip storage is 8 MiB. Each species/body appearance adds another atlas unless packed into an explicit shared atlas.

Select nearest elevation. Azimuth index is `floor((relative_yaw + PI/8)/(PI/4)) mod 8`. Locomotion frame is `floor(loop_phase*8) mod 8`. Use camera-facing quads, depth writes, and alpha scissor at 0.5; no blended transparent fur. At <8 px, combat can use the locomotion/idle representation without depicting individual sword impacts. Promote to L3 for attacks if the omission is visible in the test. Disable billboards within 20° camera elevation because flat cutouts become obvious. Test overdraw against L3 geometry; fewer triangles do not guarantee a faster atlas.

### 2.9 Draw, geometry, lighting, and effects budgets

Define `D_color = sum(visible batch surface counts) + sum(skeletal surface counts)`. Total draws additionally include depth, shadows, selection, terrain, vegetation, and effects. Never infer total draw count from the number of MultiMesh nodes.

| Category | Color-pass target | Counting example |
|---|---:|---|
| Crowd bodies | ≤72 | 6 active spatial groups × 2 species × 2 body variants × 3 occupied LODs |
| Crowd equipment | ≤96 | Bounded active weapon/socket combinations; log actual occupancy |
| L0 skeletal actors | ≤144 | 48 actors × 3 surfaces |
| Corpses | ≤24 | Grouped by body/palette/LOD, not individual nodes |
| Terrain/vegetation/buildings | ≤80 | Independent environment budget |
| Effects/selection/UI | ≤40 | Pooled particles and batched markers |
| **Color-pass planning ceiling** | **456** | Diagnostic, not an engine limit |

The 72-body example is a favorable layout, not a guarantee that 32 squads fit those keys. Eight species, many terrain cells, and all LODs occupied can exceed it. Qualification includes an 8-species fragmentation scene. If color draws exceed 456 or total draws exceed 900, inspect timing first, then merge render cells, atlases, or body variants. Do not delete gameplay equipment classes without a product-scope decision.

Planning workload at 1,600 models: 48 L0, 352 L1, 800 L2, 400 L3. Maximum triangles using the table are `48*12000 + 352*3500 + 800*1200 + 400*350 = 2,908,000` for one color traversal. All 1,600 at L1 is 5.6 million triangles. Shadows and depth can multiply submitted geometry. Measure both this tactical distribution and the adversarial all-L1 scene.

Default visual preset: one shadowed directional light; two directional shadow splits; 2048 directional shadow map; 60 m shadow maximum distance; no shadowed point lights; baked environment lighting/reflection data; no SDFGI, SSR, volumetric fog, motion blur, or real-time fur simulation. Use FXAA for the initial test; compare 2× MSAA separately. Do not enable TAA/upscaling until custom deformation motion-vector behavior is verified by a moving-character capture. Root motion vectors alone do not necessarily describe shader-deformed limbs.

Foliage uses opaque trunks and alpha-scissor leaves, at most two overlapping leaf layers along the principal tactical view in the fixture. Battle VFX ceiling: 256 visible particle sprites, 32 short-lived impact systems, 64 positional audio voices, 512 visible corpses. Pool all of them. Corpses freeze at the death clip's final frame, remain for 30 simulation seconds, then sink 0.15 m over 1 simulation second. At corpse capacity evict the oldest corpse, breaking ties by entity ID; this changes presentation only.

### 2.10 Bulk instance buffer pattern

With 3D transforms, custom data enabled, and colors disabled, the stride is **16 float32 values = 64 bytes**. Transform rows occupy indices 0–11; custom data occupies 12–15. The buffer length must match allocated instance capacity, even when fewer instances are visible. Keep a CPU-owned buffer; do not read it back from the renderer each frame. The row-major order is specified by `RenderingServer.multimesh_set_buffer(multimesh: RID, buffer: PackedFloat32Array)`. [RenderingServer buffer API](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-multimesh-set-buffer)

```gdscript
class_name CrowdBatch
extends RefCounted

const STRIDE: int = 16
var node: MultiMeshInstance3D
var mm: MultiMesh
var upload := PackedFloat32Array()
var capacity: int

func configure(parent: Node3D, mesh: Mesh, material: Material,
        max_instances: int) -> void:
    assert(max_instances > 0)
    capacity = max_instances
    mm = MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = false
    mm.use_custom_data = true
    mm.mesh = mesh
    mm.instance_count = capacity
    mm.visible_instance_count = 0
    upload.resize(capacity * STRIDE)
    upload.fill(0.0)
    node = MultiMeshInstance3D.new()
    node.multimesh = mm
    node.material_override = material
    node.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
    parent.add_child(node)

func write_instance(index: int, xf: Transform3D, pose_row: int,
        team: int, appearance: int) -> void:
    assert(index >= 0 and index < capacity)
    var o: int = index * STRIDE
    var b: Basis = xf.basis
    var p: Vector3 = xf.origin
    upload[o] = b.x.x
    upload[o + 1] = b.y.x
    upload[o + 2] = b.z.x
    upload[o + 3] = p.x
    upload[o + 4] = b.x.y
    upload[o + 5] = b.y.y
    upload[o + 6] = b.z.y
    upload[o + 7] = p.y
    upload[o + 8] = b.x.z
    upload[o + 9] = b.y.z
    upload[o + 10] = b.z.z
    upload[o + 11] = p.z
    upload[o + 12] = float(pose_row)
    upload[o + 13] = float(team)
    upload[o + 14] = float(appearance)
    upload[o + 15] = 0.0

func commit(visible_count: int, local_bounds: AABB) -> void:
    assert(visible_count >= 0 and visible_count <= capacity)
    mm.custom_aabb = local_bounds
    mm.buffer = upload
    mm.visible_instance_count = visible_count
```

The code supplies actual buffer construction, not simulation or visibility implementation. Its inputs are governed by this specification. Profile packed-array copies and engine-call overhead before replacing the loop. `mm.buffer = upload` is an upload/copy boundary, not guaranteed persistent mapped zero-copy memory. Engine interpolation is disabled because Section 6 uses a custom scheduler and presentation interpolation.

## 3. Animation design and crossover

### 3.1 Finite state and clip catalog

The initial biped palette has exactly 16 clips and 609 frames at 30 samples/second. A duration of `N` means N simulation ticks; stored samples are times `0/30 ... (N-1)/30`. Loops wrap to sample zero; nonloops hold sample N−1 for the final interval. This removes ambiguity about duplicated loop endpoints.

| ID | Clip | Frames/ticks | First atlas row | Loop | Required impact/release sample |
|---:|---|---:|---:|---|---:|
| 0 | idle | 60 | 0 | Yes | None |
| 1 | idle_alt | 90 | 60 | Yes | None |
| 2 | walk | 30 | 150 | Yes | None |
| 3 | run | 24 | 180 | Yes | None |
| 4 | turn_left | 18 | 204 | No | None |
| 5 | turn_right | 18 | 222 | No | None |
| 6 | brace | 30 | 240 | Yes | None |
| 7 | attack_a | 30 | 270 | No | 12 |
| 8 | attack_b | 36 | 300 | No | 14 |
| 9 | attack_c | 42 | 336 | No | 18 |
| 10 | hit | 12 | 378 | No | None |
| 11 | death_a | 45 | 390 | No | None |
| 12 | death_b | 54 | 435 | No | None |
| 13 | rout | 24 | 489 | Yes | None |
| 14 | ranged_fire | 36 | 513 | No | 10 |
| 15 | ranged_reload | 60 | 549 | No | None |

These are authoring requirements for the prototype clips, not measured existing assets. Species with flight or serpentine locomotion map logical idle/walk/run/rout to species-specific movement. Wing flap, glide, swim, takeoff, landing, climbing, burrowing, and siege actions need separate feature specifications before enabling those mechanics. A bird mesh does not imply free 3D navigation.

Different sword/spear/bow motion families may need separate clip blocks. Do not pretend one grip works for every weapon. For the first benchmark bake the 609-frame library per rig and use attack_a for sword, attack_b for spear, ranged_fire/reload for bow; author those clips with the proper hand positions. Additional weapon-family clips increase palette storage linearly.

State priority: DEAD > COMMITTED_ATTACK > HIT_COSMETIC > ROUT > BRACE > LOCOMOTION > IDLE. Cosmetic hit reactions do not delay damage or reset attack cooldowns. A committed attacker may complete its current impact while routing begins, but may not start another attack after the rout state is committed. Death cancels impacts on later ticks; simultaneous same-tick impacts use the tick-start living set.

### 3.2 Phase and transitions

For looping clip length `F`, sample rate `r=30`, start tick `t0`, playback multiplier `v`, phase offset `p0` in frames, and presentation time `t` in ticks:

```text
phase = positive_mod(p0 + (t - t0) * v, F)
f0 = floor(phase)
f1 = (f0 + 1) mod F
u = phase - floor(phase)
absolute_f0 = clip.first_row + f0
absolute_f1 = clip.first_row + f1
```

For nonloops clamp phase to `[0,F-1]` and clamp f1 to F−1. Initial idle/walk/run phase is `hash(entity_id, species_id) mod F`. Use a separate presentation hash so this never consumes combat RNG. Walk/run playback is `clamp(actual_root_speed / authored_speed, 0.8, 1.2)`; authored walk speed is 1.6 m/s, run 3.2 m/s for the prototype. Apply a fixed variation multiplier `0.96 + (hash mod 81)/1000`, yielding 0.96–1.04. This can produce some foot sliding; near-camera foot placement is the reason for the L0 pool.

Do not phase-randomize attack impacts, ranged releases, or deaths after the event is scheduled. Initial attack start delay is `combat_hash(entity_id, engagement_epoch) mod 6` ticks, explicitly part of the simulation. Subsequent attacks follow their cooldown. Pose sample 12 of attack_a must coincide with its authoritative impact tick in the presentation timeline.

Transitions last 4 ticks for locomotion/idle, 2 ticks into attacks or hits, 3 ticks into rout, and 0 ticks into death. Store the outgoing frame phase at transition start and hold that outgoing pose during the blend; this bounds state storage and shader work. Transition weight is `clamp((presentation_tick-blend_start_tick)/blend_ticks,0,1)`. Do not blend from a different rig palette. Immediate transitions into death are an explicit compromise to prevent a dead model continuing a previous pose blend.

### 3.3 Animation LOD is distinct from simulation LOD

| Representation | Authored sample cadence | Rendered pose behavior | State/event handling |
|---|---:|---|---|
| L0 | Source curves | Evaluate every rendered frame, target 60 Hz | Immediate |
| L1 | 30 Hz | Interpolate neighboring samples every render | Immediate |
| L2 | 15 Hz | Sample rows at 2-frame spacing, interpolate | Immediate |
| L3 | 10 Hz | Sample rows at 3-frame spacing; optional held poses only after visual pass | Immediate |
| L4 | 8 Hz sprite | Discrete sprite frames | Immediate representation state change |
| Culled | None rendered | Reconstruct current pose when visible | Logical events still processed |

Lower source sample cadence does **not** automatically reduce vertex shader invocations. Interpolating two 15 Hz samples still uses two palette samples every rendered frame. To reduce GPU work, reduce vertices/influences/passes or use held poses with one sample. To reduce CPU work, reduce pose bookkeeping/upload frequency for truly distant rows, while retaining event responsiveness. These savings must be measured separately.

For L2/L3 loops, sample on a cyclic grid of `step=2/3` with wrap handling; if F is not divisible by step, include F as an implicit sample of frame zero so the last interval has its actual shorter duration. For nonloops include final frame F−1 as an explicit endpoint. Never interpolate across clip atlas boundaries.

60 Hz to 30 Hz interpolated locomotion is usually a lower-risk sacrifice than 10 Hz held attack poses. Visibility depends on screen size, silhouette speed, and camera movement; this document does not claim a universal human-perception threshold. Test a thin spear tip, a wing tip, and a rotating tail at the threshold boundaries.

### 3.4 VAT fallback format and comparison

Bake mesh-space position and normal into two `RGBA16F` textures. Optional tangent+handedness uses a third. Every exported vertex receives a stable integer VAT ID in `CUSTOM2.x`; UV seam/hard-normal duplicates receive their own IDs. Triangulate and finalize topology **before** baking. Preserve the ID attribute through import. Reordering vertices is safe only if IDs remain attached; vertex creation/merging without consistent bake mapping is not.

For vertex ID `v`, absolute frame `f`, vertex count `V`, texture width `W=2048`:

```text
linear_texel = f*V + v
x = linear_texel mod W
y = floor(linear_texel/W)
height = ceil(total_frames*V/W)
position = mix(position_tex[f0,v], position_tex[f1,v], u)
normal = normalize(mix(normal_tex[f0,v], normal_tex[f1,v], u))
```

Do not apply a root translation both in VAT and in the instance transform. A VAT body still requires matching socket transforms or separately baked attachment vertices. Normal maps require animated tangents, or a validated reconstructed tangent basis; static bind-pose tangents are incorrect after large limb rotation.

| Storage example | Exact formula | Payload |
|---|---|---:|
| Bone palette, 64 bones, 609 frames | 64×3×609×8 | 935,424 B = 0.892 MiB |
| VAT, 3,000 vertices, 609 frames, position+normal, unpadded | 3000×609×16 | 29,232,000 B = 27.878 MiB |
| Same VAT, W=2048, H=893 | 2048×893×16 | 29,261,824 B = 27.906 MiB |
| Same VAT plus tangent texture | 2048×893×24 | 43,892,736 B = 41.860 MiB |

These are per mesh/rig animation libraries, not per instance. Bone palettes share across compatible bodies and gear; VAT bodies require separate data for each topology. Even bone palettes cannot share across different bind matrices without retargeting and rebaking.

### 3.5 Crossover is a measurement, with an explicit equation

Fit CPU costs from equal-content N={64,128,256,512,800,1600} runs:

```text
skeletal_CPU(N) = skeletal_fixed + N*skeletal_per_actor
instanced_CPU(N) = batch_fixed + N*extract_per_actor
N_cross = (batch_fixed-skeletal_fixed) /
          (skeletal_per_actor-extract_per_actor)
```

Use this only when the denominator is positive and the measured curves are locally linear. Example **illustration only**: an extra 0.6 ms fixed instancing cost and a 6 microsecond per-actor saving gives a CPU crossover at 100 actors. Those numbers are not Godot benchmark results. The winning path must also meet GPU time, memory, transition quality, and equipment correctness. Native skeletal rendering may win at 48 actors while losing at 800; VAT may beat bone textures on GPU while losing the asset-memory budget.

## 4. Simulation data layout

### 4.1 Ownership and entity lifecycle

Use a bespoke ECS-style store, not one Resource/Object per component instance. A `RefCounted` store owns packed columns and a few system objects; immutable `Resource` catalogs are suitable for authoring species, weapons, and clip definitions. Compile catalogs into integer lookup arrays before battle. Godot does not supply this game's ECS automatically.

Each model has a stable slot in `[0,2047]` and a generation counter. External handles are `(slot,generation)`; references validate both before use. Allocate the lowest free slot. Iterate an ascending active-slot array. Do not swap authoritative slots on death; compact only the active list and presentation batches. Deferred spawns/despawns are sorted by command sequence/entity ID and committed after damage/morale. Increment generation on reuse.

Squad membership is an indexed table `members[squad_id*64+k]`, 32×64 `PackedInt32Array` entries initialized to −1, plus count per squad. The stride permits up to 60 models and four reserved entries. Rebuild the affected squad's ascending member list on membership changes. A settlement citizen keeps its persistent ID when entering battle; battle slot is a separate transient mapping. Transfer HP/equipment/experience through an explicit catalog-versioned conversion at battle entry/exit.

### 4.2 Numeric representation

Authoritative position uses integer units of **1/1024 m**. XZ is a 2.5D ground plane; height is sampled from an integer map. One turn is 65,536 yaw units. Integers are stored in `PackedInt32Array`; intermediate arithmetic uses GDScript's 64-bit `int`. Clamp speed to 8 m/s and map coordinates to ±131,072 units (±128 m) for the initial 128 m square map centered at the origin.

Prebake a 4,096-entry signed sin/cos table at amplitude 32,767, indexed by `yaw >> 4`. Commit the integer table to source control; never regenerate it with platform trigonometry at runtime. Quantization is acceptable for simulation; renderer yaw uses float interpolation. Products of local position deltas, fixed direction values, HP, and damage in this bounded map fit signed 64-bit intermediates. Assert range invariants before storing 32-bit values.

| Godot type | Use | Reason |
|---|---|---|
| `PackedInt32Array` | Authoritative component columns, grid indices, distances, counters | Exact integer payload, compact numeric storage |
| `PackedInt64Array` | Long command sequence numbers and canonical tick metadata | Avoid overflow in long sessions |
| `PackedByteArray` | Flags with byte storage, map masks, canonical serialization | Exact byte layout |
| `PackedFloat32Array` | GPU transform buffers, pose texture staging, static vertex attributes | Renderer interface and compact float payload |
| `PackedVector3Array` | Presentation positions/bounds helpers only | Convenient float vectors; not cross-platform deterministic state |
| Typed `Array[Resource]` | Small immutable authoring catalogs | Useful editor tooling; excluded from inner loops |
| Typed `Array[SomeSystem]` | Small fixed system registry | No per-entity iteration dispatch |
| `Dictionary` | Import metadata and cold-path key lookup | Never authoritative iteration order or hot numeric storage |

Packed arrays require deliberate ownership. Keep hot columns as direct store fields; avoid access patterns that fetch property copies or allocate temporary arrays in loops. Packed storage improves layout but does not turn GDScript arithmetic into SIMD/native compiled loops. [PackedInt32Array API](https://docs.godotengine.org/en/4.7/classes/class_packedint32array.html)

### 4.3 Model schema: 256 bytes of column payload per capacity slot

Every field below is one signed 32-bit integer unless otherwise stated. A row describes a group of **separate contiguous columns**, not a dictionary allocated per model.

| Group | Fields, in canonical serialization order | Bytes/model |
|---|---|---:|
| Identity | entity_id, generation, squad_id, species_id, team_id, flags | 24 |
| Transform snapshots | x, y, z, yaw; prev_x, prev_y, prev_z, prev_yaw | 32 |
| Motion | vx, vz, speed_limit, accel_limit, move_remainder_x, move_remainder_z | 24 |
| Formation | slot_id, slot_offset_x, slot_offset_z, formation_epoch | 16 |
| Vitals | hp, max_hp, armor, fatigue, attack_skill, defense_skill | 24 |
| Combat | target_slot, target_generation, next_attack_tick, impact_tick, attack_sequence, pending_damage, weapon_id, attack_start_tick | 32 |
| Equipment | main_hand_id, off_hand_id, body_id, head_id | 16 |
| Animation intent | clip_id, clip_start_tick, phase_q16, rate_q16, outgoing_clip_id, outgoing_phase_q16, blend_start_tick, blend_ticks | 32 |
| Indexing | active_index, visual_slot, grid_next, grid_cell | 16 |
| Random stream | rng_state, stored as signed bits and read with mask `& 0xffffffff` | 4 |
| Movement scratch | next_x, next_z, correction_x, correction_z | 16 |
| Lifecycle/rout | death_tick, rout_goal_x, rout_goal_z, rout_epoch, blocked_ticks | 20 |
| **Total** | 64 integer columns | **256** |

`vx/vz` are units/second; displacement remainders preserve division by 30. `speed_limit` is units/second, `accel_limit` units/second². `hp`, `armor`, and skills are integer fixture values. Animation intent is reproducible but not allowed to determine combat timing. `outgoing_phase_q16` freezes the outgoing pose at transition start. Scratch/index fields are reset or rebuilt before they are read after loading; the canonical state hash policy distinguishes them in Section 6.

```gdscript
class_name ModelStore
extends RefCounted

const CAPACITY: int = 2048
var active := PackedInt32Array()
var x := PackedInt32Array()
var z := PackedInt32Array()
var prev_x := PackedInt32Array()
var prev_z := PackedInt32Array()
var hp := PackedInt32Array()

func _init() -> void:
    x.resize(CAPACITY)
    z.resize(CAPACITY)
    prev_x.resize(CAPACITY)
    prev_z.resize(CAPACITY)
    hp.resize(CAPACITY)
    x.fill(0)
    z.fill(0)
    prev_x.fill(0)
    prev_z.fill(0)
    hp.fill(0)

func capture_previous_positions() -> void:
    for j in range(active.size()):
        var i: int = active[j]
        prev_x[i] = x[i]
        prev_z[i] = z[i]
```

This snippet demonstrates ownership and access for selected columns. Generate the remaining declarations from the complete schema table; the table, not this shortened example, defines the full store. No model method call is needed in the loop.

### 4.4 Squad schema and update frequency

Allocate 256 bytes per squad: 48 `int32` fields plus 64 reserved zero bytes. The 48 fields in order are:

```text
squad_id, team_id, species_id, alive_count,
anchor_x, anchor_z, previous_anchor_x, previous_anchor_z,
facing_yaw, desired_yaw, order_kind, order_sequence,
goal_x, goal_z, field_id, field_generation,
columns, rows, spacing_u, formation_epoch,
morale, base_morale, losses_30_ticks, engaged_count,
front_contact_count, flank_contact_count, rear_contact_count, rout_state,
rout_start_tick, rally_ticks, desired_speed_u, movement_layer,
target_squad_id, command_tick, blocked_ticks, portal_reservation,
initial_count, casualties_total, fatigue_sum, leader_alive,
nav_goal_cell, nav_request_id, nav_revision, formation_change_tick,
threat_x, threat_z, rng_state, flags
```

| System | Cadence | Per-squad versus per-model work |
|---|---:|---|
| Commands/lifecycle | Every tick | Stable sorted commands and handle validation |
| Squad orders/anchors | 30 Hz | Route and facing intent shared by squad |
| Formation shape decisions | 5 Hz, every 6 ticks | Columns, corridor width, slot compaction |
| Field builder | Every tick, fixed work quota | Shared route costs by goal/movement class |
| Model integration/separation | 30 Hz | Physical model positions and bounded neighbors |
| Target acquisition | 10 Hz, every 3 ticks | Per-model candidates from spatial grid |
| Committed impacts | 30 Hz | Exact per-model impact tick |
| Morale/rout decisions | 5 Hz, every 6 ticks | Squad-level aggregation |
| Presentation | Render cadence | No authoritative writes |

Do not compute an independent global path or strategic goal for every model. Do simulate per-model HP, loadout, nearby contacts, attack schedule, local position, death, and rout movement because mixed weapons and visible individual casualties require them. Squad economy, global navigation goal, cohesion state, and morale belong at squad level.

## 5. Movement, formations, and combat

### 5.1 Navigation representation and flow fields

Initial map is 128 m × 128 m, 256×256 cells at 0.5 m. Cell index is `z_cell*256+x_cell`, with world origin at (−64,−64) m. Clamp goal coordinates to legal cells; reject goals without a passable projected destination.

Static map columns: walkability byte; movement layer byte; terrain cost int32; height int32; clearance int32. Terrain cost is 0 on flat soil, 2 in shallow mud, 5 on steep traversable slopes; blocked cells are a separate mask. Maximum traversable ground slope is 25°. Bake mask/height/clearance offline and serialize integers so runtime physics queries do not affect routes.

Small/medium/large/giant collision radii are 184/246/461/922 units (approximately 0.18/0.24/0.45/0.90 m). Flow fields are keyed by `(goal_cell, radius_class, movement_layer, map_revision)`. Ground radius classes are these four values. Clearance must be at least radius + 128 units. Clearance means the minimum distance from the cell center to any blocked cell rectangle or map boundary, floored to integer units; compute it offline from geometry. Map border clearance is not infinite.

Build a reverse Dijkstra integration field with 8-connected neighbors. Orthogonal edge cost is 10, diagonal 14, plus the destination terrain cost. For reverse expansion from settled cell `c` to predecessor `p`, use `I[p] = min(I[p], I[c] + base(p,c) + terrain[c])`. A diagonal is legal only if both adjacent orthogonal cells are passable for that radius. `INF=0x3fffffff`.

Use a preallocated indexed binary min-heap with at most one entry per cell and decrease-key. Heap comparison is `(integration_cost, cell_index)`. Neighbor tie order is N, E, S, W, NE, SE, SW, NW. Store int32 integration values and one byte direction index per field. Derive direction by choosing the legal neighbor minimizing `edge(c,n)+I[n]`, then the fixed neighbor order. If no finite neighbor exists, mark unreachable and stop the requester.

Cache at most 16 completed fields. Evict the unreferenced field with the oldest last-use **simulation tick**, ties by field ID. Share identical requests. Process one pending build at a time in ascending request sequence, with **2,048 settled cells per simulation tick** total. Maintain the heap and partial arrays across ticks. A field becomes visible to simulation only when complete at a tick boundary; models never follow unfinished gradients. A full 65,536-cell build can take 32 ticks (1.067 s), and many distinct goals can queue much longer. This is a known weakness of whole-map fields.

While a new field is pending, an already moving squad follows its previous valid order; a newly ordered idle squad holds. The UI shows a pending path. Prototype P6 requires p95 new-order route readiness ≤0.25 s for normal commands and ≤0.75 s for a burst of eight distinct goals. If that fails, this whole-map implementation is rejected: test squad-level deterministic A* corridors plus 32×32 local fields, or move the field builder to native code and increase its fixed quota while preserving the tick budget. **Do not ship one-second-plus routine command latency just to keep a GDScript implementation.**

This explicit latency test may kill whole-map fields before simulation itself becomes expensive. At only 32 independently commanded squads, a squad-level A* path with formation steering can be the better solution. Flow fields are valuable when many models share a goal, not automatically the best global planner for every RTS.

Navigation uses independent masks for GROUND=0, AIR_LOW=1, WATER=2. The initial school slice supports GROUND only; birds can be grounded units or visual hoverers with identical ground collision. Actual flying/eel traversal requires importing the other masks and specifying takeoff/landing/access rules. Do not route water-only entities over land as an undocumented fallback.

### 5.2 Formations through obstacles

Default formation columns are `min(10, ceil_sqrt(alive_count))` for small units, `min(8,ceil_sqrt(N))` for medium, `min(5,ceil_sqrt(N))` for large; giants use 1. Here `ceil_sqrt` is the smallest integer c with c²≥N. Rows are `ceil(N/columns)`. Slot spacing is `2*max_member_radius + 154` units (0.1504 m gap).

For slot index s, column c=s mod columns, row r=floor(s/columns):

```text
local_x = trunc(((2*c - (columns-1))*spacing_u)/2)
local_z = r*spacing_u
goal = anchor + right(facing)*local_x - forward(facing)*local_z
```

`forward(0)` is world −Z. Anchor is the center of the front row. Rotate using the committed integer sin/cos table and signed truncating integer division. Assign members to slots in weapon-group order (melee first, spear second, bow last), then persistent entity ID. Within-group casualties leave holes until the 5 Hz formation pass compacts slots. On a slot-layout change set the squad's `formation_change_tick=k`. Each following tick move the stored offset toward its newly derived slot offset using `offset += trunc((target_offset-offset)/max(1,12-(k-formation_change_tick)))` on each axis, snapping to target at age 12. This reaches the new offset within 12 ticks without storing an additional previous-offset array; another layout change restarts the remaining-time schedule from the current offsets.

Look ahead along the field for six cells. Let `C` be minimum centerline clearance along that lookahead. The legal maximum columns are `max(1, 1 + floor(2*(C-radius-128)/spacing))`, clamped to the squad's default column count. Reduce immediately at the formation pass; restore width only after 30 ticks of continuously sufficient clearance. A flow field for one body does not prove that a whole rectangular formation fits; this compression rule addresses that distinction.

A model follows its slot if a grid supercover line from its root to the slot is passable for its own radius and the slot is within 2 m. Otherwise it follows the shared field direction until that condition becomes true. Do not steer directly through the inner corner of a wall merely because the squad anchor has cleared it.

Desired velocity is normalized from `4*slot_direction + 2*flow_direction + separation_direction`, each direction in the same fixed-point scale. If slot following is illegal, its coefficient becomes zero. Far from its slot (>1 m), a nonrouting model may move at 1.10× squad speed, bounded by its species speed cap. The squad anchor slows to 0.65× when more than 25% of members lag by over 1.5 m; it stops when more than 50% lag. This preserves visual cohesion at the cost of delayed movement.

Define integer normalization `unit(dx,dz)=(trunc(dx*32767/d),trunc(dz*32767/d))`, with `d=floor_sqrt(dx²+dz²)`; return (0,0) when d=0. The separation direction is the normalized sum of overlapping-neighbor displacement vectors from the previous completed tick's positions, using the same bounded neighbor set. Desired velocity is `trunc(unit(steering)*desired_speed/32767)` componentwise. Let `dv=desired_velocity-current_velocity`; add `unit(dv)*min(length(dv),floor(accel_limit/30))/32767` to velocity with truncation, snapping exactly to desired velocity when its difference is within that step. Re-clamp speed to the species cap after acceleration.

Fixture speed caps are small3277, medium4096, large3072, giant5120 units/second; acceleration limit is4096 units/second² for all. Normal march speed is1638 units/second, ordered run speed is the lowest member cap. Turn squad facing by at most728 yaw units/tick along the shortest signed yaw difference; exactly half-turn ties rotate clockwise. Formation directions use the updated facing. These values are prototype movement constants, and the global8192-unit/second guard still applies to future catalogs.

Precompute single-lane corridor IDs at map bake for cells with width <2.0 m. Reserve each connected corridor to one squad at a time in request-tick, then squad-ID order; expire an unused reservation after 90 ticks. Release after the last member leaves. Opposing sides contest entrances through combat; reservation does not grant permission to pass through an enemy. This avoids friendly two-way oscillation in narrow paths.

### 5.3 Integration and inexpensive separation

Use a uniform XZ hash grid with 2 m cells (64×64 cells on this map). Maximum normal diameter is 1.80 m, so potentially overlapping centers are in the same or neighboring cells. Build lists deterministically in descending active slot order, inserting at the head so iteration within a cell is ascending. Grid links use the columns in Section 4.

For each model, inspect the center cell then the eight neighbors in fixed clockwise order starting north. Scan at most 64 candidates in total, retain the nearest 12 by `(squared_distance, entity_id)`, and record a truncation counter. This deliberately bounds work but is approximate in severely packed crowds; it cannot guarantee nonoverlap. Never describe a 12-neighbor soft solver as exact collision physics.

Perform two Jacobi separation iterations: read the same iteration positions, accumulate corrections independently, then apply together. For neighbors with `d < r_i+r_j`, correction contribution is `normal(i-j) * min((r_i+r_j-d)/2, 51 units)`. Cap total correction magnitude at 102 units (≈0.10 m) per iteration. Exact coincident pairs choose an axis from `hash(min_id,max_id) mod 4`; reverse its sign for the other model. This prevents zero-distance division and preserves an opposing push direction.

Use integer floor square root for distance. Clamp all trial positions to passable map cells with sufficient clearance. Calculate displacement from velocity/30 once per tick with remainder accumulation, then split each component into `trunc(displacement/2)` and `displacement-first_half`. Integrate these two fixed substeps and reject blocked substeps; try X-only sliding then Z-only sliding, with axis order reversed on odd entity IDs to reduce systematic bias. Do not apply velocity/30 independently twice. Remainder accumulation prevents long-run fractional movement loss. Collisions with static terrain are constrained; model-model overlap is soft and verified by the congestion gate.

Steering normalization and correction use 64-bit products and signed division truncating toward zero. Never call float `Vector3.normalized()` in authoritative movement. The renderer may use it freely.

```gdscript
static func floor_sqrt(n: int) -> int:
    assert(n >= 0)
    var remainder: int = n
    var result: int = 0
    var bit: int = 1 << 62
    while bit > remainder:
        bit >>= 2
    while bit != 0:
        if remainder >= result + bit:
            remainder -= result + bit
            result = (result >> 1) + bit
        else:
            result >>= 1
        bit >>= 2
    return result

@warning_ignore("integer_division")
static func displacement_component(velocity_u_per_s: int,
        remainder: int) -> Vector2i:
    var numerator: int = velocity_u_per_s + remainder
    var whole: int = numerator / 30
    return Vector2i(whole, numerator - whole * 30)
```

The square-root routine is a correctness reference and may become a GDScript hotspot. Measure it within the full separation kernel. Do not move just one sqrt call across a native boundary per pair; move the whole grid/separation pass if needed.

### 5.4 Combat: bounded individual contacts

Recommended resolution is **per-model HP and attacks with bounded local target acquisition**, controlled by squad orders. It is not all-pairs combat, and it is not a statistical squad casualty model disguised as individual duels.

All-pairs distance testing at 1,600 models is 1,279,200 unordered pairs per pass, before eligibility checks; directed loops are 2,558,400 pairs. A bounded 12-candidate pass is at most 19,200 directed candidates. The spatial grid makes this a plausible CPU workload, but GDScript cost still needs measurement.

At the 10 Hz acquisition pass retain the current valid enemy within range; otherwise choose the nearest eligible enemy among retained grid candidates, ties by ID. Melee acquisition uses a separate range-sized grid query: search cell radius `ceil((self_radius+922+weapon_reach_extra)/2048)`, up to a 5×5 neighborhood for the fixture. Visit cells in increasing ring radius, then cell index; scan at most 64 enemies and retain the nearest 12. Do not reuse a separation-only 3×3 query for a giant's spear range. Bows select a target squad at squad level and scan that squad's ≤60 members, selecting the nearest legal target by range/line-of-sight then ID. Bow acquisition is staggered by `entity_id mod 3` so every archer updates once per 3 ticks. Ground line-of-sight uses the integer supercover grid with24 m world range; allow128 visited cells including corner-touch side cells. Do not equate24 m range with48 total supercover visits on a diagonal.

| Weapon fixture | Range | Base damage | Armor penetration | Start-to-impact | Minimum start-to-start cooldown |
|---|---:|---:|---:|---:|---:|
| Sword | radii sum + 410 units | 12 | 2 | 12 ticks | 30 ticks |
| Spear | radii sum + 1024 units | 10 | 4 | 14 ticks | 36 ticks |
| Bow | 24 m center-to-center | 9 | 1 | Release at 10 ticks; flight added | 96 ticks |

Prototype soldiers have HP=100, armor=4, attack_skill=600, defense_skill=500. These are executable benchmark values; they are not a complete faction economy/balance specification.

At attack start, commit source, target handle, start tick, impact tick, and attack sequence. At melee impact validate both handles and range with a 256-unit tolerance. A miss due to out-of-range does not retarget. The defender's relative direction is measured against its facing using an integer normalized dot product: front if dot≥16384, rear if dot≤−16384, otherwise flank, with directions scaled to 32767.

```text
flank_bonus = 0 front, 100 flank, 200 rear
hit_per_mille = clamp(650 + attack_skill - defense_skill + flank_bonus, 100, 950)
hit = next_combat_u32(attacker) mod 1000 < hit_per_mille
damage = max(1, base_damage - max(0, armor - armor_penetration))
```

Modulo introduces a tiny known bias; it is acceptable for this prototype and deterministic. RNG advances once for every scheduled melee attempt whose source was alive at the start of the impact tick, even if range/target validation fails; invalid attempts discard the roll. Process attempts in attacker ID, then attack-sequence order. Accumulate damage, then apply it simultaneously. A model killed this tick can still land a same-tick committed impact; it cannot land future impacts.

For bows, resolve a logical projectile at release: integer origin/target snapshot, `flight_ticks=max(1,ceil(distance_u*30/20480))` for 20 m/s. Store target handle and predicted impact cell. At arrival test target still alive and within 768 units of predicted impact position; otherwise miss. Apply the same hit rule with no flank bonus. The visual arrow follows a parabola from release position to predicted impact position with peak height 1.5 m above the straight segment. Decorative arrow position never determines damage. No rigid-body arrow simulation is required.

Statistical squad combat is cheaper and suitable for distant strategic battles, but it weakens spatial weapon reach, identifiable casualties, and flanking at model level. Do not switch combat algorithms when the camera zooms: that would make camera movement change outcomes. If statistical resolution is chosen later, use it everywhere in that battle mode and specify its attribution rules separately.

### 5.5 Morale, flanking, and rout fixture

Morale is an integer 0–1000, initial/base morale 700. Every 6 ticks calculate:

```text
loss_per_mille = floor(1000*deaths_in_last_30_ticks / max(1,initial_count))
flank_fraction = floor(1000*flank_contacts / max(1,all_contacts))
rear_fraction = floor(1000*rear_contacts / max(1,all_contacts))
pressure = floor(loss_per_mille/8) + floor(flank_fraction/50)
           + floor(rear_fraction/25) + (20 if leader_dead else 0)
recovery = 8 if all_contacts==0 and loss_per_mille==0 else 0
morale = clamp(morale + recovery - pressure, 0, base_morale)
```

Contacts count unique engaged defenders classified against their facing, not every duplicate pair. Maintain a per-squad 30-entry casualty ring, one entry per tick, for exact rolling losses. Route when morale≤200. Rally is allowed only after 150 ticks without contacts, with morale≥400 and at least 25% of initial members surviving. Route ends at the 5 Hz morale pass; it never depends on a visual animation completion.

At rout entry, stop assigning formation slots. Each member's escape direction is away from the squad's mean enemy-contact position, plus deterministic angular spread in [−30°,30°] from `(entity_id,rout_epoch)`. Project an escape goal 12 m away onto a reachable cell using a fixed ring search up to 8 cells, with ties by cell index; if none is reachable, hold and retry after 15 ticks. Routing uses the same obstacle/separation solver, a 1.15× speed multiplier capped at species maximum, and no cohesion slowdown. Recompute escape goal every 30 ticks. Bodies visibly disperse because the formation constraint is removed, not because their renderer moves independently of simulation.

## 6. Determinism, pause, and render interpolation

### 6.1 Determinism definition

Required: identical authoritative state for identical initial catalog/map hashes, seed, commands, and completed tick count across the qualified Mac/Windows builds. Rendering pixels, animation float interpolation, camera motion, particle placement, and elapsed wall time do not have to match. This is stronger than merely “same machine, same seed.” Multiplayer lockstep is not part of this document, but the replay boundary can support later networking work.

| Hazard | Required rule |
|---|---|
| Float differences across CPU architectures/compiler paths | Integer authoritative math; floats end at input quantization or presentation |
| Variable `delta` | Use delta only to schedule fixed ticks; never in damage/navigation/movement equations |
| Engine physics | No per-model engine physics in authoritative simulation; static collision comes from the baked integer map |
| `randf()`/global RNG | Use explicit isolated integer streams with a specified algorithm |
| Dictionary/hash iteration | Sort keys or use packed arrays and fixed iteration order |
| Parallel writes/reductions | Read immutable tick snapshots; reduce in entity ID order |
| Async navigation completion | Fixed expansion quota and deterministic commit ticks, not whichever worker finishes first |
| Animation callbacks/root motion | Animation observes combat events; it cannot generate authoritative damage or displacement |
| Wall clock/OS timing | Diagnostics only; never a tie-breaker, random seed, or AI input |
| Floating input raycasts | Quantize the resulting command destination and record it; replay consumes the quantized command, not a repeated raycast |
| GPU compute/readback | No authoritative decisions from GPU results |
| Engine upgrades | Increment replay compatibility version and rerun parity gates |

Godot's RNG implementation is an implementation detail and should not be treated as a guaranteed cross-version replay format. A stored seed alone is insufficient when draw order changes. [RandomNumberGenerator API](https://docs.godotengine.org/en/4.7/classes/class_randomnumbergenerator.html)

Use this explicitly specified 32-bit xorshift stream for the prototype. Zero state is forbidden; initialize each stream with a deterministic integer hash and replace zero with 1. This is gameplay randomness, not cryptographic randomness.

```gdscript
static func next_u32(state: int) -> int:
    var x: int = state & 0xffffffff
    assert(x != 0)
    x = (x ^ ((x << 13) & 0xffffffff)) & 0xffffffff
    x = (x ^ (x >> 17)) & 0xffffffff
    x = (x ^ ((x << 5) & 0xffffffff)) & 0xffffffff
    return x

static func hash_pair(a: int, b: int) -> int:
    var h: int = (a ^ 0x9e3779b9) & 0xffffffff
    h = (h * 1664525 + 1013904223 + (b & 0xffffffff)) & 0xffffffff
    h = (h ^ (h >> 16)) & 0xffffffff
    return h
```

Store unsigned state into signed int32 columns as `state if state<2147483648 else state-4294967296`; recover with `& 0xffffffff`. Seed fixtures use battle_seed=123456789 and model seed `hash_pair(battle_seed, entity_id)`, replacing zero with 1. Presentation phase uses `hash_pair(entity_id,species_id)` without touching this stream.

### 6.2 Tick order and read/write ownership

The scheduler invokes the following stages in exactly this order for tick k:

1. Copy current transforms to previous transforms. Clear damage and correction scratch. Initialize casualty-ring entry `k mod 30` to zero.
2. Consume commands stamped k in `(player_id, command_sequence)` order; validate handles and commit orders/equipment.
3. Advance the navigation builder by its fixed quota; publish completed field results.
4. Run due squad formation/order decisions and compute anchor desired movement.
5. Build the spatial grid from tick-start positions; compute desired model velocities.
6. Integrate static-constrained movement, rebuild the grid, then execute two separation iterations with snapshot reads and simultaneous writes. Rebuild the grid after each iteration.
7. Run due target acquisition; create attacks whose next-start tick has arrived.
8. Resolve due melee impacts and logical projectile arrivals from the tick-start living set; accumulate damage in deterministic order.
9. Apply all accumulated damage simultaneously; update casualties and due morale/rout decisions.
10. Derive animation intents/events from committed simulation transitions; copy death presentation data before freeing any slot.
11. Commit lifecycle changes, rebuild affected membership/active arrays, and increment completed tick count.
12. Produce the canonical hash in verification mode and publish the snapshot to presentation.

Attack starts and impacts on the same tick follow this order; the fixture has nonzero windups. If a future weapon has zero windup, its same-tick attempt participates after acquisition and before damage application. Movement is resolved before range checks, using this tick's final positions; simultaneous survival eligibility is still taken from the start of the tick.

### 6.3 Fixed scheduler with clean pause

Use a dedicated simulation clock node in `_process`, with a 30 Hz accumulator. This keeps the ECS independent of Godot's physics tick configuration. Do not also run its systems from `_physics_process`. Physics interpolation is off for ECS presentation nodes; otherwise two interpolation layers would add lag or corrupt instance transitions.

The callback `step_fn(k)` executes the full tick order above. The callback `present_fn(alpha,tick_time)` extracts previous/current snapshots; `alpha=0` selects previous and `alpha=1` selects current. The following scheduler is complete for clocking; callback implementations are the systems specified elsewhere in this document.

```gdscript
class_name BattleClock
extends Node

const STEP: float = 1.0 / 30.0
const MAX_STEPS_PER_FRAME: int = 4
const MAX_BACKLOG: float = 0.25

var completed_tick: int = 0
var accumulator: float = 0.0
var paused: bool = false
var overloaded: bool = false
var presentation_tick: float = 0.0
var step_fn: Callable
var present_fn: Callable

func configure(step_callback: Callable, presentation_callback: Callable) -> void:
    assert(step_callback.is_valid() and presentation_callback.is_valid())
    step_fn = step_callback
    present_fn = presentation_callback
    process_mode = Node.PROCESS_MODE_ALWAYS

func set_battle_paused(value: bool) -> void:
    if paused == value:
        return
    paused = value
    accumulator = 0.0
    if paused:
        # Snap by at most one simulation interval to the committed tick.
        presentation_tick = float(completed_tick)

func _process(delta: float) -> void:
    if not step_fn.is_valid() or not present_fn.is_valid():
        return
    if not paused and not overloaded:
        accumulator += maxf(delta, 0.0)
        var steps: int = 0
        while accumulator >= STEP and steps < MAX_STEPS_PER_FRAME:
            step_fn.call(completed_tick + 1)
            completed_tick += 1
            accumulator -= STEP
            steps += 1
        if accumulator > MAX_BACKLOG:
            # Diagnostic stop: preserve backlog and every completed tick.
            overloaded = true
    if paused:
        presentation_tick = float(completed_tick)
    else:
        var a: float = clampf(accumulator / STEP, 0.0, 1.0)
        var candidate: float = maxf(0.0, float(completed_tick - 1) + a)
        # Prevent visual time running backward after a pause snap.
        presentation_tick = maxf(presentation_tick, candidate)
    var alpha: float = 1.0
    if completed_tick > 0:
        alpha = clampf(presentation_tick - float(completed_tick - 1), 0.0, 1.0)
    present_fn.call(alpha, presentation_tick)
```

Initialize previous=current before the first tick. The ordinary render path is one simulation interval behind current state; this is the standard cost of interpolation without prediction. At pause, choosing the completed tick gives exact tick inspection and may advance visuals by at most 33.33 ms. Resume holds the snapped pose until the delayed timeline catches up, preventing a backward jump. If the desired product behavior is to freeze the exact displayed subframe instead, that is a separate presentation policy; it cannot simultaneously promise an integer-tick visual snapshot.

The overload diagnostic freezes further scheduling and displays an error; it does not silently skip simulation ticks. Recovery is explicit: clear `overloaded` and allow remaining backlog to drain, or pause and resume to discard wall-time debt while preserving the exact simulation state. Benchmark runs fail on overload. A shipping slow-motion policy must be separately visible to the player; this architecture never hides sustained overload behind a 60 FPS camera.

For root presentation use `lerp(prev_position,current_position,alpha)` and shortest-arc yaw interpolation; divide integer positions by 1024 only at extraction. Teleports/spawns set previous=current. Animation sampling uses the same `presentation_tick`, including clip transitions from the previous snapshot until their event tick is reached. Retain the preceding tick's animation intent/events in the presentation snapshot so a newly committed attack/death does not appear one tick early.

Pause is a simulation gate, not `Engine.time_scale=0`. Camera and UI run on unscaled frame delta. If menus also use `SceneTree.paused`, keep camera/UI at `PROCESS_MODE_ALWAYS` and ensure the dedicated clock remains the authority. Godot process modes determine what still runs under tree pause; they do not automatically freeze custom shader time. [Pausing guide](https://docs.godotengine.org/en/4.7/tutorials/scripting/pausing_games.html), [Interpolation introduction](https://docs.godotengine.org/en/4.7/tutorials/physics/interpolation/physics_interpolation_introduction.html)

L0 `AnimationPlayer` instances use manual processing; advance or seek from presentation time, and disable gameplay method/audio tracks. `AnimationMixer.callback_mode_process = ANIMATION_CALLBACK_MODE_PROCESS_MANUAL` and `advance(delta: float)` provide the manual evaluation path. `AnimationPlayer.seek(seconds: float, update: bool = false, update_only: bool = false)` can initialize a promoted actor at its current clip time. Freeze their evaluation on pause. [AnimationMixer API](https://docs.godotengine.org/en/4.7/classes/class_animationmixer.html), [AnimationPlayer API](https://docs.godotengine.org/en/4.7/classes/class_animationplayer.html)

### 6.4 Canonical replay and save contract

Replay header contains `format_version=1`, engine patch string, simulation rules hash, catalog hash, navigation-map hash, integer lookup-table hash, battle seed, and initial state. Commands are fixed 48-byte records: 12 little-endian int32 fields `(tick,player_id,sequence_low,sequence_high,kind,squad_id,target_slot,target_generation,goal_x,goal_z,arg0,arg1)`. Sequence is reconstructed as an unsigned 64-bit value for ordering. Reserve `kind`: MOVE=1, ATTACK=2, HALT=3, SET_FORMATION=4, SET_EQUIPMENT=5. Pause is a scheduler event recorded separately for playback timing; it never consumes combat RNG.

Encode signed 32-bit values as their two's-complement low 32 bits, explicitly little-endian. Do not hash `Dictionary` serialization or platform-native object memory. Use SHA-256 over canonical bytes for parity testing. `HashingContext.start(HashingContext.HASH_SHA256)`, `update(PackedByteArray)`, and `finish()` are the intended engine API; hashing runs every tick only in validation and every 300 ticks in normal replay recording. [HashingContext API](https://docs.godotengine.org/en/4.7/classes/class_hashingcontext.html)

Canonical order: header numeric fields, completed tick, model slots ascending, squad slots ascending, projectiles ascending, queued commands in execution order, pending navigation request/heap arrays in their defined order, casualty rings, then RNG states. Exclude GPU buffers, visual LOD/batch slots, camera state, active_index, visual_slot, grid_next/grid_cell, movement scratch, and reserved padding. Include current/previous authoritative transforms and animation intent for reproducible presentation tests. Include field-builder progress because future path availability depends on it.

Save all included state plus explicit occupied-slot bitsets/generations and completed tick. On load, rebuild derived active lists, spatial grid, render mappings, and buffers; set presentation previous=current for the first displayed frame while retaining the saved authoritative previous fields for parity checks. A save/load continuation must match uninterrupted replay hashes after the next completed tick. Do not serialize engine RIDs or NodePaths as model identity.

Cross-platform test: run 18,000 ticks (10 simulation minutes) on Mac Metal, Windows Vulkan, and Windows D3D12 using the same command log; compare every hash. On first mismatch, dump changed column names/slots and the last 30 commands. A matching final hash alone is insufficient evidence if intermediate states were never compared.

## 7. Memory budget

### 7.1 Live model column payload

Values below are decimal bytes and exclude packed-array headers, resource objects, allocator overhead, and render/server copies. “At 800/1600” is logical occupied payload; allocated capacity is normally 2,048, so the actual store occupies 524,288 bytes even with 800 living models.

| Data | Bytes/model | At 800 models | At 1,600 models |
|---|---:|---:|---:|
| Identity | 24 | 19,200 | 38,400 |
| Transform, current + previous | 32 | 25,600 | 51,200 |
| Velocity, limits, movement remainders | 24 | 19,200 | 38,400 |
| Formation | 16 | 12,800 | 25,600 |
| Vitals/combat stats | 24 | 19,200 | 38,400 |
| Combat scheduling | 32 | 25,600 | 51,200 |
| Equipment IDs | 16 | 12,800 | 25,600 |
| Animation intent | 32 | 25,600 | 51,200 |
| Indices/membership links | 16 | 12,800 | 25,600 |
| RNG | 4 | 3,200 | 6,400 |
| Movement scratch | 16 | 12,800 | 25,600 |
| Lifecycle/rout | 20 | 16,000 | 32,000 |
| **Simulation payload subtotal** | **256** | **204,800** | **409,600** |
| Additional CPU body upload buffer | 64 | 51,200 | 102,400 |
| Pose-state image, living rows | 64 | 51,200 | 102,400 |

The final two rows are presentation memory, not included in the 256-byte simulation sum. Additional equipment transforms, engine copies, and capacity slack are counted below. An ECS float transform is not 64 bytes by necessity: a 3×4 float matrix is 48 bytes; our 64-byte render record includes 16 bytes of custom data. The authoritative two-snapshot transform is eight integers =32 bytes because pitch/roll come from presentation terrain alignment.

### 7.2 Simulation-owned allocation ceiling

| Allocation | Formula/cap | Bytes |
|---|---|---:|
| Model columns | 2048×256 | 524,288 |
| Squads | 32×256 | 8,192 |
| Squad members | 32×64×4 | 8,192 |
| Casualty history | 32×30×4 | 3,840 |
| Static navigation columns | 65,536×14 | 917,504 |
| 16 completed fields | 16×65,536×5 | 5,242,880 |
| Active field builder + indexed heap | 1,048,576 reserved | 1,048,576 |
| Spatial heads and active/free indices | 32,768 reserved | 32,768 |
| Projectile pool | 4096×64 | 262,144 |
| Tick event ring | 8192×32 | 262,144 |
| Command log buffer before disk flush | 65,536×48 | 3,145,728 |
| Two bounded checkpoint buffers | 2×8,388,608 | 16,777,216 |
| Navigation/corridor auxiliary maps | 4,194,304 reserved | 4,194,304 |
| Catalog tables / handles / metadata | 2,097,152 reserved | 2,097,152 |
| Allocation/implementation reserve | 16,777,216 reserved | 16,777,216 |
| **Planned simulation ceiling** | Sum | **51,302,144 B (48.93 MiB)** |

Checkpoint buffers store mutable state and builder progress, not duplicate immutable maps and all reconstructible completed fields. Serialize field keys and rebuild completed fields at load before resuming; preserve pending builder data exactly. If reconstruction changes future availability, block load completion until all previously completed referenced fields are ready. Assert checkpoint encoded size≤8 MiB. Flush command logs to disk before the ring fills; replay files may grow beyond RAM budget.

The 100 MB requirement is realistic for simulation data. GPU assets and engine memory are a separate, larger concern. Monitor simulation allocations directly as well as process memory; process RSS is not a measure of ECS payload alone.

### 7.3 Presentation and graphics ceiling

| Allocation | Starting ceiling / accounting rule |
|---|---|
| All CPU MultiMesh upload arrays | 32,768 allocated part slots×64 =2,097,152 B |
| Engine/GPU copies of instance records | Reserve 8 MiB; measure backend allocation rather than assuming one copy |
| Pose-state CPU image + GPU texture + staging | 3×163,840 B minimum planning allowance; reserve 1 MiB |
| 512 corpse metadata records | 512×64 =32,768 B in addition to corpse pose rows/instance buffers |
| L0 actor pool | Reserve 32 MiB CPU + GPU auxiliary allocation; verify with actual rig scenes |
| Crowd bone palettes | 32 MiB total per battle roster; include extra clips/large rigs |
| Crowd meshes across LODs/equipment | 128 MiB GPU ceiling |
| Crowd material textures | 256 MiB GPU ceiling |
| Optional impostors | 64 MiB GPU ceiling; disabled until justified |
| Total loaded scene graphics resources | ≤2.5 GiB on 6 GB reference GPU, leaving driver/other application headroom |
| Peak process resident memory | ≤4 GiB qualification target, including engine/imported resources |

Bone palette memory for 12 compatible-library groups at 64 bones/609 frames is about 10.70 MiB before extra rig families. VAT with 12 species ×3 LODs can consume hundreds of MiB depending on vertex counts and tangent storage. Do the exact roster sum at load time and reject over-budget content in development. Apple unified memory does not mean these texture bytes are free or identical to Windows VRAM allocation.

## 8. Cross-platform risk and Windows testing

### 8.1 Risks that matter for this design

| Risk | Mechanism | Required test / mitigation |
|---|---|---|
| Different GPU architecture | Apple unified/tile-based GPU behavior does not predict discrete PC texture bandwidth, overdraw, or submission cost | Compare the same exported scene, internal resolution, and settings on W-N/W-A/M-D |
| Shader translation/driver differences | Godot abstracts drivers but compilation and optimization still vary | Compile every 1/2/4-influence and transition variant on all three drivers; fail on warnings/errors |
| Half precision | Palette translations/rotations can quantize; format handling/performance differs | Compare 16F vs 32F deformation; enforce 2 mm body / 5 mm tip error limits |
| Texture import transformations | sRGB conversion, mipmaps, compression, or sampling can corrupt numeric data | Test known matrix texels and palette frame boundaries after export, not just in editor |
| Buffer layout | Row/column confusion or incorrect stride scrambles instances on every backend, sometimes appearing to work in trivial tests | Identity, 90° rotation, translation, uniform scale, and all four custom-data sentinel tests |
| Culling | Animated limbs leave static mesh bounds; broad cell bounds submit hidden work | Inspect extreme poses at all four frustum edges; log visible versus submitted members |
| Shadows | Vertex deformation repeats per pass and may differ from color rendering | Check moving weapons/wings against shadow silhouettes on each backend |
| Custom motion vectors | New vertices may not have correct previous deformation data for temporal effects | Disable temporal AA/blur by default; moving limb trail test before enabling |
| Retina or dynamic resolution | 1080p versus native Mac display resolution changes pixel cost substantially | Log internal render-target dimensions every benchmark |
| Windows path/export behavior | Case mismatch and omitted generated data files can break otherwise valid imports | Clean Windows export from repository sources, no dependency on Mac import cache |
| Extension binaries | macOS ARM64 native binaries cannot serve Windows x86-64 | Build and package a binary for each supported OS/architecture; exact godot-cpp compatibility |
| Driver/pipeline warmup | First encounter with a material/mesh/pass can hitch | Exercise all supported shader/pass variants behind a loading scene; separately capture cold starts |

No driver-specific shader preprocessor code is allowed in the first prototype. Use Godot spatial shaders and sampled textures. Do not mix raw Metal/Vulkan conventions with Godot projection matrices. Reverse-Z/depth reconstruction is not needed for the core crowd shader; introduce it only for a specific verified effect.

If a compute deformation cache is later introduced, it requires RenderingDevice buffer ownership, dispatch, barriers, render-thread integration, and avoidance of synchronous readback. Compute is available through modern RenderingDevice renderers, and can be driven from GDScript; using a compute shader does **not** itself require GDExtension. A local RenderingDevice's resources cannot simply be assumed to belong to the main renderer's resource namespace. The initial architecture intentionally avoids that integration dependency. [Compute shader guide](https://docs.godotengine.org/en/4.7/tutorials/shaders/compute_shaders.html), [RenderingDevice API](https://docs.godotengine.org/en/4.7/classes/class_renderingdevice.html)

### 8.2 Week-one Windows matrix

Before creating more than one final-quality species, run these exported-build tests on W-N with both Vulkan and D3D12, and on W-A as soon as available:

1. A one-bone animated mesh, a rigid weapon attachment, then a 64-bone palette character.
2. Counts 64/256/800/1600/1920 with fixed scene/seed and recorded GPU driver.
3. 1,600 unique phase offsets, transitions, deaths, and batch migrations.
4. Mixed gear with both armor variants and all three weapon families.
5. Camera at 65°, 40°, and 15° elevation, 55° FOV; shadow on/off comparisons.
6. 10,000 pause/resume cycles in automated replay, plus 1,000 single-tick steps, with camera moving continuously.
7. Integer replay parity against the Mac; save/load at tick 3,000 and continue through tick 18,000.
8. Cold launch after clearing only the test build's generated caches; log shader hitches separately from steady-state results.

Do not wait for a complete battle scene to obtain Windows evidence. A Mac-only green result cannot qualify the Windows target. If no Windows machine is available, status stays **unqualified**, rather than inventing a PC performance estimate from Mac FPS.

## 9. Blender / Blender MCP asset rules

These are tool-independent instructions for a local Blender agent, including an agent using Blender MCP. No Blender tool or installed Blender MCP service was invoked to produce this document.

### 9.1 Modeling and export contract

| Field | Required value |
|---|---|
| Blender units | Metric, unit scale 1.0; 1 unit=1 m |
| Simulation convention | Godot +Y up, −Z forward, +X right |
| Authoring convention | Blender +Z up, +Y forward, +X right; deliberate project convention |
| Axis conversion | `(x_g,y_g,z_g)=(x_b,z_b,-y_b)` for geometry and transforms |
| Origin | Ground contact center between feet, or ground-projected body center for non-bipeds |
| Prototype mouse height | 1.0 m gameplay scale; fantasy relative scale, not biological meters |
| Object transforms | Applied rotation/scale, scale (1,1,1), no negative determinant |
| Crowd rig | ≤64 bones including sockets; names/order fixed in a rig manifest |
| Skin influences | Normalize positive weights to sum 1 within 0.00001; retain top 4/2/1 by weight and then bone index |
| Rig scaling | No animated scale/shear; no runtime nonuniform root scale |
| Topology | Triangulated before bake; UV seams and hard normals finalized |
| Material slots | One body surface; gear surfaces budgeted separately; no per-fur-strand surfaces |
| Textures | One 2048² albedo, normal, and ORM atlas per species family initially; lower LODs share it |
| Fur | Sculpted silhouette + normal/albedo detail; no shell fur or hair strands in crowds |
| Root motion | In-place clips; remove root planar displacement and yaw before palette bake |
| Export | `.glb` source scene with rest pose, normals, tangents, skin and actions; explicit generated crowd resources |
| Naming | `species_mouse_body_a_lod1`, `rig_mouse_v1`, `clip_attack_a`, `socket_main`, `socket_off`, `socket_head` |

Godot/glTF's common oriented-asset convention is +Z model front, while this simulation uses −Z forward. The table intentionally chooses a project convention. Apply the conversion once at import/bake and validate a “face north” fixture; do not automatically add another 180° rotation through `look_at(...,use_model_front=true)`. Use `use_model_front=false` for this project's −Z-facing presentation roots. [Godot model export conventions](https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_3d_scenes/model_export_considerations.html)

### 9.2 Asset generation sequence and validation

1. Produce the mouse body and one sword first. Do not generate all 20 species before validating the bake.
2. Apply transforms, finalize topology, rig, bind, and define `socket_main/off/head` in the bone map. All socket bones count against the rig budget.
3. Author the 16 clips to the exact sample counts/impact positions in Section 3. Bake at 30 Hz. Strip control bones from the exported deform rig unless explicitly referenced by an attachment.
4. Export the conventional L0 GLB and generate L1/L2/L3 meshes to the ceilings in Section 2.7. Generate normals/tangents after LOD simplification and before palette/VAT validation.
5. Evaluate the imported rig in Godot model space or apply the same explicit conversion matrix to Blender vertices and bone matrices. Never bake one coordinate system and import the other without conversion.
6. Generate the skin-matrix palette and custom mesh attributes. Store palette dimensions, frame table, bind hash, bone-map hash, and mesh vertex counts in a manifest. Hashes are computed from actual artifacts, never filled with sample text.
7. For each clip at every baked frame compare crowd-deformed vertex positions with the conventional reference. Require maximum 2 mm error for body and 5 mm for equipment tips. At half-frame times compare against interpolated source animation too; require ≤10 mm body deviation and ≤20 mm weapon-tip deviation at L1. If this fails due to matrix interpolation, sample that clip at 60 Hz or change palette representation and update frame metadata.
8. Build animation AABBs from all deformed mesh/gear vertices; add 0.05 m offline padding. The runtime 0.25 m batch padding is additional.
9. Render front, side, rear, and 3/4 views at 180, 70, 24, and 8 pixels. Require clear species silhouette at 70 px, distinguish sword/spear/bow at 24 px when weapon length≥6 px, no visible body/gear detachment at 180 px, and no missing shadow limbs.
10. Bake/apply the same rules to the next species only after P3/P4 pass on Windows. Sharing a rig requires equal skeleton hierarchy, bone order, bind-space transforms, and clip metadata; similar-looking species are not proof of compatibility.

Geometry manifests use JSON with strict required keys. The following is a **complete configuration example** for the first test asset; generated hashes and actual mesh statistics are stored in the separate build report, not invented here:

```json
{
  "schema_version": 1,
  "asset_id": "mouse_body_a",
  "rig_id": "mouse_v1",
  "forward_axis": "-Z",
  "units_per_meter": 1,
  "max_bones": 64,
  "palette": {
    "path": "res://assets/crowd/mouse/mouse_v1_palette.res",
    "format": "RGBA16F",
    "frames": 609,
    "sample_rate": 30,
    "texels_per_bone": 3,
    "mipmaps": false
  },
  "lod_triangle_limits": [12000, 3500, 1200, 350],
  "lod_influence_limits": [4, 4, 2, 1],
  "body_variants": ["body_a", "body_b"],
  "equipment_ids": [1, 2, 3],
  "root_motion": false,
  "allow_nonuniform_scale": false
}
```

Importer SHALL fail if required keys are absent, palette height does not equal the sum of frame counts, indices reference an invalid bone/frame/visual row, weights are invalid, surfaces exceed limits, or generated bounds exclude any sampled vertex. Missing clip data is an error; do not silently reuse idle for attack/death.

## 10. Honest feasibility and native-code escalation

### 10.1 What is realistic, and what is not yet justified

| Proposed outcome | Assessment |
|---|---|
| 800 characters, authored silhouettes, readable mixed weapons, restricted effects, 1080p | Sensible first school-project target; still requires full-scene validation |
| 1,600 mostly instanced animated models, bounded contacts, few material families | Plausible engineering goal in Godot; no measured guarantee supplied |
| 1,920 all-small units plus corpses/projectiles | Necessary overload test given squad rules; qualify separately |
| 1,600 independent conventional animation trees + physics bodies + individual pathfinding in GDScript | Wrong baseline architecture for this target; reject unless an actual representative benchmark contradicts the risk |
| Unrestricted Warhammer III close-up quality, every soldier fully articulated/IK/cloth, all effects at 60 FPS on the proposed floor | Not a credible school-project commitment |
| AoE IV-inspired readability, proportions, materials, lighting, and composition | Reasonable art direction; it is not a reproducible technical performance specification |

The bottleneck is likely to move: skeletal CPU evaluation first in the naive baseline; then GDScript movement/neighbor loops and presentation packing; then skinning/shadows/foliage on GPU; then content variety and memory. This is an engineering expectation to test, not an observed profile of this project.

**There is no demonstrated fundamental Godot capability wall at 1,600 models.** The missing out-of-the-box facility is a turnkey per-instance independently animated crowd system combining skeletons, sockets, transitions, culling, and deterministic battles. This document builds those pieces. The cost is custom engineering and asset tooling, not a magic `MultiMesh` checkbox.

### 10.2 Ranked sacrifices, least painful first

1. Remove invisible animation work, offscreen particles, distant fingers/face detail, and redundant material surfaces. Preserve gameplay state.
2. Reduce far shadow distance/casters, alpha overdraw, particle counts, and expensive post effects.
3. Share atlases/palettes, restrict armor to authored merged variants, and remove crowd cloth/fur simulation.
4. Reduce mesh vertices/influences and sample cadence by screen size; maintain silhouette and weapon classes.
5. Cap conventional skeletal/IK close-ups at 48; overflow uses the crowd mesh even near the camera.
6. Reduce resolution or present a 30 FPS high-fidelity preset as an explicitly different mode. This does not meet the original 60 FPS preset requirement.
7. Reduce living population to the qualified cap while retaining per-model mixed equipment and combat.
8. Replace individual contact combat with squad statistics or remove meaningful equipment differences. These harm core mechanics most and require a redesigned game specification.

The near-camera pool means the entire army cannot simultaneously receive full close-up fidelity. At a normal perspective ground view, only a subset is large on screen, but long-lens views and oversized creatures can defeat that assumption; the stress scene deliberately exercises it.

### 10.3 When GDExtension/C++ is required

**No component here inherently requires C++ just to function.** GDScript can populate MultiMesh buffers and drive texture-backed shaders. Shader code is GPU code, not GDScript and not C++. However, meeting the measured deadline may require native kernels. Do not promise a pure-GDScript shipping implementation before profiling.

| Measured failure after obvious allocation fixes | Escalation | Native requirement |
|---|---|---|
| Simulation tick p99>4 ms; grid/separation consumes >2 ms | Port grid build, neighbor selection, integer distance, and two separation iterations together | Required for the current design if the native prototype restores the gate and GDScript does not |
| Flow-field route latency fails while higher GDScript quota exceeds tick budget | First test squad A* + local fields; alternatively port indexed-heap field build | May require native path kernel; count of squads alone does not decide |
| Presentation extraction/upload packing p95>3 ms | Port gather/interpolation/transform packing as one bulk job | Required only if measured packing dominates; not if driver upload or GPU stalls dominate |
| GPU time>12.5 ms with CPU below budget | Reduce geometry/passes, compare VAT, then consider deformation cache | C++ simulation will not fix this |
| Transition/skeletal pool CPU exceeds 1 ms presentation budget | Lower pool, simplify animation graphs, or shared-pose experiment | Full engine fork is not the first response |
| Shader/palette memory exceeds budget | Reduce asset variants/frames or use bone palettes | C++ will not compress an overlarge art specification automatically |

Give each failing kernel two bounded optimization passes of at most four engineering hours: eliminate allocations, reduce API calls, and verify the algorithm's work count. Then prototype a native kernel with identical integer inputs/outputs. If no native skills/time are available, reduce the qualified population or feature scope at that point, not in month eight.

Native boundaries are coarse:

```text
BattleKernel.configure(map_columns, catalog_columns, capacity)
BattleKernel.load_state(canonical_bytes)
BattleKernel.step(tick, ordered_command_bytes) -> event_bytes
BattleKernel.copy_render_snapshot() -> packed_numeric_snapshot
BattleKernel.save_state() -> canonical_bytes
```

For a single native movement kernel, transfer/own its full columns once, then call one `step_movement()` per tick. Do not call C++ once per model or neighbor. Keep exact integer overflow/rounding behavior and run the same replay parity suite. If using threads, workers write disjoint scratch buffers; the main thread commits results in a fixed order. No worker touches live scene nodes or shared resource objects. Godot documents limitations on scene-tree and resource access from worker threads. [Thread-safe APIs](https://docs.godotengine.org/en/4.7/tutorials/performance/thread_safe_apis.html)

GDExtension loads native libraries without requiring a custom Godot executable. Build macOS ARM64 and Windows x86-64 libraries, and keep the extension ABI/version configuration pinned. This is a supported escape hatch, not an assertion that all of the renderer should be rewritten. [GDExtension API](https://docs.godotengine.org/en/4.7/classes/class_gdextension.html)

### 10.4 Would another engine be a better choice?

For the **school project**, remain with Godot if the first two weeks of gates qualify the reduced visual scope. Switching engines while simultaneously learning crowd rendering, deterministic simulation, and 20 species of asset production can increase risk.

If **commercial Total War-like close-up fidelity and dense battles are non-negotiable**, evaluate Unreal now with one identical crowd fixture. Unreal provides MassEntity/MassRepresentation infrastructure, an Animation Sharing plugin, and AnimToTexture tooling. Those are useful starting points that reduce some custom integration work. They do not supply this game's deterministic combat, equipment semantics, or a guaranteed frame rate. Mass systems and high-fidelity settings still need profiling, and Blueprint-only per-character logic is not a substitute for the proposed bounded simulation. [MassEntity](https://dev.epicgames.com/documentation/unreal-engine/mass-entity-in-unreal-engine), [Animation Sharing](https://dev.epicgames.com/documentation/en-us/unreal-engine/animation-sharing-plugin-in-unreal-engine), [AnimToTexture](https://dev.epicgames.com/documentation/en-us/unreal-engine/API/Plugins/AnimToTexture)

Unity's Entities Graphics is another data-oriented instancing/LOD option, but migration means a C#/DOTS workflow and its own animation integration. It is not a drop-in GDScript performance fix. [Unity Entities Graphics](https://docs.unity3d.com/Packages/com.unity.entities.graphics@1.4/manual/index.html)

The recommendation is conditional: switch for better-fitting tooling/team expertise and prototype evidence, not because Godot fundamentally cannot draw 1,600 animated meshes. If the real constraint is a short school deadline and no shader/native programming experience, reducing the game's scope is more reliable than changing engines.

### 10.5 Honest supported population policy

Evaluate candidate caps `{400,600,800,1000,1200,1600,1920}`. For each, run the entire scene/camera matrix. Define `N_qualified` as the largest tested cap for which that cap and every smaller candidate pass all functional and timing gates on W-N and W-A. Define the release cap as the largest candidate ≤`0.85*N_qualified`, unless the final full-content test independently proves the higher cap with the Section 0 headroom. The 15% rule is a production-risk reserve, not a hardware law.

Example: if 1,600 passes but 1,920 fails, a conservative advertised cap is 1,200 until content headroom is independently qualified. If only 800 passes, use 600 under the reserve rule. If 600 fails, stop and rescope before battle production. These are conditional outcomes, not predictions of measured Godot maxima.

A 600–800-model battle can still look substantial: 10 squads/side with 30–40 visible members, compact frontages, readable banners, distinct spear/bow blocks, visible reserves, and a camera framing the conflict. This changes the original small-unit count range and must be labeled as a reduced school scope. Do not retain a “60 soldiers” stat while rendering or simulating only 30 unless abstract squad strength becomes an explicit redesigned mechanic.

## 11. Sequenced prototypes and stop gates

Execute in this order. Do not begin the next asset-heavy experiment until its predecessor passes or the architecture is explicitly revised. Maximum initial architecture spike: **80 engineering hours**; this is a proposed planning timebox, not an estimate that the complete game takes two weeks. Record time spent. A gate failure should produce a decision, not an indefinite optimization project.

| ID / effort cap | Isolated build | Measure | Pass / stop-and-rethink result |
|---|---|---|---|
| P0 / 1 h | Empty export on Mac and Windows; frame CSV logger, fixed camera and resolution | Launch/export, hardware/driver identity, idle cost | Stop qualification if Windows export cannot be tested; fix environment before content |
| P1 / 2 h | Static representative L1 meshes at N=256/800/1600/1920; no animation or simulation | Geometry cost, draw count, shadows off/on; compare MultiMesh vs shared-mesh nodes | If static crowd-only GPU p95>6 ms at 1600 with no shadows, reduce geometry/materials before animation work |
| P2 / 4 h | All-skeletal baseline using one rig, clips, three gear types; count sweep | CPU pose cost, render submission, GPU time; fit crossover | If 800 skeletal actors fail, retain the result as evidence and proceed to instancing; do not optimize per-actor physics/AI that is outside the target design |
| P3 / 8 h | Bone-texture and VAT alternatives for the same rig, meshes, clips, and phases | Deformation error, shader compilation, CPU/GPU delta, memory | Require 2 mm/5 mm baked-frame error and crowd-only GPU p95≤8 ms at1600 unshadowed; if both fail, simplify mesh/rig or abandon the proposed fidelity floor |
| P4 / 4 h | One 60-model mixed squad, then 1600 mixed models; 2 body variants and sword/spear/bow/head parts | Correct attachment pose, batch count, hidden/culling cases, upload time | Zero detached/wrong-pose parts; extraction p95≤3 ms; if batching fails, revise gear/atlas scheme before more species |
| P5 / 4 h | L0 pool + L1–L3 transitions, camera sweep, 512 deaths, pause/resume | LOD popping, pool churn, animation continuity, render freeze | No identity/pose swaps in 10,000 migrations; no playback advance over 10 paused seconds; no missing frustum-edge limbs |
| P6 / 8 h | Integer ground movement; 32 squads; flow-field builder; walls/corridors; render simple markers | Tick time, command latency, overlap, formation recovery | p99 tick≤4 ms; route-ready p95≤0.25 s normal/≤0.75 s burst; if route latency fails, compare A* corridors/local fields before production |
| P7 / 8 h | Bounded contacts, three weapon fixtures, morale, rout, logical arrows; markers only | Candidate counts, scheduled damage, rout dispersion, deterministic hashes | No event overflow, invalid-handle damage, or camera-dependent outcomes; if tick budget fails, native-kernel experiment or lower cap |
| P8 / 4 h | Full replay/save-load suite on Mac/Windows; alternate render cadences 30/60/144 FPS | Per-tick canonical hashes, pause and single-step behavior | Any hash mismatch is a hard failure; repair deterministic boundary before content |
| P9 / 4 h | Eight-species silhouettes and gear/material fragmentation; include wings/tails and 32 giants in a separate case | Draw occupancy, bounds, CPU/GPU cost, palette memory | Entire crowd representation fits its budgets; if not, revise roster/material variety or size-specific budgets |
| P10 / 8 h | Integrated woodland battle with terrain/foliage, one sun, UI, arrows, corpses, audio and VFX limits | Full Section 0 timing/memory gates at all candidate counts | This determines qualified population; passing an empty-field crowd demo does not substitute |
| P11 / 4 h | Cold launches + 20-minute soak + repeated battle load/unload, both PC GPUs/drivers | Hitches, resource growth, thermal slowdown, crashes | No overload; no >5 MiB retained growth between post-unload baselines over 10 cycles; all steady-state gates still pass |

The effort caps sum to 59 hours, leaving 21 hours of the 80-hour spike for gate-driven fixes and decision writing. Native implementation and full art production beyond this spike require a revised project schedule.

### 11.1 Mandatory stress scenes

| Scene ID | Deterministic setup |
|---|---|
| S00_STATIC | 32 groups on an 8×4 grid, 12 m between group anchors; 50 models/group for 1600; all L1 forced |
| S01_MARCH | Same roster, two opposing sides initially 40 m apart; both move 20 m toward center |
| S02_MELEE | 16 squads/side, 50 models/squad, alternating sword/spear assignments; all engage at center |
| S03_MIXED | 50% sword, 30% spear, 20% bow in each squad; opposite target squad by mirrored squad ID |
| S04_CORRIDOR | 32 squads ordered across two 2 m wide, 12 m long corridors through a 4 m thick wall |
| S05_ROUT | At tick 900 set morale=190 through a recorded test command for eight engaged squads; verify dispersal and continuing damage |
| S06_CORPSES | 1600 living plus 512 retained corpses and 4096 occupied logical projectile records; render at most256 arrow sprites if needed, logical impacts unchanged |
| S07_FRAGMENT | 8 species cycling by squad ID, 2 armor variants alternating by model ID, 3 weapon families at 50/30/20%; normal LOD |
| S08_GIANTS | 32 one-model giant squads, 96-bone/2×geometry rigs where applicable, large wings/tails in close view |
| S09_POPULATION | Repeat S01–S07 at 400/600/800/1000/1200/1600/1920; distribute count across32 squads as evenly as possible, never >60/squad |

S00 grid must fit the 128 m map: anchor X positions −42,−30,−18,−6,6,18,30,42 and Z positions −18,−6,6,18. For 1920 use 60 members per group. S06's projectiles are logical records; visual caps are deliberate cosmetic budgets. A 4,096-projectile worst case must still resolve all logical events even if only a subset of arrow sprites is visible.

Test cameras use 55° vertical FOV and elevation 65°/40°/15°, pointing at map center. Distances are 90/45/12 m respectively, adjusted only to prevent the camera entering terrain. Also test a 12 m ground view focused on the densest melee. Camera path is deterministic presentation data but excluded from the authoritative hash.

### 11.2 Metrics and report schema

Write one CSV row per rendered frame to `res://`-independent user-writable benchmark output storage. Buffer rows and flush every 120 frames outside the measured CPU system scopes. The file header is:

```csv
run_id,scenario,engine,os,cpu,gpu,driver,renderer,width,height,seed,frame_index,completed_tick,living,corpses,projectiles,frame_interval_ms,sim_ticks_this_frame,sim_ms,extract_ms,cpu_frame_ms,gpu_frame_ms,total_draws,lod0,lod1,lod2,lod3,lod4,batch_count,allocated_part_slots,neighbor_scans,neighbor_truncations,route_ready_ms,sim_alloc_bytes,process_rss_bytes,gpu_resource_bytes,overloaded
```

Use `NA` for unsupported timing/memory counters, not zero. That is a report schema value, not an implementation placeholder. A run without GPU timing may measure end-to-end performance but cannot decide whether native CPU code or a shader change fixes the bottleneck. Obtain an appropriate GPU profiler capture before making that decision.

Instrument simulation stages with `Time.get_ticks_usec()` outside authoritative math. `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` supplies a draw diagnostic; other engine monitors are useful for cross-checking. Monitor values can be delayed or sampled and are not a substitute for precise stage timestamps. Validate pass totals in a GPU capture. [Performance API](https://docs.godotengine.org/en/4.7/classes/class_performance.html)

For sorted frame intervals `v[0..n-1]`, percentile p is `v[ceil(p*n)-1]` for p=0.50/0.95/0.99. FPS for an interval is `1000/ms`; do not average reciprocal FPS and call it average frame time. Calculate mean FPS as total completed frames divided by total elapsed seconds. Mark load screens and warmup as separate phases; do not delete slow gameplay frames from the dataset.

For congestion, count a pair as a severe overlap when center distance `<0.75*(r_i+r_j)`. Each unordered pair counts once. Require fewer than 2% of living models involved in severe overlap for more than 15 consecutive ticks in normal march/melee scenes; corridor entry may exceed this briefly but must recover within 60 ticks. Require >95% of surviving nonrouting squad members within 1 m of their assigned slot within 90 ticks after leaving an obstacle. If scan truncation occurs on >2% of living models for 30 consecutive ticks, reject the spatial-grid settings even if FPS is high.

Test logical camera independence by replaying the same battle once with overview-only camera, once with continuous zoom, and once without rendering. All authoritative hashes must match. Test frame independence at fixed 30/60/144 presentation FPS and a repeating 10/40/16/25 ms frame-delta sequence.

### 11.3 Diagnostic HUD layout

The HUD is a development tool, hidden in the player build. Use a 1920×1080 reference canvas. Coordinates below are exact reference pixels; anchors keep the upper bars aligned at other window sizes.

```text
+--------------------------------------------------------------------------------+
| [Run S03] [N:1600] [Seed:123456789] [Pause] [Step] [Restart]       (0,0)-(1920,48) |
+-----------------------------+--------------------------------------------------+
| CPU  / GPU / frame p95       |                                                  |
| Sim tick p99 / extraction    |                                                  |
| L0 L1 L2 L3 L4 counts        |              LIVE BATTLE VIEW                    |
| Draws / batches / slots     |                                                  |
| Route ready / backlog       |                                                  |
| Overlap / truncations       |                                                  |
| Sim MB / VRAM / hash match  |                                                  |
| (0,48)-(360,344)             |                                                  |
+-----------------------------+                                                  |
|                                selected model: ID / squad / gear / clip / row  |
|                                        (1280,48)-(1920,192)                    |
+--------------------------------------------------------------------------------+
| Timeline tick / last command / gate failure text           (0,1016)-(1920,1080) |
+--------------------------------------------------------------------------------+
```

Space toggles simulation pause; period advances exactly one tick only while paused; F3 toggles the diagnostic overlay; F4 cycles forced LOD off/0/1/2/3; F5 restarts the deterministic fixture. Forced LOD0 testing may intentionally exceed the pool only in P2, clearly labeled as a baseline mode. WASD pans, middle-drag orbits, wheel zooms. Camera controls work during pause. A step captures previous state, runs one tick, then presents alpha=1 and stays paused.

## 12. Initial execution checklist for the coding agent

Paths in this section are intended repository paths for the implementation agent; this document itself does not create the game or those source files.

```text
docs/
  crowd_rendering_architecture.md
assets/crowd/mouse/
  mouse_lod0.glb
  mouse_v1_palette.res
  mouse_body_a_lod1.res
  mouse_body_a_lod2.res
  mouse_body_a_lod3.res
  mouse_manifest.json
src/battle/
  battle_clock.gd
  model_store.gd
  squad_store.gd
  battle_systems.gd
  navigation_fields.gd
  separation.gd
  combat.gd
  replay_codec.gd
src/presentation/
  crowd_batch.gd
  crowd_renderer.gd
  crowd_skin_4.gdshader
  crowd_skin_2.gdshader
  crowd_skin_1.gdshader
  skeletal_pool.gd
tools/
  bake_crowd_assets.gd
  validate_crowd_assets.gd
tests/crowd/
  benchmark.tscn
  benchmark_runner.gd
  determinism_runner.gd
```

- [ ] **EX-001 / P0:** Pin Godot 4.7.2 and matching export templates. Record the exact hardware/OS/driver matrix. Confirm Windows release export runs.
- [ ] **EX-002 / P0:** Create frame/stage logging, percentile calculation, fixed seed, fixed internal resolution, and the diagnostic HUD. Verify empty-scene overhead.
- [ ] **EX-003 / P1:** Build the static crowd fixture with representative geometry and three gear meshes. Capture static cost with/without shadows.
- [ ] **EX-004 / P2:** Establish the conventional skeletal count sweep with shared assets and no per-model gameplay nodes. Save the measured crossover data.
- [ ] **EX-005 / P3:** Bake one palette, create the custom attributes, and compare deformation against L0 at every frame. Run the shader on all drivers.
- [ ] **EX-006 / P3:** Build the equal-content VAT alternative; record exact texture bytes and GPU pass cost. Select one crowd deformation path with an evidence-backed report.
- [ ] **EX-007 / P4:** Implement stable visual rows, batch gathering, full-stride uploads, dynamic bounds, and matching gear sockets. Test slot compaction/reuse.
- [ ] **EX-008 / P5:** Implement LOD hysteresis, capped L0 pool, synchronized gear transitions, death retention/eviction, manual animation time, and pause.
- [ ] **EX-009 / P6:** Generate the authoritative SoA columns and immutable catalogs. Validate all ranges, defaults, handle reuse, and canonical field ordering.
- [ ] **EX-010 / P6:** Implement integer map collision, indexed-heap fields, command queue, formations, spatial grid, and two-pass separation. Measure command latency as well as tick time.
- [ ] **EX-011 / P7:** Implement mixed-weapon contacts, committed impacts, projectiles, morale/rout, and deferred lifecycle. Compare deterministic golden encounter traces.
- [ ] **EX-012 / P8:** Implement replay/save-load and full per-tick hash comparison on Mac/Windows with varied render cadence and pause patterns.
- [ ] **EX-013 / P9:** Introduce eight-species fragmentation and large wings/tails. Verify geometry/palette/material caps rather than cloning the easiest mouse benchmark.
- [ ] **EX-014 / P10:** Add the actual woodland environment and all listed effects/UI/audio. Run the count/camera matrix and compute `N_qualified`.
- [ ] **EX-015 / P11:** Run cold-start, long-soak, and load/unload tests. Confirm native libraries and generated numeric textures are included in Windows exports if used.
- [ ] **EX-016 / decision:** Publish the accepted renderer, supported population, hardware floor, sacrificed features, measured timings, memory totals, and outstanding failing gates. Freeze this contract before settlement/battle integration grows around it.

### 12.1 Remaining fixed record schemas

Projectile records are 64 bytes, 16 int32 fields in this order:

```text
flags, source_entity_id, target_slot, target_generation,
origin_x, origin_y, origin_z, aim_x, aim_y, aim_z,
release_tick, arrival_tick, base_damage, armor_penetration,
hit_per_mille_at_release, roll_0_to_999
```

At bow release consume exactly one attacker RNG roll and store it in the projectile; calculate hit threshold from the release-time skills, with no flank bonus. Arrival uses this saved roll/threshold and the target's current armor. The projectile remains valid after its archer dies; it never reads a recycled source slot. This rule supplements the melee RNG consumption rule in Section 6.

Tick event records are 32 bytes: `(kind,tick,source_slot,source_generation,target_slot,target_generation,arg0,arg1)`. Kinds are ATTACK_START=1, IMPACT=2, MISS=3, DEATH=4, ROUT_START=5, RALLY=6, EQUIPMENT_CHANGE=7. Empty target/source slots use −1 and generation 0. Attack args are weapon ID/attack sequence; impact args are damage/weapon ID; death args are death-clip ID/body ID; rout/rally args are squad ID/morale; equipment args are slot kind/equipment ID. The 8192-entry ring is drained each tick into presentation/replay consumers; overflow is a development error and a failed gate.

Corpse metadata is 64 bytes: `(source_entity_id,species_id,body_id,head_id,main_hand_id,off_hand_id,palette_id,x,y,z,yaw,death_tick,expiry_tick,death_clip_id,phase_q16,flags)`. The corpse root remains at the committed death position; the death animation may move the body inside its baked bounds. Pose row is derived from corpse pool index. No living slot reference is needed to animate a corpse.

Persist completed-field cache descriptors `(field_id,generation,key,last_use_tick,referencing_squad_mask)` and pending requests in saves. Restore the same IDs, descriptors, and LRU order before resuming; rebuilding immutable field values during loading must not alter future eviction or request-order decisions.

### 12.2 Required golden tests

| Test ID | Exact expected result |
|---|---|
| GT-001 | Identity transform + pose frame0 preserves bind-space fixture within the stated error tolerance |
| GT-002 | Rotate root +90° around Y and translate (3,0,5): body and main-hand socket move together and the custom pose row is unchanged |
| GT-003 | Move a model between two batches 10,000 times: no frame/gear/ID swaps, no generation mismatch |
| GT-004 | With seed state1, first xorshift values are 270369, 67634689, 2647435461, 307599695, 2398689233 |
| GT-005 | `floor_sqrt(0,1,2,3,4,15,16,17)` returns `0,1,1,1,2,3,4,4` respectively |
| GT-006 | Constant vx=1024 units/s, remainder0, 30 steps: total X displacement1024 units and final remainder0; negative velocity gives−1024 and remainder0 |
| GT-007 | Sword vs fixture armor4: successful hit deals10 HP; spear deals10; bow deals6 |
| GT-008 | Two 10-HP sword units with valid same-tick impacts and forced passing rolls both die on that tick |
| GT-009 | Pause at completed tick300: after10 seconds camera motion, all authoritative bytes and animation phases are unchanged; one step produces tick301. LOD changes may resample that same frozen phase, so texture-row bytes need not remain identical across a sampling-tier change. |
| GT-010 | Body slot reused after death: corpse retains its original gear/pose, and attacks holding the previous generation cannot damage the new model |
| GT-011 | Replay at30/60/144 rendering FPS and headless: all18,000 tick hashes match |
| GT-012 | Save at tick3000 and reload: continuation hashes match uninterrupted run through tick18000 |
| GT-013 | Clip15 starts at row549 and ends at row608; no frame lookup requests row609 |
| GT-014 | Completed-field save/load restores the same pending-path availability tick and subsequent cache eviction order |

### 12.3 Verification status of this specification

Official Godot API references were consulted for the selected engine branch. Memory arithmetic, frame offsets, record sizes, and scheduler/numeric reference behavior were checked outside the engine. **No Godot executable or existing game project was available in this workspace, so the GDScript and shaders have not been parsed, compiled, rendered, or benchmarked here.** P0–P3 must validate them in the pinned editor before the implementation agent treats them as production code.

This is a complete architecture proposal and execution contract for the requested crowd problem. It is not evidence that the proposed visual target already runs at 60 FPS, nor a replacement for the full game's economy, settlement, or air/water movement specifications.

---DOC:crowd_rendering_architecture.md---
