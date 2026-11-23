# paws-plugins

Version-pinned SLSsteam Lua plugins for [paws](https://github.com/one-eyed-queen/paws).

paws uses [`manifest.json`](manifest.json) to pick one download interceptor by Steam architecture, Steam client build and SLSsteam version. It verifies SHA-256 before installing it as `~/.config/SLSsteam/plugins/download.lua`. The bundled x86 copy inside paws is only the offline fallback.

## Layout

- `x64/` — plugins for the 64-bit `steamrt64` client.
- `x86/` — plugins for the 32-bit `ubuntu12_32` client.

Filenames and internal identifiers are deliberately opaque. Each arch folder contains:

| x64 file | x86 file | Role | Auto-installed by paws? |
|---|---|---|---|
| `rize.lua` | `kaneki.lua` | Download interceptor: depots, decryption keys, MRC resolution | Yes, via the manifest |
| `touka.lua` | `ayato.lua` | Ownership-ticket splicing for apps whose own ticket request fails | No, optional |
| `eto.lua` | `yoshimura.lua` | Looks up missing depot keys in Sudama's key list | No, optional |
| `hinami.lua` | `nishiki.lua` | Saves/restores-warning for `AdditionalDepots` and `DecryptionKeys` | No, optional |
| `arima.lua` | `suzuya.lua` | Startup/config health check for the download setup | No, optional |

Optional plugins share the `Kaneki` global namespace and only mark their presence there; they do not hook each other.

## Download interceptor

SpaceBunny was removed from this collection. Its useful behaviour now lives in our own downloaders as a clean-room implementation:

- MRC validation rejects HTML, short numbers, zeroes and echoed manifest IDs; `strtoull` preserves 18–20 digit codes.
- Success cache, per-manifest failure backoff and per-provider cooldown.
- Two MRC endpoints: the primary `wudrm` HTTPS host and a proxy-style fallback worker.
- Guarded hooks unlock the mutex even when a hook errors.
- Depot writes validate the package pointer, limit counts, dedupe IDs, preserve vector fields and refuse empty writes.

## Checks done before publishing

- Every Lua file passes `luajit -bl`.
- The x64 patterns were checked against `steamrt64/steamclient.so` build `1792618285`.
- The x86 patterns were checked against `ubuntu12_32/steamclient.so`.
- The MRC helper logic was exercised with a standalone LuaJIT harness.
- The Sudama depot-key endpoint and the MRC fallback worker were reached with CLI probes.
- The ticket-splice RTTI names `14IClientUserMap` and `GetAppOwnershipTicketExtendedData` exist in both x64 and x86 clients; the hook has not been launched in Steam here.

Steam was not launched. The previously working x64 plugin was left in place locally; update the live `download.lua` only when you are ready to test Steam again.

## Credits

- **ciscosweater** — original 32-bit `download.lua`, MIT (see [`LICENSE`](LICENSE)).
- **niwia and the ASSella contributors** — SpaceBunny's MRC robustness design inspired the clean-room improvements here. No ASSella Lua files remain in this repo.
- The x64 port and the optional paws plugins are maintained here for paws. External services used by plugins are not part of this repo.
