# Changelog

## ColourForge 1.2 — original game paint gun — 19 November 2026

* Uses Scrap Mechanic's installed paint gun model and matching animations instead of the Vaporator custom model.
* Uses the original paint gun inventory image and preview. The menu header and Workshop preview now match this edition.
* Keeps the colour wheel, RGB/HEX, live colour selection, Q menu, drag paint/erase and middle-mouse eyedropper.
* Keeps the unique icon sheet names and original icon positions from the icon repair.
* Existing native DLL is compatible and unchanged. Update the Workshop files or run the matching complete installer; replacing the DLL alone cannot switch the model.
* File references and icon pixels checked. This model change still needs an in-game visual check.

## ColourForge gun icon lookup fix â€” 18 November 2026

* Fixed a filename collision between the normal and Challenge inventory sheets that could show an unrelated item as ColourForge's icon.
* Uses distinct ColourForgeInventoryIcons.png, ColourForgeChallengeIcons.png and ColourForgeToolIcon.png names.
* Checked that both game sheets contain the gun image at the registered coordinates and that all other icon pixels and positions remain unchanged. Workshop package validation passed.
* Re-download and run the corrected complete installer to repair existing Challenge registration and icon references. Workshop subscribers receive the mod icon asset update through Steam; the native DLL has not changed.

## ColourForge 1.1 installer icon fix â€” 18 November 2026

* Preserves the original inventory icon sheet dimensions and all existing icon positions.
* Copies the icon sheet in pixels to prevent Windows display scaling from shifting the icons.
* Places the ColourForge icon in an unused cell. Existing icon pixels were checked against the originals for both the normal and Challenge inventories.
* The complete installer ZIP on the ColourForge 1.1 release has been replaced with the corrected package. Download it again, close the game, extract it and run Install.cmd to apply the fix. The native DLL has not changed.

## ColourForge 1.2 — original game gun â€” 18 November 2026

* Named ColourForge.dll distribution and complete companion installer.
* Exact 1.0.6.889 and 1.0.7a.903 executable support tables with native routine comparison.
* Legacy bridge migration, checksummed loader download, backups and uninstall restoration.
* Colour wheel, live selection, Q/Escape, drag erase, eyedropper and matching gun accents.
* 1.0.7a in-game painting and multiplayer still require verification.

## Paintball & Grenades 0.8 testing

* Paintballs, temporary surface/character splats, aiming and hopper refill visuals.
* Paint and smoke grenades with selected colour.
* Static smoke colour palette and taller layered coverage; latest smoke behaviour unverified in game.
