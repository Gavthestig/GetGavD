# ColourForge 1.2 — original game gun

[Download the complete installer](https://github.com/Gavthestig/GetGavD/releases/download/colourforge-v1.2/ColourForge-1.2-Share.zip) · [Release files](https://github.com/Gavthestig/GetGavD/releases/tag/colourforge-v1.2)

Extract the complete ZIP, close the game and run Install.cmd. Do not run the script directly from inside the ZIP. The installer requires Windows x64 and the exact supported game executable: 1.0.6.889 or 1.0.7a.903. It downloads the official QuestionableM SM-DLL-Injector v1.8 if necessary, verifies its checksum, installs ColourForge.dll in Release/DLLModules, and registers the tool and assets. It archives the old Native-Drag-Bridge.dll to prevent duplicate loading.

The separate DLL-only ZIP is for manual installation and does not contain all mod assets or Challenge registration. Most players should use the complete installer. Never substitute the old SM-BetterPaintTool.dll.

## Finding the tool

For a step-by-step **Workshop + DLL + injector** setup, open [How to download and enable](../README.md#how-to-download-and-enable) on the main page and expand that option. [SM-DLL-Injector v1.8 download](https://github.com/QuestionableM/SM-DLL-Injector/releases/tag/v1.8) · [Injector author's installation instructions](https://github.com/QuestionableM/SM-DLL-Injector#how-to-install).

The Workshop supplies the model, textures, scripts, GUI and icons; ColourForge.dll supplies the native painting component; the injector loads that DLL when the game starts. All three are needed for the Workshop route. Enable the Workshop mod in the Creative world's mod list. Use the complete installer for additional Challenge registration; Workshop + DLL alone does not provide it. Matching files and a supported game build are required, and this route still needs separate-installation verification.

Creative and Challenge Builder: look in Tools. Survival: craft using the normal paint tool ingredients. Challenge play: the challenge must allow the paint tool. Survival and Challenge-play wiring need further testing. Registration does not bypass a challenge’s tool restrictions.

## Using it

Q toggles the picker; Escape closes it. Choose a colour using the wheel, RGB controls, presets or six-digit HEX. Selection applies live. Left drag paints, right drag erases and middle mouse samples a shape’s colour. The gun accents show your selected colour.

## Troubleshooting

### Gun appears, but painting and the eyedropper do nothing

If you see **“Native drag bridge is not attached; no paint applied”**, the native painting component is unavailable. In the confirmed case on 19 November, `ColourForge.dll` was present, but the injector had been replaced by the standard Microsoft runtime. The model was not the cause. Restoring the injector fixed painting and middle-mouse sampling.

1. Close Scrap Mechanic completely.
2. [Download the complete ColourForge 1.2 installer again](https://github.com/Gavthestig/GetGavD/releases/download/colourforge-v1.2/ColourForge-1.2-Share.zip).
3. Right-click the ZIP → **Extract All** → open the extracted folder.
4. Run **Install.cmd** and let setup finish. It checks the official injector, reinstalls it if needed and keeps a backup of the Microsoft runtime.
5. Start the game normally and load your world. Select ColourForge, press **Q** to choose a colour, then test painting and middle-click sampling.

The installer is the simplest repair. Replacing **ColourForge.dll alone** cannot restore a missing injector. If you prefer manual setup, follow [SM-DLL-Injector's official installation instructions](https://github.com/QuestionableM/SM-DLL-Injector#how-to-install); do not delete the original Microsoft runtime backup. Check Steam launch options for `-noinject`, which disables the injector.

After restarting, `Release/DLLModules/ColourForge.log` should receive a **new** “ColourForge DLL loaded…” entry. An old log entry from a previous session is not proof that it loaded this time. Game updates or Steam file verification can replace modified game files; rerun the matching installer if the problem returns. This message can also have other causes, so check the log for an unsupported version or initialization error if reinstalling does not help.

Missing tool, blank icon or no picker: confirm you used the complete package and installed into the game folder you actually launch, then restart the game. A Workshop subscription alone cannot install the required native module. For native errors check ColourForge.log beside the DLL. An unsupported executable requires an updated build; do not disable the version checks. Do not load both ColourForge.dll and the legacy Native-Drag-Bridge.dll.

## Backups and uninstall

Keep Scrap Mechanic/ColourForgeBackups. Uninstall.cmd restores the latest setup backup. Uninstall before game updates or other changes to the same files: restoring an old backup later can overwrite newer changes. A pre-existing loader is retained. Remove the tool from hotbars before uninstalling. Setup does not edit world saves.

## Verification limits

Earlier Creative and Challenge Builder behaviour was user-tested. The 1.0.7a native routines were compared across builds and the installer/uninstaller passed isolated real-file fixture checks. On 19 November, the user confirmed the original-gun edition working locally after the verified injector was restored, following a report that painting and the eyedropper failed. This confirms that local repair; it does not establish compatibility in every game mode or multiplayer. No extra block materials, metallic finishes or physical lights are added.
