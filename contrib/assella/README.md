# ASSella plugins — upstream mirror

These are niwia's SLSsteam Lua plugins from [niwia/ASSella](https://github.com/niwia/ASSella), kept here verbatim so the paws plugin collection can carry them with provenance. **Credit goes to niwia and the ASSella contributors.** Do not present these as paws' work.

- Upstream commit: `ebf6e992338f86f76c5cbdf80f10d8df8e480da9` (2026-11-22)
- Upstream manifest: `src/res/plugins/plugins_manifest.json`, `manifest_version: 2`, serial `20261110130206`
- Upstream license: GPL-3.0, copy included as [`LICENSE`](LICENSE)
- Hashes: [`SHA256SUMS`](SHA256SUMS), checked against the upstream manifest before publishing

## Plugins

| File | Version | Role | Deployment |
|---|---|---|---|
| `plugins/spacebunny.lua` | 1.8.5 | Download interceptor: depots, decryption keys, manifest request codes | Required by ASSella; **x86-era, do not use on the x64 Steam client** |
| `plugins/styx.lua` | 2.4 | Ownership-ticket splicer for SteamStub apps | Required by ASSella; x86/legacy until proven on x64 |
| `plugins/lobster.lua` | 1.2.2 | Restores `AdditionalDepots` / `DecryptionKeys` after an SLSsteam config reset | Required by ASSella; config-only, likely architecture-neutral |
| `plugins/lettuce.lua` | 0.4 | Proxy / ISP-block transport for MRC and Hubcap requests (formerly `bypass.lua`) | Optional, on by default; architecture-neutral |
| `plugins/pineapple.lua` | 1.0 | Pre-seeds Hubcap manifests so updates survive dead code providers (formerly `bakeneko.lua`) | Upstream marks it `deployable: false` — unfinished, included for reference only |

The upstream manifest also lists retired plugins (`hubcap.lua`, `bypass.lua`, `spacebunny1.5.lua`, `spliced-tickets.lua`, `katamari.lua`, `bakeneko.lua`, `download.lua`). Those are not copied here.

## How this differs from paws' own plugins

The root [`manifest.json`](../../manifest.json) is for paws' `download.lua` only. It is not changed by this folder. These ASSella files are not auto-installed by `paws plugins download`; they are here for people who want the upstream set and for provenance.

`spacebunny.lua` does the same core job as paws' `download.lua`, but it is written for the 32-bit cdecl client (`ffi.load("tier0_s")`, 32-bit `CUtlVector`, `E8 ... 83 C4` stack-cleanup patterns). Those patterns do not exist in the current `steamrt64/steamclient.so`. The verified x64 plugin stays in [`plugins/download-steam64.lua`](../../plugins/download-steam64.lua).

## Ideas worth borrowing, without copying code

ASSella is GPL-3.0. paws is source-available under its own all-rights-reserved license, so GPL source must not be pasted into paws. These are behaviour ideas to reimplement independently and credit as inspiration:

- **SpaceBunny:** multiple MRC providers with per-provider circuit breakers, backoff and a compact failure summary; optional proxy fallback through a transport plugin.
- **Lettuce:** one-shot proxy retry for blocked upstream hosts, leaving direct requests untouched when they work.
- **Lobster:** detect a config rewrite that stripped depot/key sections and restore them from the last known good copy.
- **Pineapple:** pre-seed depot manifests so a dead MRC provider does not stop an update.
- **Versioning convention:** numbered changelog in the header, `VERSION` global, and the version in the load notification.

## License

The files in `plugins/`, `plugins_manifest.json` and the upstream text in `LICENSE` are GPL-3.0, copyright niwia / ASSella contributors. Mirror them with attribution and the license text intact. paws' own x86/x64 `download.lua` files remain MIT (see [`plugins/LICENSE`](../../plugins/LICENSE)).
