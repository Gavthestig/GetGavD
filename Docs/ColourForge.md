# ColourForge 1.1 preview

[Download the complete installer](https://github.com/Gavthestig/GetGavD/releases/download/colourforge-v1.1/ColourForge-1.1-Share.zip) · [Release files](https://github.com/Gavthestig/GetGavD/releases/tag/colourforge-v1.1)

Extract the complete ZIP, close the game and run Install.cmd. Do not run the script directly from inside the ZIP. The installer requires Windows x64 and the exact supported game executable: 1.0.6.889 or 1.0.7a.903. It downloads the official QuestionableM SM-DLL-Injector v1.8 if necessary, verifies its checksum, installs ColourForge.dll in Release/DLLModules, and registers the tool and assets. It archives the old Native-Drag-Bridge.dll to prevent duplicate loading.

The separate DLL-only ZIP is for manual installation and does not contain all mod assets or Challenge registration. Most players should use the complete installer. Never substitute the old SM-BetterPaintTool.dll.

## Finding the tool

For a step-by-step **Workshop + DLL + injector** setup, open [How to download and enable](../README.md#how-to-download-and-enable) on the main page and expand that option. [SM-DLL-Injector v1.8 download](https://github.com/QuestionableM/SM-DLL-Injector/releases/tag/v1.8) · [Injector author's installation instructions](https://github.com/QuestionableM/SM-DLL-Injector#how-to-install).

The Workshop supplies the model, textures, scripts, GUI and icons; ColourForge.dll supplies the native painting component; the injector loads that DLL when the game starts. All three are needed for the Workshop route. Enable the Workshop mod in the Creative world's mod list. Use the complete installer for additional Challenge registration; Workshop + DLL alone does not provide it. Matching files and a supported game build are required, and this route still needs separate-installation verification.

Creative and Challenge Builder: look in Tools. Survival: craft using the normal paint tool ingredients. Challenge play: the challenge must allow the paint tool. Survival and Challenge-play wiring need further testing. Registration does not bypass a challenge’s tool restrictions.

## Using it

Q toggles the picker; Escape closes it. Choose a colour using the wheel, RGB controls, presets or six-digit HEX. Selection applies live. Left drag paints, right drag erases and middle mouse samples a shape’s colour. The gun accents show your selected colour.

## Troubleshooting

Missing tool, blank icon or no picker: confirm you used the complete package and installed into the game folder you actually launch, then restart the game. A Workshop subscription alone cannot install the required native module. For native errors check ColourForge.log beside the DLL. An unsupported executable requires an updated build; do not disable the version checks. Do not load both ColourForge.dll and the legacy Native-Drag-Bridge.dll.

## Backups and uninstall

Keep Scrap Mechanic/ColourForgeBackups. Uninstall.cmd restores the latest setup backup. Uninstall before game updates or other changes to the same files: restoring an old backup later can overwrite newer changes. A pre-existing loader is retained. Remove the tool from hotbars before uninstalling. Setup does not edit world saves.

## Verification limits

Earlier Creative and Challenge Builder behaviour was user-tested. The 1.0.7a native routines were compared across builds and the installer/uninstaller passed isolated real-file fixture checks. Actual painting on 1.0.7a and multiplayer remain unverified. No extra block materials, metallic finishes or physical lights are added.
