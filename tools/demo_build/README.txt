REDWALL DEMO -- a small Mossflower village (Windows build)
==========================================================

Built {built} from commit {commit} with Godot {godot}.


HOW TO RUN
----------
1. Copy redwall-demo-windows.zip to the PC and unzip it (right-click > Extract All...).
   Do not run it from inside the zip: the game needs RedwallDemo.pck beside the .exe.
2. Double-click RedwallDemo.exe.

   Windows SmartScreen may say "Windows protected your PC", because the program is not signed.
   Click "More info", then "Run anyway". It asks once per copy.

The window opens maximized. F11 switches full screen on and off. The village opens running; the
HUD's pause and 1x / 2x / 4x buttons (or Space, F1, F2, F3) control time.

If it closes at once or shows an error, run RedwallDemo.console.exe instead: it is the same game
with a console window that keeps the log, which says what went wrong.


REQUIREMENTS
------------
- Windows 10 or 11, 64-bit.
- A graphics card with Vulkan (tried first) or DirectX 12 (tried if Vulkan fails) drivers: most
  NVIDIA, AMD and Intel GPUs from about 2016 on. Keep the graphics driver up to date.
- About 2 GB of free video memory, and under 1 GB of disk for the unzipped folder (the game data,
  RedwallDemo.pck, is {pck_mib} MB).


CONTROLS
--------
Camera
  W A S D or arrow keys     pan              Q / E                  rotate
  Mouse wheel, PgUp/PgDn    zoom             Alt+PgUp / Alt+PgDn    tilt
  Home                      back to the village

Residents
  Left click                select one (Shift: add or remove)
  Left drag                 box-select (Shift: add)
  Left click empty ground   clear the selection
  Right click ground        move there, then hold
  Right click a work spot   work there
  R                         release the selection to its own routine
  Esc                       clear the selection

Tunnels
  T (mole selected)         lay out a tunnel: left click the entrance, each bend, the exit;
                            Enter or right click digs it, Backspace takes back a point, Esc cancels
  U                         underground view
  Left click a tunnel       its panel (widen, brace, lanterns, chambers)

Farm and village
  Left click a crop bed     its panel: plant, water, harvest, clear, compost, cover
  Right click a bed         (residents selected) do its most pressing work
  V                         map overlays: moisture, ripeness, water, off
  K                         the pantry

Time and window
  Space                     pause / resume   F1 / F2 / F3           1x / 2x / 4x speed
  F11                       full screen on / off


WHAT THIS IS
------------
A presentation demo of the settlement layer, not the game: the HUD, the clock, the farm's crop
arithmetic, weather and fishing are the real systems; the residents' walking is scripted for the
demo (the settlement's movement system is not built yet). Nothing is saved.


KNOWN ISSUES
------------
- The program is unsigned, so SmartScreen warns (see above), and the .exe has Godot's own icon and
  version details.
- The first minute can stutter while the graphics driver compiles shaders; it is smooth after.
- Some props face the wrong way (the asset pass has not checked facing yet), and the walk cycles'
  swinging foot can scrape the ground.
- If the top of the screen shows "Paused: CRITICAL", the game clock stopped itself after the PC
  stalled for over a quarter of a second (for example while the first run compiles shaders). The
  pause button cannot lift that pause yet: close the demo and start it again.
- If neither Vulkan nor DirectX 12 starts, Godot falls back to its OpenGL renderer: the demo runs,
  but lighting and some materials look different.


HOW IT WAS BUILT (decision 0196)
--------------------------------
- Boots straight into the demo: the build carries the custom feature "demo_build", and
  godot/project.godot overrides the main scene (application/run/main_scene.demo_build), the window
  (maximized) and the title for it. The editor and the normal game still open scenes/main.tscn.
- Textures: every 3D texture the demo's models carry is VRAM-compressed (S3TC: DXT1 colour and
  roughness, BC5 normal maps, the roughness map capped at its colour map's size and its mipmaps
  filtered by the normal map). About 6.2 GB of texture memory in the opening view became about
  0.9 GB, with no visible change. The crop card atlases and item icons, and all UI art, stay
  lossless: they are packed as the original PNG files.
- Renderer: Forward+ on Vulkan, falling back to DirectX 12, then to OpenGL (Godot 4.7's Windows
  defaults, kept on purpose).
- Rebuild on the Mac with one command: python3 tools/build_demo_windows.py --out <folder>
