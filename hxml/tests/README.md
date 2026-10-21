# Haxe Test Descriptors

These HXML files are test entrypoints for the World of Cake Haxe code.

Run them from the repository root, for example:

```bash
haxe hxml/tests/test-kdiagram-headless.hxml
haxe hxml/tests/test-kdiagram-native.hxml
```

The paths inside the HXML files intentionally remain relative to the repository root (`Source`, `build/...`). Haxe accepts forward slashes on Windows and Linux, so the same descriptor paths work from PowerShell, CMD, and Bash when invoked from the repo root.

The `derivatives/openfl/project-*.xml` files are OpenFL/Lime application descriptors, not headless test descriptors. They live under `derivatives/openfl/` with `Assets/` and `Export/` co-located there, and use a `../../Source`-relative path back to the shared repo-root `Source` tree.
