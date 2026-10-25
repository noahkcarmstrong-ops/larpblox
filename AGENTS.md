# Larpblox project instructions

## Project terminology

- **unlarp** = the original player / avatar.
- **deadname** = the unlarp's name.

## Reuse native Roblox behavior

- Inspect Roblox's existing code and behavior before implementing a replacement. Prefer reusing its native rendering, formatting, controls, and lifecycle handling.
- Supply Larpblox's local presentation data through the narrowest supported API or targeted hook so Roblox retains ownership of layout, spacing, icons, and interactions.
- Add custom rendering only when the native path cannot support the requirement. Keep that fallback small and avoid duplicating platform behavior or hardcoding individual games.

## Preserve game behavior through generic mappings

- Treat Larpblox as a minimally invasive presentation layer. Let Roblox and the game retain control of gameplay, character lifecycle, and appearance changes; substitute only the presentation covered by an explicit Larp mapping.
- Define the mapping and its boundaries before implementing a fix. Prefer rules based on observable identity and state over guesses about intent, timing, object names, or a particular game's implementation.
- For avatar substitutions, map the original avatar's appearance to its Larp equivalent. Preserve game changes outside that mapping. For example, a different uniform remains visible; restoring the original shirt makes its Larp replacement visible again. Apply this reasoning to accessories, faces, makeup, and other appearance features rather than special-casing clothing or one game.
- Distinguish ownership of our writes and resources from the reason for an external change. Identify our own updates to avoid feedback loops and clean them up safely. Do not require guessing whether an external update came from a uniform, respawn, reward, or another game action when the same mapping rule can handle it.
- Consider equivalent outcomes reached through different mechanisms: property edits, instance replacement, additions/removals, whole-description application, character replacement, and cloned or ragdolled bodies. Preserve unrelated game effects, including visibility, scaling, and death effects, instead of repeatedly forcing a saved outfit over them.
- Check ambiguous cases explicitly. If a game grants an item identical to the original avatar's item, identity alone cannot reveal its intent. Apply the same mapping consistently unless an explicit, reliable signal distinguishes the cases; state the limitation rather than inventing a timing heuristic.
- Before claiming a generic fix, reason through initial load, repeated changes, restoration to the original, respawn, death, feature disable, and interface reload. State which cases are supported by evidence and which remain unverified. Do not add polling or game-specific exceptions to hide an unresolved model.

## Preserve Roblox's native icons

- Do not modify Roblox installation files, bundled sprite sheets, or native menu/voice-chat icons. The user explicitly requested these remain untouched after a cross-version image-sheet replacement broke the UI.
- Never copy Studio assets into a Player installation or mix assets between Roblox versions.
- Keep Larpblox identity and avatar changes scoped to player names, badges, and avatar thumbnails; exclude native controls, keyboard hints, separators, and voice indicators.
- For suspected native asset problems, inspect first. Restore only files previously changed by this project, using the exact installed Player version and a verified backup; do not replace assets from another build.

## Event-driven behavior and performance

- Prefer event-driven updates and targeted executor hooks over polling. React to the actual state change instead of repeatedly checking for it.
- Prefer native events over hooks when they expose the required change. Use a hook only for a demonstrated observation gap; avoid broad metamethod interception such as a global `__newindex` hook when scoped events suffice.
- Do not introduce polling loops, recurring timer checks, or per-frame scans to detect changes. Do not disguise polling as a Heartbeat, RenderStepped, or PreAnimation listener.
- When Roblox does not expose a suitable event, use a narrowly scoped executor hook for the relevant callback, property assignment, or method invocation. Preserve the original behavior and arguments, avoid recursive hooks, and ignore unrelated objects.
- Coalesce duplicate events with deferred work when needed. A deferred reaction to an event is appropriate; a repeating retry timer is not.
- Disconnect listeners and release hook ownership when a character is replaced, a feature is disabled, or the module is destroyed. Keep hooks safe across interface reloads.
- If neither an event nor a safe hook can observe the change, explain the limitation and ask before adding any polling fallback.
