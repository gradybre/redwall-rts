# Resume Windows testing

Status: deferred by the user until the Windows PC is available. User-reported hardware is a 5090 GPU and 64 GB RAM. CPU, Windows version, driver version and measured installed memory are not yet known. `hardware.json` preserves these facts without filling missing fields.

## 1. Purpose of this package

This package runs the same isolated Godot settlement controls already executed on the Mac. It compares both complete winter outcomes against the Python reference, tests resident-slot identity and integer clock behavior, loads the retained Mac checkpoint, and compares every state hash at ticks 3000–18000.

It does not contain a complete game build or renderer benchmark. A successful USER-PC run does not certify the Ryzen 5 3600 / GTX 1660 Super / 16 GB reference floor. Keep USER-PC results separate from the W-N and W-A qualification records. `[GDD §5.11; crowd §0.3]`

## 2. Files and prerequisites

Use the checked-out `redwall-rts` repository, or extract the supplied validation package into a new folder. It preserves these relative paths:

```text
docs/
  game_gdd.md
  ui_ux_controls.md
  crowd_rendering_architecture.md
  setting_rules_amendment.md
  validation/
    run_headless.py
    qualify.py
    winter.py
    hardware.json
    headless/
      project.godot
      winter_world.gd
      control_checkpoint.gd
      resident_slots.gd
      fixed_clock.gd
      test_foundation.gd
      run_controls.gd
validation-results/
  winter-controls/winter_report.json
  godot-mac/report.json
  godot-mac/comparison.json
  godot-mac/winter.control
  godot-mac/checkpoint_hashes.csv
```

Required tools: Python 3.9 or newer and the standard Godot Windows console executable whose `--version` output is exactly `4.7.2.stable.official.ed1daf0bf`. Use the console executable so the runner can retain diagnostics. No third-party Python dependencies or network connection is used by these tests. `[NEW tooling contract; engine pin crowd §0.2]`

## 3. Run from PowerShell

Open PowerShell at the extracted package or repository root. The following command asks for the existing Godot executable path and uses it directly; it does not install software or change system settings.

```powershell
$RedwallGodotExe = Read-Host "Full path to the Godot 4.7.2 Windows console executable"
py -3 docs/validation/run_headless.py --godot "$RedwallGodotExe" --output validation-results/godot-user-pc --checkpoint-input validation-results/godot-mac/winter.control --compare-mac validation-results/godot-mac
```

The input Mac checkpoint and output Windows checkpoint must be different files. Do not overwrite the Mac baseline. When the engine version, source digests or reference inputs differ, the runner refuses comparison rather than presenting a misleading match.

## 4. Expected evidence

| File under `validation-results/godot-user-pc/` | Meaning |
|---|---|
| `comparison.json` | Summary, source/evidence digests, platform, result equality and cross-platform flags |
| `report.json` | Every Godot check result, both winter traces, foundation result and checkpoint continuation result |
| `winter.control` | Checkpoint supplied to the Windows control loader |
| `checkpoint_hashes.csv` | Saved boundary plus 15000 subsequent completed-tick hashes |
| `console.log`, `engine.log` | Captured diagnostics |

For a complete isolated cross-platform pass, `comparison.json` must contain all of the following:

```json
{
  "status": "PASS_ISOLATED_MAC_WINDOWS_PARITY",
  "platform": "Windows",
  "python_results": "EXACT_MATCH",
  "daily_and_terminal_rows": 18,
  "death_events": 12,
  "next_tick_comparisons": 15000,
  "speed_parity": true,
  "comparison_with_mac": {
    "compared_hash_rows": 15001,
    "cross_platform": true,
    "loaded_mac_checkpoint": true
  }
}
```

This is a required field subset, not a fabricated Windows result. The actual file also contains checks, digests and diagnostics. Any script error, unknown engine error, differing result, differing hash, stale source input, wrong engine or missing evidence fails the run with exit 2. Known Mac sandbox startup diagnostics are retained explicitly; Windows errors do not receive a generic exemption.

## 5. Return point

When the PC becomes available, first record its detected hardware/OS/driver details, then run this package. Bring back the entire `godot-user-pc` result directory. Its result can close the isolated Mac/Windows control gap. Full-game replay, transactional release saves, graphics correctness and the performance capture matrix remain separate gates after their runtime systems are integrated.
