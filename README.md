<p align="center">
  <img src="assets/larpblox-logo.png" alt="Larpblox" width="520">
</p>

<p align="center">be who you never will.</p>

![Without Larpblox and with Larpblox comparison](assets/larpblox-before-after.png)

Larpblox lets you create a different look and name on Roblox.

## 1. Set up your browser

1. Install [Tampermonkey](https://www.tampermonkey.net/) in your browser. Already use [Violentmonkey](https://violentmonkey.github.io/get-it/)? That works too.
2. If you have the old Larpblox extension, turn it off on your browser's **Extensions** page.
3. Click **[Install Larpblox](https://github.com/3xjn/larpblox-extension/releases/download/main-latest/larpblox.user.js)**, then click **Install** on the page that opens.
4. Refresh Roblox. Click the Tampermonkey or Violentmonkey icon beside your address bar, then **Open Larpblox**.

Updates happen automatically through your script manager. Greasemonkey is not supported yet.

[Need help installing?](docs/userscript-install.md)

## 2. Use it in games

Install and open [Larpblox Desktop](https://github.com/3xjn/larpblox-desktop/releases) to connect your browser outfits and names to the game. Then load Larpblox using the instructions below.

## Load Larpblox in Roblox

Run in a compatible Roblox client executor:

The interface uses [Prism](https://github.com/3xjn/prism) with Larpblox's classic styling. The executor needs local file and asset support (`writefile` and `getcustomasset` or `getsynasset`).

```lua
local branch = "main"
loadstring(game:HttpGet("https://raw.githubusercontent.com/noahkcarmstrong-ops/larpblox/" .. branch .. "/launcher.lua", false))(branch)
```

## Features

- Edit accessories, clothes, skin, body parts, emotes, and movement animations.
- Save and switch between character looks.
- Pair with the browser wardrobe for outfit sync and optional Larp names.
- Share supported appearances with Larpblox users in the same live server.

> [!NOTE]
> Appearance changes affect your local client. Enable **Share appearance** on the browser's Avatar page to share supported looks with other Larpblox users in the same server. Both players must enable sharing. A custom Larp name is optional.

<details>
<summary>Murder Mystery 2</summary>

Local inventory, weapon, and effect previews. They do not grant ownership. See the [user guide](docs/guide.md#mm2-local-cosmetics).

</details>

## Documentation

- [User guide](docs/guide.md)


<details>
<summary>Developer information: avatar diagnostics</summary>


Executor logs are written to `logs/larp/latest.log`; the previous session is archived when a new session starts. Loading and generation operations have paired `operation_start` / `operation_finish` records with unique operation IDs, parent IDs for nested calls, player/asset context, elapsed milliseconds, and errors. Starts and finishes are flushed immediately. Normal mode records individual mesh/accessory mutations only on failure or when they take at least 16 ms; verbose mode includes their paired checkpoints. An unfinished operation identifies a call that was in progress when logging stopped, not proof that it caused a crash. Interface teardown records unfinished operations as cancelled.

For deeper captures, configure the shared options table before loading the interface:

```lua
getgenv().larpblox = {
    diagnostics = {
        verbose = true,
    },
}
```

During a session, change `getgenv().larpblox.diagnostics.verbose` directly; initialization preserves existing options. Verbose mode adds Lua memory, total client memory, instance counts, and individual mesh-application checkpoints. Set it to `false` to return to normal logging. Stats are sampled at operation boundaries only; there is no recurring sampler. Verbose logging adds disk writes and should be used for diagnosis rather than performance benchmarking.

</details>
