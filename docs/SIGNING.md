# Signing releases

QuitX release builds are signed **ad hoc** with a fixed designated requirement (`identifier "io.coreify.quitx"`), so macOS recognizes each new build as the same app and keeps the Accessibility grant. `Scripts/build.sh` fails the build if the requirement would fall back to a CDHash.

Signing every release with one stable certificate goes a step further: the in-app updater then refuses any update that wasn't signed with that same certificate. A self-signed certificate is enough; it doesn't need to come from Apple.

## Set it up once

1. On a Mac, run:
   ```sh
   ./Scripts/create-signing-cert.sh
   ```
   This creates `quitx-signing.p12` and prints three values.
2. In GitHub, open **Settings → Secrets and variables → Actions → New repository secret** and add:

   | Secret | Value |
   |---|---|
   | `MACOS_SIGNING_IDENTITY` | The certificate name, `QuitX Code Signing` by default |
   | `MACOS_SIGNING_CERT_PASSWORD` | The password the script printed |
   | `MACOS_SIGNING_CERT_P12` | The long base64 text the script printed |

3. Keep `quitx-signing.p12` private and backed up. It is git-ignored. If you lose it, users have to allow Accessibility once more when you switch to a new certificate.

The next release run imports the certificate into a temporary keychain and signs by its SHA-1 hash (a self-signed identity isn't trusted, so codesign can't find it by name). The **Check the Signature** step fails the release if the app still comes out ad-hoc signed.

The first certificate-signed release changes the designated requirement once, so macOS asks for Accessibility one more time after that update. After that, the grant stays across updates.

## How it interacts with in-app updates

- Every update must have a valid code signature, the right bundle identifier and the version named by the release tag.
- When the installed app is signed with your certificate, every update must also satisfy its designated requirement, so it must come from the same certificate. A tampered or foreign build is rejected.
- When the installed app is ad-hoc signed, the updater checks validity, the GitHub asset digest and the bundle identity, and trusts the HTTPS connection to this repository's releases.

## Releasing

1. Move the notes for the version into a `## X.Y.Z` section of `CHANGELOG.md`, written for users. The release notes and the update window use it.
2. Bump the version with `npm run bump` (updates `package.json` and `Support/Info.plist`) and commit.
3. Push a `vX.Y.Z` tag, or run **Actions → Release**.

## Legacy update key

`UPDATE_ED25519_PRIVATE_KEY` is only used to publish `updates.json` for QuitX 1.1.8 and earlier, which update through the old Cloudflare Worker. Current versions don't use any key. Keep the secret and the Worker for a transition period, then delete both.

## Notarization

Notarizing with an Apple Developer ID would remove the "right-click → Open" step on first launch. It isn't set up yet.
