# LifeLogger Release Guide

## Prerequisites

- Xcode 16+ with macOS SDK
- Apple Developer Program membership
- Developer ID Application certificate
- Notarytool keychain profile

## Environment variables

| Variable | Description |
|----------|-------------|
| `DEVELOPMENT_TEAM` | Apple Team ID (e.g. `SPJSUD7XBZ`) |
| `NOTARY_PROFILE` | `notarytool store-credentials` profile name |

Create a notary profile:

```bash
xcrun notarytool store-credentials "lifelogger-notary" \
  --apple-id "you@example.com" \
  --team-id "$DEVELOPMENT_TEAM" \
  --password "@keychain:AC_PASSWORD"
```

## Build, sign, notarize, DMG

```bash
export DEVELOPMENT_TEAM=YOUR_TEAM_ID
export NOTARY_PROFILE=lifelogger-notary
chmod +x scripts/build_release.sh
./scripts/build_release.sh
```

Output: `build/LifeLogger.dmg`

## Sparkle appcast

1. Generate EdDSA keys: `./Sparkle/bin/generate_keys` (after adding Sparkle SPM)
2. Place public key in `Info.plist` → `SUPublicEDKey`
3. Host `appcast.xml` and set `SUFeedURL`
4. Sign updates with `sign_update` when publishing a new DMG/ZIP

## Verify locally (no signing)

```bash
xcodebuild -scheme LifeLogger -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO build
xcodebuild -scheme LifeLogger -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
```
