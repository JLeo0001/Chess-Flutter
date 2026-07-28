# CI Build Learnings

## Windows: Flutter 3.27 CMake generator rewrite

**Problem:** GitHub Actions `windows-latest` runners may ship only a newer Visual Studio installation, while Flutter 3.27 hardcodes `-G "Visual Studio 16 2019"` for Windows desktop builds.

Setting only `CMAKE_GENERATOR_INSTANCE` fails with:
> "Warning: Environment variable CMAKE_GENERATOR_INSTANCE will be ignored, because CMAKE_GENERATOR is not set."

Renaming `cmake.exe` and replacing Flutter's generator with a fixed `Visual Studio 17 2022` is also brittle when the runner only has VS 2026.

**Fix:** Detect the installed Visual Studio major version from the `vswhere` installation path, map it to the matching CMake generator, set both CMake environment variables, and use a `cmake.bat` wrapper to rewrite Flutter's hardcoded `Visual Studio 16 2019` argument:

```powershell
$vsMajor = [int](Split-Path (Split-Path $vsPath -Parent) -Leaf)
switch ($vsMajor) {
  18 { $cmakeGenerator = "Visual Studio 18 2026" }
  17 { $cmakeGenerator = "Visual Studio 17 2022" }
  16 { $cmakeGenerator = "Visual Studio 16 2019" }
  default { throw "Unsupported Visual Studio major version: $vsMajor ($vsPath)" }
}
$env:CMAKE_GENERATOR = $cmakeGenerator
$env:CMAKE_GENERATOR_INSTANCE = $vsPath
```

The workflow also prints `cmake --help` Visual Studio generator lines before wrapping, so future CI logs show exactly which generators the runner CMake supports.
