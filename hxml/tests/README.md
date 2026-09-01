# Haxe Test Descriptors

These HXML files are test entrypoints for the World of Cake Haxe code.

Run them from the repository root, for example:

```bash
haxe hxml/tests/test-kdiagram-headless.hxml
haxe hxml/tests/test-kdiagram-native.hxml
```

The paths inside the HXML files intentionally remain relative to the repository root (`Source`, `build/...`). Haxe accepts forward slashes on Windows and Linux, so the same descriptor paths work from PowerShell, CMD, and Bash when invoked from the repo root.

The root `project-*.xml` files are OpenFL/Lime application descriptors, not headless test descriptors. They remain at the root for now because moving them would require checking OpenFL's XML path resolution for `Source`, `Assets`, and `Export` separately.
