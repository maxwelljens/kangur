# gdUnit4 pin (Kangur)

- Upstream: https://github.com/MikeSchulze/gdUnit4
- Version (plugin.cfg): **7.0.0**
- Branch: `master` (no git tag exists for 7.0.0 — tags stop at v6.2.3)
- Commit: **8988c2ab1a24c2d5153e6caddbae00766105ba54** (committed 2026-11-14T10:26:22Z)
- Source: `https://codeload.github.com/MikeSchulze/gdUnit4/tar.gz/refs/heads/master`,
  only `addons/gdUnit4/` vendored (rest of the tarball discarded).
- Why 7.0.0 and not 6.2.3: 6.2.3 aborts in `--headless` without `--ignoreHeadlessMode`;
  7.0.0 runs headless plain. See docs/research/godot-tech.md §5.
- `godot --headless --path . --import` is mandatory before the first gdUnit4 run
  (7.0.0 segfaults on a cold cache).