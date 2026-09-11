# Publishing a release

The GitHub Actions workflow tests and packages the arm64 app on `macos-15`. A version tag publishes the verified ZIP and SHA-256 checksum as a GitHub release. No signing secrets are required for the current ad-hoc signed, unnotarized build.

1. Update `CFBundleShortVersionString` in `Resources/Info.plist` and increment `CFBundleVersion`.
2. Add release notes at `docs/releases/v<VERSION>.md`. Describe changes, requirements, and any installation limitations.
3. Run `env -u LIBRARY_PATH swift test` and `./scripts/package-release.sh` on an Apple silicon Mac. The packaging script verifies the bundle both before and after archiving.
4. Commit and push the changes to `main`. Check that the **Build and release** workflow passes.
5. Tag that commit and push the tag, substituting the actual version:

   ```sh
   git tag -a v1.0.0 -m "Release v1.0.0"
   git push origin v1.0.0
   ```

6. Check the tag's workflow run and the resulting [GitHub release](https://github.com/emielvangoor/CopyToTranslate/releases). The tag must match the version in Info.plist and have a release-notes file or the workflow fails before publishing.

Version tags identify immutable releases. Publish a new version to replace a released binary. There is no built-in app updater; users download and replace the app manually.

For a release without macOS's unidentified-developer prompt, the packaging process would need Developer ID signing and Apple notarization. The current workflow does not claim or attempt either.
