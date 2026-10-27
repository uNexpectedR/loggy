# Corner assistant

A small assistant that sits in a corner, in the role Clippy had in Word. Its first task, and the only one, is to run a Logos blockchain node. After that it waits. Later tasks are not in this slice.

Logos Basecamp is a Qt/QML desktop shell. UI apps are `ui_qml` modules loaded into that shell, and they call core modules with `logos.callModule`. The module in `assistant/` is that package. This environment has no Nix and no Basecamp binary, so `preview/` is a local window you can open in a browser. It is not Basecamp.

## Preview

```bash
python3 preview/serve.py
```

Open http://127.0.0.1:47291

The workspace behind the assistant still takes clicks and typing. Only the speech bubble and the character receive pointer events. Drag the character to move it. That spot lasts for the page session.

## Run a node

The button runs `preview/run_node.py` through `logosctl` 0.3.2. The page does not download anything.

It looks for the binary in `$LOGOSCTL`, then `bin/logosctl`, then `PATH`. The pinned Linux x86_64 archive is `logosctl-x86_64-linux.tar.gz` from [logosctl 0.3.2](https://github.com/logos-co/logos-logoscore-cli/releases/tag/0.3.2), SHA-256 `294fbcc6409a8851b7471582bdad2dbfaf681b5d1c67dfffec38ada925dc6762`. Install steps are in the [Logos node guide](https://docs.logos.co/run-a-node).

When the binary is present, the script:

1. Starts `logosctl daemon` if this session is not already running.
2. Loads `blockchain_module` 0.3.2. If it is not installed, refreshes the catalogue and installs that version, root hash `9ab4acbb734a85b0271f88d6db87f6d6ca3c6d96a3b27bacaa4ab11f67b6f0d7`.
3. Writes `user_config.yaml` with `generate_user_config` and the public testnet bootstrap peers from the 0.3.2 release notes, if a config is not already there.
4. Calls `start` with that config and an empty deployment string.
5. Reads `get_cryptarchia_info`.

A success line includes the real mode, height, and slot. `Bootstrapping` counts as running. A failure shows the command error. The panel never pretends the node is up.

Keys and config stay in `data/logos-node` (gitignored). The script does not print them.

`logosctl` itself loads the modules baked into the 0.3.2 binary: package manager, package downloader, storage, capability, and module state. This slice does not install the delivery module and does not mine.

Inside Basecamp, `assistant/Main.qml` calls the same three methods on `blockchain_module` through `logos.callModule`. Package it with Nix from `assistant/` (`nix build`, module builder 0.3.0). That build is not run here.

The published package is `corner_assistant` 0.1.4. It is QML only, so `main` is empty and the same files are in the portable `linux-amd64` and `darwin-arm64` variants. There is no native plugin. Install it in Basecamp from:

https://github.com/uNexpectedR/loggy/releases/download/corner_assistant-v0.1.0/logos-repo.json

That catalogue lists 0.1.4. The package file is on the `corner_assistant-v0.1.4` release. Refresh the repository, then install Corner assistant 0.1.4.

## Real and stubbed

Real: the `ui_qml` module, the `logos.callModule` methods, and the preview's `logosctl` / `blockchain_module` 0.3.2 run.

Stubbed: the browser shell is not the Basecamp app. The character is the reference photo with the beige wall removed, not a drawing and not a 3D view. It bobs a few pixels. In Basecamp it is drawn in the content area. Drag it; the place lasts until the module is closed. Only the character and the bubble take clicks.

A real cocoa window is translucent with `FramelessWindowHint`, `NoDropShadowWindowHint`, and a clear color. This module is a `QQuickWidget` in the dock. Clearing that widget paints black, which is what 0.1.2 did, and `Qt.Tool` kept the child window offscreen. The root item is not filled. The page uses Basecamp's content color (`#171717`) so it is not a white page, and the photo has no backdrop. The preview is where the rest of the window stays usable.
