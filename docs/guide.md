# Larpblox user guide

This repository contains the Roblox client scripts. The browser extension is maintained and distributed separately.

A universal, local avatar editor with the Larpblox menu style. It has its own repository. An MM2 menu appears in Murder Mystery 2; the cosmetic tabs remain universal. It does not load features from the original hub.

## Load

Run this in your executor:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/main/launcher.lua", false))()
```

For a selectable branch, use `autoexec.lua` and change its first-line `branch` value. The selected GitHub branch is resolved to one commit for the loader and every module. Refresh reloads that branch rather than switching to main.

## Local names

> [!NOTE]
> Enable **Share appearance** on the browser's Avatar page to share supported looks and Larp names with other Larpblox users in the same server. Both clients must have sharing enabled. Larpblox Desktop connects the browser and game automatically.

Use **Larpblox Desktop 0.1.3 or newer**. Sharing travels from the game to desktop over localhost WebSocket, then through the public WebSocket relay. Changes are pushed as they happen instead of polling every three seconds. Desktop owns reconnects and presence; no browser extension update is needed for this transport. If desktop is older, update it before enabling sharing.

Your own name, portrait, and appearance come from the paired local browser connection and work without the shared relay. Other players' shared names, portraits, and appearances come from the relay while sharing is enabled.

Set an optional **Larp name** in the browser's **Robux** dropdown and enable **Larp mode**. An empty custom name keeps your original name and does not prevent avatar sharing. A paired browser connection sends it to the game automatically. There is no Names tab in the in-game menu. Disabling Larp mode or restoring the browser name restores the real in-game names when connected.

Names affect local overhead labels and accessible own-player rows, including the built-in player list and the People menu's display name and @username. Players without shared appearance enabled see your real identity. Protected CoreGui or custom game interfaces may prevent replacement; live executor verification is still needed.

## Accessories

1. Open **ACCESSORIES**.
2. Paste Roblox catalog links or numeric asset IDs, separated by spaces, commas, or new lines.
3. Click **Add accessories**. Existing hats stay on; you can keep adding more.

The added accessory list shows your count and a separate Remove button for each item. Successful entries clear from the input; any failed entries stay there to retry, with an explanation above the list.

Supports compatible rigid accessories, including hats, masks, and hair. Added accessories appear in a remove list. **Remove added accessories** leaves your existing accessories alone. Asset scripts are stripped before anything is equipped. Up to 20 added accessories are allowed per accessory type, including hats, hair, and face accessories. Body parts and classic clothes do not use accessory slots.

**Remove current Roblox accessories** hides the accessories your avatar is already wearing, including your account's hats. Accessories added by the hub stay equipped. **Restore original appearance** brings the original accessories back. Refresh re-applies your saved choice. This does not remove anything from your Roblox inventory.

### Doombringer satellite

Wear **Doombringer's Doombringer** (4640898) with Larp mode enabled. Its original satellite behavior is recreated as local visual effects:

| Chat command | Effect |
| --- | --- |
| `smite Username` / `smite me` | Fire a satellite beam with a visible impact at a player. |
| `target X Y Z` | Fire at coordinates. |
| `movesat X Y Z` | Move the satellite. |
| `location` | Show your coordinates in Larpblox's status. |
| `giveweapon me` | Add a local targeting tool; equip it and click to fire. |
| `kill Username` / `kill all` | Play cosmetic strikes without changing player health. |
| `armageddon` | Fire 25 visible strikes around your character. |
| `stop` / `...` | Cancel ongoing strikes. |

Effects and the targeting tool are removed when the hat is unequipped, Larp mode is disabled, or your character respawns. These effects do not damage players or grant tools to other players.

### Hat sounds

Wear Game Trailer Video Contest Winner (92719239) with Larp mode enabled to receive **Contest Winner Award** in your backpack. Equip it and click for the original applause sound and five seconds of gold sparkles. During those five seconds, touching small objects with the held award gives them a temporary local gold/ice appearance. Character parts are excluded; objects restore when the effect ends or the tool is unequipped. The original ready/busy cursor is restored while equipped, and your previous cursor returns afterward. Hat sounds settings and Roblox audio permissions apply.

Black Iron Crown of Pwnage (1078202) reproduces its original `Hello John` console greeting once when worn with Larp mode enabled. Its obsolete `RenderHooksService:EnableAdorns(false)` call is omitted to preserve Roblox's native controls. This script has no visual effects or chat commands.

Equipped accessories can play their embedded original sounds locally. Brighteyes' Witches Brew Hat uses its original three laughs and randomly plays one every 5–15 seconds while worn, matching its original SoundPlayer behavior. Hidden or removed hats stop hub-started playback. Roblox audio permissions still apply; arbitrary accessory scripts are not executed.

Original asset inspected: https://assetdelivery.roblox.com/v1/asset/?id=305888394 (WitchesBrewHat; Laugh 62777535, Laugh2 88108663, Laugh3 88108686).

## Clothes

1. Open **CLOTHES** and paste a classic 2D shirt catalog link or ID, then click **Equip shirt**.
2. Paste a classic 2D pants catalog link or ID, then click **Equip pants**.
3. Use **Restore original shirt** or **Restore original pants** to reset just that garment.

Shirts and pants work together and save like your other cosmetic selections, including after rejoining when file auto-save is on. These controls support classic `Shirt` and `Pants` assets; layered 3D clothing is rejected. Changing clothes keeps accessories, skin, body packages, emotes, and movement animations.

## Skin

1. Open **SKIN** and choose the whole body or a region with **Apply to**.
2. Expand **Roblox colors** for all 30 exact RGB swatches from the supplied screenshot, in its original 5-column order. You can also enter RGB numbers from 0 to 255 or paste a six-digit hex color.
3. Click the matching Apply button for custom colors.

Clothing and textured bodies can cover skin colors. R6 and R15 limb groups are supported.

**Restore original skin** resets only your skin colors and clears saved color overrides. It keeps added hats, body packages, hidden original accessories, emotes, and movement animations.

## Body

1. Open **BODY**.
2. Choose **Blocky**, **Girl**, or **Robloxian 2.0**, or paste a Roblox body bundle link/ID and click **Apply body package**.
3. Expand **Custom body parts** to mix a head, torso, left/right arm, and left/right leg from different packages. Each region has its own link box and Equip button. Use a body bundle URL to select that package's region, or the individual part's catalog URL/asset ID. Individual region replacement requires R15; arms and legs include matching hands and feet.
4. Use **Restore original body** to restore your avatar's original body shapes while keeping accessories, clothing, and skin colors.

The editor keeps your current character model, live limbs, rig, and gear connections. R6 uses compatible CharacterMesh bodies; R15 updates existing mesh appearance with ApplyMesh instead of replacing hands or other live body parts. Package limb dimensions and matching rig attachment offsets are applied to the existing limbs and body joints. Full packages also apply their floor height. Game gear attachments and tool joints are preserved; restore returns the original sizes, joint offsets, and floor height. Compatible Part-based heads use visual meshes. Unsupported conversions show an error instead of replacing a live part. Body bundles must expose a usable avatar outfit. The Girl and Robloxian 2.0 presets use Roblox's official outfits. Body-only package changes do not add the package's clothes or hair. Custom part selections save and reapply over your selected base package. Equipping a new full body package replaces the mixed part selections. Unsupported or restricted parts show an error; live compatibility depends on the asset and game.

Package changes preserve the source body's hidden parts, including Korblox Deathspeaker's invisible lower-leg and foot pieces. Restore original body returns your original parts' visibility.

## Emotes

1. Open **Emotes**.
2. Hover over a slot to play it on the preview avatar. Moving off the wheel returns the preview to idle.
3. Click a **+** to add an emote, or click an occupied slot to replace it.
4. Browse or search the emote thumbnails, select one, then choose **Add** or **Replace**. Use **Link or ID** if you already have a catalog link. Cancel leaves the slot unchanged.

Emote and animation browsers have **Previous** and **Next** pages and a **Sort by** menu. Changing the search or sort returns to page 1. Animation searches include off-sale components, which can still be selected locally.

The top-level tabs separate **Animations** and **Emotes**. The **Background** control in Settings lists backgrounds collected through the browser extension. Selecting one updates both previews and syncs back to the extension; choosing **None** clears it. Background purchases remain in the extension.

Open **Settings** and turn on **Emote while walking** to keep catalog emotes playing as you move. Turn it off or jump to stop the emote. This option requires standard Roblox emote controls and executor callback access.

Only the chosen slot changes. Your other equipped emotes stay in place. Assignments save and reapply after respawning or reloading the interface. Roblox's standard wheel requires an R15 avatar and the game's emote menu to be enabled. Private or restricted emotes may not play.

## Animations

Click **Bundle** to browse animation sets, or click an individual **Idle**, **Walk**, **Run**, **Jump**, **Fall**, **Climb**, or **Swim** row to browse that type. Select an animation and choose **Apply**. **Link or ID** remains available for catalog links. **Current avatar** restores the active real or larp avatar's animation for that type.

The avatar preview shows changes without moving your character. Saved choices return after resets or reloading the interface. Animation changes require an R15 avatar with Roblox's standard Animate controls; games with custom movement systems may not support them.

## Saved characters

1. Put together your look using the cosmetic tabs.
2. Open **CHARACTERS**, click **Create New Character**, enter a name, and click **Create**.
3. Click a square character preview to equip it. Names appear underneath; **Search by name...** filters the grid as you type. The grid widens on desktop and adapts to smaller screens.
4. Click the cog in the top-right of a preview for **Update**, **Rename**, **Delete**, and **Cancel**. Update replaces that saved character with your current look and preview; Rename changes its name. Delete asks for confirmation and leaves your equipped look alone.

Save up to 12 looks. Each snapshot keeps your hub accessories, skin colors, body package and individual parts, classic clothes, emote slots, and movement bundle. Equipping replaces all those selections and makes that look the one that returns after resets and rejoining. Saved looks use your current account avatar as their original base; they do not change your Roblox account. File access is required to keep the wardrobe after leaving, just like the other saved settings. Previews show the saved outfit’s classic shirts and pants alongside its body and accessories. Native body meshes are reused or loaded in the background so classic clothing can render without blocking the menu. Previews are local visual snapshots; asset permissions and unusual game characters can limit rendering.

## Controls and limits

- **Restore original appearance** removes added accessories, brings back hidden original accessories, restores original clothes, the captured body, colors, emote wheel and movement animations, and clears saved cosmetic selections.
- **Right Shift** shows/hides the menu. Hiding keeps your changes.
- In the weapon position editor's avatar preview, **left-drag** rotates, **right-drag** moves the view up/down/sideways, and **scroll** zooms. Moving the view does not change weapon placement.
- Weapon position, rotation, and size adjustments save when you release a slider or finish editing a number, and when rerunning closes the editor. **Cancel** restores the settings from when you opened it. With **Auto-save: on**, adjustments also survive leaving and rejoining.
- **Refresh** closes the old editor and loads the latest version from this repository, then reapplies your saved cosmetics.
- Respawning or resetting automatically reapplies your body package, hidden original accessories, added accessories, and per-region colors after your new character finishes loading.
- **Reapply saved cosmetics** retries saved items if an asset failed to load. Failed saved items are kept for retry.
- Hiding original accessories changes only their local visibility. Identified avatar hats stay parented with their scripts and joints intact; unidentified game equipment is left alone. The hub does not clear Backpack tools or rebuild game-owned accessory joints.

Selections and editor fields survive respawns, resets, Refresh, and re-running the launcher. When your executor supports `readfile` and `writefile`, automatic saving also stores accessories, classic shirts and pants, colors, body packages, emote slots, movement bundles, and editor fields in `HoneyBunCosmeticHub_<RobloxUserId>.json`, with a `.bak` backup. Run the hub again after rejoining to load them. The file belongs to your account on that executor/device and is shared across games; it does not follow you to a different device automatically.

The menu displays **Auto-save: on**, **session only**, or a file-write failure. Without executor file access, saving lasts only for the current Roblox session. Refreshing into this version saves your existing selections automatically.

Accessory, body, skin, and wheel assignment changes are local. They do not update your Roblox account avatar. Animation and emote playback uses the character's existing Animator: when that Animator was created by the server, Roblox normally shares the playback with other players. This depends on the game's character system and asset permissions; multiplayer visibility has not been verified in a live session. Asset permissions, custom game characters, and client API restrictions can prevent an item or package from loading; the menu shows an error. Layered clothing is not supported by the rigid accessory equipper.

## Verification

```sh
npx --offline --package=fengari-node-cli fengari tests/avatar.lua
npx --offline --package=fengari-node-cli fengari tests/menu.lua
npx --offline --package=fengari-node-cli fengari tests/motion.lua
npx --offline --package=fengari-node-cli fengari tests/animations.lua
npx --offline --package=fengari-node-cli fengari tests/storage.lua
npx --offline --package=fengari-node-cli fengari tests/clothes.lua
npx --offline --package=fengari-node-cli fengari tests/characters.lua
npx --offline --package=fengari-node-cli fengari tests/previews.lua
npx --offline --package=fengari-node-cli fengari tests/mm2.lua
npx --offline --package=fengari-node-cli fengari tests/native_inventory.lua
npx --offline --package=fengari-node-cli fengari tests/mm2_effects.lua
```

These use Roblox stand-ins to check the editor logic; they do not prove that a game permits a particular asset.

API references: [Accessories](https://create.roblox.com/docs/reference/engine/classes/Accessory), [Humanoid body-part replacement](https://create.roblox.com/docs/reference/engine/classes/Humanoid#ReplaceBodyPartR15), [Players avatar generation](https://create.roblox.com/docs/reference/engine/classes/Players#CreateHumanoidModelFromDescriptionAsync), [emote assignments](https://create.roblox.com/docs/reference/engine/classes/HumanoidDescription#SetEquippedEmotes), and [animation replication](https://create.roblox.com/docs/reference/engine/classes/Animator#LoadAnimation).

## Lighting

Open **Lighting** to adjust time, brightness, colors, fog, shadows, and post-processing. Sliders apply immediately; the number fields accept exact values. Click a color swatch for RGB controls, or enter a hex color.

Choose a sky tile or expand **Custom skybox** for a model link or ID. **Advanced sky** exposes the six faces, sun, moon, and stars. The included skies use real Roblox assets and thumbnails: [Sunset Dawn](https://create.roblox.com/store/asset/325545295/Sunset-Dawn-Skybox) and [Grimm Night](https://create.roblox.com/store/asset/332466267/Grimm-Night-Skybox-HD) by dearjournal, and [Sunset](https://create.roblox.com/store/asset/402561625/Sunset-Skybox) by camcool12354.

**Save preset** stores your current overrides. Saved presets can be loaded, updated, renamed, or deleted. Existing saved atmospheres remain available. **Restore game** removes your lighting and sky overrides. These changes are visible only to you.

## MM2 local cosmetics

The sheriff crosshair accepts Roblox image IDs and decal IDs or links, including Creator Store links. Decals are resolved to their image texture before previewing and saving.
Drag the **Crosshair Size** slider to set its width and height from 8 to 200 pixels; the default is 40. The size saves with your other choices.

**Show all MM2 emotes** remembers ON or OFF across Refresh and rerunning the menu. With **Auto-save: on**, it also restores your choice when you run the menu after rejoining MM2, including the Game Emotes bar.

Open MM2's Weapons inventory, then open **MM2** in the hub and enable **Show all weapons**. Supported native item cards are copied into the game's inventory window using the loaded knife/gun catalog. Click a local card to select it. The selection applies to a matching native weapon now or when it becomes available, and reapplies after respawning. Season 1, Classic, and Holiday use the loaded item metadata; cards sort by available order metadata, rarity, chroma status, and name. The local collection reconnects when MM2 reopens or rebuilds its inventory. Disable the toggle to restore the original inventory display and weapon appearance.

This changes the local inventory display; it does not add ownership or trading rights. It requires a recognizable native card layout and loaded catalog. Unsupported layouts or model formats report an explanation. Use **Copy MM2 report** if the inventory cannot be detected. Live compatibility with every rare item and emote is not yet verified.

Weapon appearances are visible only to the person running the hub. The hub tries the selected model asset and exact, identifiable copies MM2 has already loaded. If neither source is available, the inventory selection remains saved but its avatar appearance cannot be shown. Loaded scripts are stripped; supported meshes are applied to the existing native weapon/display without replacing its connections. The tab matcher supports image buttons with separate caption labels. Copy MM2 report includes category totals, matched tab controls, pending selections, item asset IDs, and equip failures.

### Saved weapons and effects

In **MM2 → Save a look**, choose a player, select Gun, Knife, and/or Effect, then press **Save selected**. Save while the player holds the weapon to capture its appearance and loaded sounds.

Your captures appear under **Saved weapons** and in MM2's **Weapons → Saved Weapons** inventory. Click a card to equip it; its menu lets you rename or delete the saved copy. Saved effects appear in MM2's **Effects** inventory. Captures survive rejoining when file saving is available, and the source player does not need to remain in the server.

**More options** contains refresh, weapon matching, server-effect capture, and reporting tools. Rendering depends on Roblox making the source assets available. These local previews do not grant ownership or trading rights.

## Personal saves and distribution

Distribute the published source files, not your executor workspace or personal save files. Outfits, saved MM2 weapons/effects, cosmetic selections, custom names, and menu preferences are saved locally per Roblox account in `HoneyBunCosmeticHub_<UserId>.json` (plus its `.bak` backup). They are not uploaded by the save system or bundled in the repository. New users start with their own empty saved collections. Existing local save files remain compatible; newly written files also include the owning account ID.

Personal save files are excluded by `.gitignore`. These are local files, not encrypted storage; someone with access to the same computer can read them.

## Larp mode in Roblox menus

While the browser is paired and Larp mode is on, recognized local-player portraits in Roblox's player list and People menu use a live local avatar preview. Opening your own avatar inspector requests Roblox's native inspector with the effective Larp outfit and browser name. Supported catalog accessories, classic clothes, body parts, colors and scales come from the same outfit snapshot as browser sync; hidden originals are excluded. Game-only props without catalog assets cannot appear in the native catalog item list.

While Larp mode is loading, recognized own portraits stay blank. The inspection page and its controls remain visible; account avatar, name, and item content are masked until the Larp replacements are ready. The inspection viewport renders a capture of the live local character, so Roblox normalizing its generated body description cannot leave the Larp preview permanently blank. Failed avatar loads leave only the preview blank, so the inspection page remains usable. Turning mode off or disconnecting restores the original portraits and own inspector. These are local views and do not change account ownership or other players' screens. Inspector detection currently recognizes Roblox's English own-avatar title inside InspectAndBuy; protected or changed native layouts may prevent detection. Automated stand-in tests cover matching, outfit conversion and restoration; live executor compatibility has not been verified.


## Browser gear

The browser wardrobe's Gear category contains catalog gear (asset type 19), separately from hats and other accessories. Wear selects one held Larp gear at a time; Remove clears it. Selected gear is included in browser outfit exports and connected outfit snapshots, so browser outfit previews and Currently Wearing use the same selection.

The connected game loads the gear's visual parts locally and strips scripts. It preserves the game's existing equipment; gear-specific attacks, powers, and purchases are not enabled. The live local avatar preview includes the held visual. Roblox's native inspection catalog list uses HumanoidDescription, which does not provide a gear slot, so that native list cannot include gear as a normal accessory card.
