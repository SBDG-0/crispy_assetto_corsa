# Crispy Assetto Corsa Apps

CSP Lua apps by **SavageBulldogOG** for everyday driving, drifting, spectating, and adjusting your Assetto Corsa experience.

## At a glance

| App | What it adds |
| --- | --- |
| Crispy Audio UI + Shortcut UI | Quick volume presets, mute, and supported car controls. |
| Crispy Cam Select | Camera switching, driver selection, and replay lap navigation. |
| Crispy Driver Tags | Custom driver labels with flags, ping, icons, colors, and fading. |
| Crispy FFB Controls | Per-car gain defaults, global FFB adjustments, and live force graphs. |
| Crispy Pedals UI | A customizable pedal, handbrake, steering, and FFB overlay. |
| Crispy Setup Loader | Remember a setup per car and attempt to restore it on joining. |
| Crispy Quick Teleport | Jump to an available server teleport point near a tagged friend. |

## Installation

These apps are written for Assetto Corsa with **Custom Shaders Patch (CSP)**. Content Manager is used for the associated driver tags and friend workflow. 
A minimum CSP version has not been established for the complete collection; individual features depend on the APIs available in your build.

1. Download and extract this repository.
2. Copy the desired `crispy_*` folders into `assettocorsa/apps/lua/`. Keep each app's files and subfolders together.
3. Start a session and open the desired app from the in-game app sidebar. 
    - Setup Loader only appears in the setup menu.


## Crispy Audio UI + Shortcut UI

Folder: `crispy_audio_ui`

Two compact windows keep audio and supported car functions within reach.

### Audio window

- Three quick-volume buttons select between **10/20%**, **30/50%**, and **80/99%**, based on the current volume.
- The volume readout also acts as a mute/unmute button.
- Unmuting restores the volume saved when muting, with 50% as the fallback.
- Optional fading hides the controls when the window is not hovered.
- Adjustable background contrast.

### Shortcut window

- Wiper mode selection.
- Headlight control, including off/low/high beams on supported cars.
- Left and right indicators and hazard lights, with active-state highlighting.
- Hold-to-sound horn or a siren control, depending on the car.
- Cockpit-adjustable brake bias.
- Adjustable turbo wastegate level.
- Individual visibility switches for each control category, plus separate fading and background settings.

Controls depend on the capabilities exposed by the current car. In the current code, the basic headlight checkbox for cars without low/high-beam selection is also gated by an internal button-count setting; it may not appear with the default settings.

## Crispy Cam Select

Folder: `crispy_cam_select`

A compact panel for choosing your view and the car you want to watch.

- Cycle through driving cameras using **Camera**.
- Switch to **Free**, **Orbit**, **Heli**, **Track**, or **Car** camera modes.
- Toggle several external camera modes back to the last driving-camera mode.
- Cycle through six car-camera positions by pressing **Car** again while that mode is active.
- Select a driver from the session list to focus their car, with driver-tag colors in the list.
- Return to your own car with **Focus own view**.
- Jump to the previous or next lap during replay playback.
- Recenter VR when a VR headset is connected.
- Hover controls for descriptions and relevant keyboard or configured binding information.

Track-camera sets are changed with **F3**. Free-camera keyboard access depends on the relevant AC system setting; its tooltip describes right-mouse look, arrow-key movement, and Ctrl/Shift speed modifiers.

## Crispy Driver Tags

Folder: `crispy_driver_tags`

Customizable labels above cars, designed to keep driver information readable without keeping every label fully visible at all distances.

- Driver names with optional national flags or custom driver icons.
- Online ping readouts with colors and warning symbols for higher latency.
- Recognized bracketed name tags are replaced with icons: `[STREAMER]` and `[TTV]` use the Twitch icon; `[ADMIN]` uses the admin icon; `[COOL_KID]`, `[DRIFT_KING]`, `[BAD_DRIVER]`, and `[ANGLE_MASTER]` use the Discord icon. Other bracketed tags remain as text.
- Use Content Manager/CSP driver-tag colors for names, outlines, or both, or choose custom text and outline colors.
- Adjust font, font size, outline width, flag size, and ping size.
- Toggle a background box and customize its color, padding, and corner roundness.
- Adjust base visibility distance and separate near/far fading behavior, including minimum close-range opacity.
- Choose whether labels appear for cars in the pits or pit lane.
- Maintain a server blacklist to suppress this app's labels on selected servers.
- Refresh tag registration or the car cache from the settings panel.
- Advanced options expose tag-container dimensions, server details, and an app-disable switch.

The blacklist and disable controls advise reloading the session to apply changes. The base visibility distance is combined with fade cutoffs, so labels can disappear before that maximum distance.

## Crispy FFB Controls `work in progress`

Folder: `crispy_ffb_controls`

Manage car-specific force-feedback gain, tune native AC/CSP settings, and inspect the signals while driving.

### Per-car defaults

- Automatic default gain, initially **60%**, with an adjustable **0–200%** target.
- By default, preserves a saved native per-car gain and also preserves a live gain that is already different from 100%.
- Saves automatically applied defaults to AC's native `user_ff.ini`.
- Optional **Override car gain** mode applies the chosen target at startup and when the override is enabled or its target changes.
- Live car-gain slider, a shortcut to 100%, and a reset to the original gain captured by the app.
- Automatic initialization is skipped during replays.

### Quick Settings and Controls

