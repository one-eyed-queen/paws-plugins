# paws-plugins

Version-pinned `download.lua` builds for [paws](https://github.com/one-eyed-queen/paws) and SLSsteam.

paws installs one of these as `~/.config/SLSsteam/plugins/download.lua`, chosen from
[`manifest.json`](manifest.json) by Steam architecture, Steam client build and SLSsteam version.
The bundled 32-bit copy inside paws is only the offline fallback; this repo is the source of truth
for version-matched plugins.

paws verifies the SHA-256 in the manifest before it installs anything. Do not edit these files in
place: change the file, update its hash in `manifest.json`, then let paws re-fetch it.

## Files

| file | for | notes |
|---|---|---|
| `plugins/download-steam64.lua` | 64-bit `steamrt64` Steam client | x64 port: SysV hooks, RIP-relative call-site patterns, x64 `PackageInfo_t`, absolute-path `libtier0_s.so` load, HTTPS MRC with validation/cache/backoff and guarded hooks |
| `plugins/download-steam32.lua` | 32-bit `ubuntu12_32` Steam client | the original plugin paws has shipped for years |
| `plugins/LICENSE` | both | MIT, copyright ciscosweater (original plugin) |

## ASSella plugin mirror

[`contrib/assella/`](contrib/assella/) carries niwia's five SLSsteam Lua plugins from
[niwia/ASSella](https://github.com/niwia/ASSella), verbatim and GPL-3.0 with attribution. They are
not selected by `manifest.json` and are not installed by `paws plugins download`. SpaceBunny covers
the same job as `download.lua` but is x86-era; the verified x64 plugin remains the one in
[`plugins/`](plugins/). See [`contrib/assella/README.md`](contrib/assella/README.md) for hashes,
versions. The MRC robustness ideas were reimplemented clean-room in the x64 plugin (`2026.11.23-x64-3`);
no GPL code was copied into it.

## Manifest

`manifest.json` maps `{steam_arch, steam_build, sls_version}` to a file, URL, SHA-256 and pattern set.
Selection is exact first, then wildcard/range entries, then a default.

After Steam or SLSsteam updates, add a new entry with the new version triple and the hash of the
verified plugin. `paws repair` (or `paws plugins download`) will then pick it up.

## Credits

- **ciscosweater** — original 32-bit `download.lua`, MIT (license in [`plugins/LICENSE`](plugins/LICENSE)), via [enter-the-wired](https://github.com/ciscosweater/enter-the-wired).
- **niwia and the ASSella contributors** — SpaceBunny, Styx, Lobster, Lettuce and Pineapple, GPL-3.0, mirrored with attribution in [`contrib/assella/`](contrib/assella/). The x86 patterns and provider/proxy design informed paws' pattern checking and failure handling; no GPL code was copied into paws' plugin.
- The x64 port of `download.lua` is maintained here for paws. The manifest-code service used by the plugin (`gmrc.wudrm.com`) is external to this repo.
