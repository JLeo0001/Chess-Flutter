# CI Build Learnings

## Windows: Flutter 3.27 CMake generator rewrite

**Problem:** GitHub Actions `windows-latest` runners may ship only a newer Visual Studio installation, while Flutter 3.27 hardcodes `-G "Visual Studio 16 2019"` for Windows desktop builds.

Setting only `CMAKE_GENERATOR_INSTANCE` fails with:
> "Warning: Environment variable CMAKE_GENERATOR_INSTANCE will be ignored, because CMAKE_GENERATOR is not set."

Renaming `cmake.exe` and replacing Flutter's generator with a fixed `Visual Studio 17 2022` is brittle if `windows-latest` moves ahead to a runner image whose Visual Studio/CMake combination is not supported by Flutter 3.27.

**Fix:** Pin the Windows job to `windows-2022`, where Visual Studio 2022 is available, then detect the installed Visual Studio product major from `vswhere -property installationVersion` (17.x for VS 2022), map it to the matching CMake generator, set both CMake environment variables, and use a `cmake.bat` wrapper to rewrite Flutter's hardcoded `Visual Studio 16 2019` argument. Do **not** parse the installation path folder, because VS 2022 installs under a `2022` year folder, not a `17` major-version folder:

```powershell
$vsPath = & $vswhere -latest -property installationPath
$vsVersion = & $vswhere -latest -property installationVersion
$vsMajor = [int]($vsVersion.Split('.')[0])
switch ($vsMajor) {
  18 { $cmakeGenerator = "Visual Studio 18 2026" }
  17 { $cmakeGenerator = "Visual Studio 17 2022" }
  16 { $cmakeGenerator = "Visual Studio 16 2019" }
  default { throw "Unsupported Visual Studio version: $vsVersion ($vsPath)" }
}
$env:CMAKE_GENERATOR = $cmakeGenerator
$env:CMAKE_GENERATOR_INSTANCE = $vsPath
```

The workflow also prints `cmake --help` Visual Studio generator lines before wrapping, so future CI logs show exactly which generators the runner CMake supports.

## Windows: Flutter desktop artifact path

Flutter 3.27 Windows release output is under:

```text
build/windows/x64/runner/Release
```

not the older/simplified path:

```text
build/windows/runner/Release
```

The workflow should package `build/windows/x64/runner/Release/*`, with a fallback to the older path and diagnostics that list discovered `Release` directories if neither exists.
