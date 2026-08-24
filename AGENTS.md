# Repository Instructions

## FluxDO Upstream Updates

When asked to update FluxIDC to follow a FluxDO release:

1. Fetch `upstream` and merge the latest stable `upstream/main` into `main`, preserving the IDC Flare site configuration, FluxIDC branding, package IDs, URL schemes, release repository, and disabled Linux.DO-only services.
2. Update `pubspec.yaml`, `README.md`, and `UPSTREAM.md`, then commit the merge as `chore: sync FluxDO vX.Y.Z` and push `main`.
3. Use the FluxIDC release tag format `vX.Y.Z-fluxidc.N`.
4. Create a draft GitHub Release targeting the exact merge commit.
5. Dispatch `.github/workflows/build-android.yaml` and `.github/workflows/build-ios.yaml` from that commit with the release tag as `release_tag`.
6. Treat GitHub Actions as the authoritative compile and package verification. Wait for both workflows, inspect failures, fix and rerun as needed, and verify the APK, IPA, and checksum assets before publishing the Release.

Do not install or bootstrap a local Flutter SDK for this release flow unless the user explicitly requests local builds. Local checks should be limited to repository structure, merge conflicts, formatting that is already available, and JSON/YAML validation.
