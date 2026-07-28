# CI Build Learnings

## Windows: CMAKE_GENERATOR + CMAKE_GENERATOR_INSTANCE

**Problem:** GitHub Actions `windows-latest` runners (mid-2026) ship VS 2026 but not VS 2019.
Flutter 3.27 hardcodes `-G "Visual Studio 16 2019"` as the CMake generator.
Setting only `CMAKE_GENERATOR_INSTANCE` fails with:
> "Warning: Environment variable CMAKE_GENERATOR_INSTANCE will be ignored, because CMAKE_GENERATOR is not set."

**Root cause:** CMake checks for the *environment variable* `CMAKE_GENERATOR` (not the `-G` flag) before deciding to honor `CMAKE_GENERATOR_INSTANCE`.

**Fix:** Set both env vars before `flutter build windows --release`:
```powershell
$env:CMAKE_GENERATOR = "Visual Studio 16 2019"
$env:CMAKE_GENERATOR_INSTANCE = $vsPath
```

This tells CMake: "Use the VS 2019 generator, but point it at the VS 2026 installation path." The VS 2026 toolchain is backward-compatible enough to build with the VS 2019 generator.
