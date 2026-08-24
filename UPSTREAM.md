# Upstream provenance

FluxIDC is a modified distribution of [Lingyan000/fluxdo](https://github.com/Lingyan000/fluxdo).

## Imported baseline

- FluxDO commit: `98bcf5513bb064fa4bfb00b60cd6d9d687db8efa`
- FluxDO release line: `v0.2.27`
- `core/doh_proxy`: `08d3468f0a1eb2858840c525d61f8aa888696522`
- `packages/fluxdo_render`: `e36d0a4129ffea39e236d7deba366ca975459ffd`

The upstream remote and merge history are retained. The two upstream source trees remain Git submodules, so source checkouts must initialize submodules before bootstrapping the Flutter workspace.

## FluxIDC changes

- Replaced the site endpoint, trusted domains and deep-link handling with IDC Flare values.
- Replaced visible application branding and platform icons with IDC Flare assets.
- Retained the established `com.fdcflare.client` package ID and `idcflare` URL scheme for upgrade compatibility, while user-visible branding and release artifacts use FluxIDC.
- Disabled Linux.DO-only Credit, CDK, Connect and metaverse integrations.
- Uses FluxIDC's own GitHub Releases for application updates and keeps crash reporting disabled until an independent service is configured.

Internal package names, native method-channel identifiers and the `fluxdo_render` package name are intentionally retained where renaming would add compatibility risk without changing user-visible behavior.

## License

FluxDO is distributed under GNU GPL v3. FluxIDC keeps the same `LICENSE` and provides this provenance record so upstream authorship and the modified nature of this distribution remain clear.
