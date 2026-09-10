# Task 10 — Complete presentation and release qualification

2026-09-09 · PLANNED milestone card. Build presentation with tasks 04–08;
this task owns remaining completeness and final qualification, not the first UI.
Owners: UI-SET/REQ-UX registry and task-10 CSV rows; REQ-SET-163/164 and other
qualification rows; ARCH-PERF-001–005, MOVE-G03/G04/G05, crowd asset/determinism
contracts, DEC-018/019/021 and applicable setting presentation policies.

## Dependencies and work

- [ ] 10.1 Finish every allocated UI definition/state and input flow, including
  all command kinds, accessibility, keyboard navigation, Mac trackpad, selection,
  layer/cutaway picking, context explanations and scenario onboarding. Evidence
  includes real visible layouts across prescribed resolutions/UI scales and
  screen-reader flows. Do not claim controller-only support from generic QA text.
- [ ] 10.2 Complete versioned species/age/culture briefs using original image
  references directly and source-qualified literary context. Validate recognizable
  anatomy, mouse 1 m anchor, gear/contact clearance and coherent storybook/
  grounded materials. Missing backs/poses are authored interpretations. Paid
  asset generation requires explicit separate authorization.
- [ ] 10.3 Complete clip/LOD mappings for real movement domains, equipment and
  supported work. Recompute bones/frames/texture/bounds/visible actor memory,
  including both presentation snapshots. No per-resident physics/navigation/
  AnimationTree; at most 24 close skeletal actors. Distant views preserve actual
  traversal mode. Integrate contextual audio with explicit resource/stream budget.
- [ ] 10.4 Qualify the **complete integrated exported release**: tick/frame/UI/
  route latency/memory, 256 living and maximal required stores, dense interiors,
  multi-level domains, weather/crop/expiry bursts, seasonal boundaries and 4×.
  Measure normal tick p99 ≤2000 µs and aggregate 4× frame simulation p95 ≤6000 µs
  separately, plus all other ARCH-PERF gates; compare no additive percentile sums.
- [ ] 10.5 Complete source-versioned scenario survival, all adopted movement
  gates, save/replay, capacity/failure recovery and long-run reliability evidence.
  Make a release audit linking each requirement/policy to evidence or an explicit
  unresolved gate; all required rows must be resolved for release completion.

## Ownership, performance and acceptance

Art/UI/audio owners deliver bounded files to the integration lead. Test runner
collects raw measurements with exact build/export/PCK/catalog/source manifests;
independent reviewer checks methodology and slowest-repeat result. ADR 0016
performance ownership is proposed as implementation lead plus independent review;
record its actual assignment before the next integrated checkpoint. Optimization
must preserve integer rules and complete deterministic state. A behavior correction
gets new expected hashes and a rules explanation, never optimization-parity credit.

Re-run relevant stage measurements as integration changes workload; existing
needs/WU editor numbers and newer release/fused microbenchmarks are evidence for
their own workloads only. No runtime suite was run by this planning package.
Follow architecture/validation protocols for warmup, repeats, soak, renderers,
percentiles and first divergence. Keep verification instrumentation overhead
separate from release qualification.

Mac M5 Pro runs are development evidence. **Windows testing is deferred by
Brendan.** The available 64 GB/RTX 5090 PC does not establish the Ryzen 5 3600 /
GTX 1660 Super / 16 GB reference-floor result or RX 6600 companion. Record
unavailable qualification as DEFERRED/BLOCKED, never fabricate a passing matrix.
Completion requires actual evidence for all applicable gates; a strong Mac demo,
finished assets or passing unit tests alone cannot close release qualification.