- Global FFB gain, filtering, and skip steps, with the resulting refresh-rate indication.
- Minimum force, center boost gain, and center boost range.
- Kerb, road, slip, ABS, and understeer effects.
- Gyro selection: **None**, **Standard**, or **FFB Tweaks**.
- Legacy CSP gyro strength control, whose effect depends on the CSP build.
- Damper gain and minimum level.
- Low-speed force-reduction threshold and multiplier.
- CSP range compression and range-compression assist.
- Native post-processing selection: **Disabled**, **Gamma**, or **LUT**.
- Gamma adjustment and selection of existing `.lut` files from `Documents/Assetto Corsa/cfg`. LUT creation/import is outside this app.
- Reset buttons for supported settings restore the values captured when the app initialized, rather than factory defaults.

These global controls save to AC/CSP configuration files and reload control settings. They affect more than the current car.

### Graph and Info

- Live final and pure FFB signals, current gain, car base multiplier, and steering-assist value when exposed by CSP.
- Approximately ten seconds of graph history, with final/pure traces and reference lines at ±100%.
- Peak final magnitude, RMS final signal, and percentage of samples at the output limit.
- Clear graph history on demand.
- A read-only configuration overview, including additional settings such as real steering forces, configured wheel peak torque, dirt vibration, and soft lock.

The graph shows normalized signals, not measured wheel torque in Nm. Output-limit samples indicate saturation, not a complete diagnosis of clipping. The Info page shows configured values; that alone does not establish that a feature is active for the current car.

## Crispy Pedals UI `work in progress`

Folder: `crispy_pedals_ui`

A compact input overlay with optional steering and force-feedback information.

- Clutch, brake, and throttle bars with smoothing.
- Optional handbrake bar and/or a handbrake indicator over the brake bar.
- Custom handbrake text or symbol.
- Optional rotating steering-wheel graphic.
- Optional FFB display in **Absolute** or **Signed (centered)** mode.
- An FFB warning symbol at the normalized output limit and red coloring beyond it.
- Optional percentage readouts and labels, with horizontal/vertical label orientation.
- Adjustable scale, bar width and height, spacing, background opacity, and smoothing.
- Color controls for pedals, handbrake, and positive/negative FFB.
- Reset controls for appearance and defaults.
- Additional FFB debug values in the settings panel.

FFB indicators use CSP's final normalized signal; they do not measure physical wheel torque. The main overlay captures the focused car when the script loads, so switching spectator focus later is not explicitly handled by the current implementation.

## Crispy Setup Loader `work in progress`

Folder: `crispy_setup_loader`

Remember a preferred saved setup for each car, independent of track, and attempt to restore it once per join.

- Choose from the car's saved `.ini` setups in generic and track folders.
- **Remember selected** stores a preferred setup for that car.
- Tracks setup loads and saves made through the original AC setup interface, remembering explicit setup files without replacing the preference with `last.ini`.
- Optionally use `generic/last.ini` instead of the remembered file for automatic loading.
- Enable or disable automatic loading per join.
- Experimental immediate loading attempts a load about 1.5 seconds after joining.
- If the early attempt is rejected, a short fallback window on the first setup-screen opening makes up to three attempts.
- A manual setup load/save cancels further automatic loading for that join, helping preserve your subsequent choices.
- Manual buttons load the selected setup, remembered setup, or `last.ini`, and refresh the list.
- Status messages explain missing files, unavailable editing, rejected loads, and successful requests.

**Setup loading requires an editable setup.** Fixed-setup restrictions still apply. The app's implementation notes that CSP supports setup loading in the setup menu; experimental pre-menu loading is not guaranteed to succeed or finish before you click Drive. Automatic loading stops after the initial attempt window. Automatic-loading option changes take effect on the next join.

## Crispy Quick Teleport `work in progress`

Folder: `crispy_teleport_to_friend`

Quickly rejoin tagged friends using destinations supplied by the online server.

- Lists connected players tagged as friends in Content Manager, sorted by name.
- Shows the chosen destination and its distance from each friend.
- A friend's **Teleport** button remembers that player as the quick target.
- A quick-teleport button and an assignable key/controller binding target the last chosen friend.
- If that friend is unavailable or no longer tagged, quick teleport cycles through available tagged friends while preserving the saved target for their return.
- Optional preference for destinations ahead of a friend's travel direction; when moving, velocity is used to better account for drifting.
- Within the configurable near threshold, uses the nearest available point even if it is behind the friend.
- Beyond that threshold, prefers an ahead point within the configured radius, falling back to the nearest available point if needed.
- Defaults to a **50 m** near threshold and **600 m** maximum ahead-search distance; both can be adjusted.
- Disable the ahead preference to always choose the closest available point.
- Resolves the friend's current position when teleporting and reports unavailable destinations or other errors.

**This uses server-defined teleport points, not arbitrary coordinates beside a friend.** It requires an online server with teleport destinations, permission to use an available point, and a compatible CSP build. Distances are straight-line distances rather than distances along the road. The custom binding starts unassigned and can be configured inside the app.

## Credits

- made with ❤️ by **SavageBulldogOG**
- Cam Select includes code from **x4fab's Unbound**; its source is referenced in the app manifest.
- FFB Controls follows parts of **x4fab's Controller Tweaks** for settings layout and behavior.
- Quick Teleport references **Tuttertep's Comfy Map** for server teleport-destination ordering and the tagged-friend workflow.

## License
I think i should declare at least somewhere that i use Codex in my workflow.

See [LICENSE](LICENSE).

---
