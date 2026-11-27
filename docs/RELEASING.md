# Releasing

## Publish a version

1. Merge to `main` with the version already set in `game/project.godot`, `game/export_presets.cfg`, `game/scripts/main.gd`, `tools/export_mac.py` and `tools/test_release.py`.
2. Push a tag such as `v1.5.0`.
3. The **Mac build** workflow exports the Universal app, zips it and creates a GitHub Release with the ZIP attached.

Every push also runs the **Tests** workflow: the seven functional suites, the collision replays, and a Forward+ render smoke test on a software Vulkan driver.

## Notarization (optional, not yet exercised)

Without these secrets the app is ad-hoc signed, and players must approve it under System Settings → Privacy & Security the first time. With them, the Mac build signs with your Developer ID, notarizes with Apple and staples the ticket. This path has never run; expect to adjust it on first use.

Add these repository secrets under Settings → Secrets and variables → Actions:

| Secret | Value |
| --- | --- |
| `MACOS_CERT_P12` | Base64 of your exported **Developer ID Application** certificate and key (`base64 -i cert.p12`) |
| `MACOS_CERT_PASSWORD` | The password you set when exporting the `.p12` |
| `MACOS_SIGN_IDENTITY` | The identity name, for example `Developer ID Application: Your Name (TEAMID)` |
| `APPLE_ID` | The Apple ID email of the developer account |
| `APPLE_TEAM_ID` | The ten-character team ID |
| `APPLE_APP_PASSWORD` | An app-specific password created at account.apple.com |

## Before tagging

- Play at least one cup on a physical Mac.
- Run `python3 tools/test_release.py` against the exported app for the native Metal cases and captures.
- Choose and add a `LICENSE` file; the repository currently has none.
