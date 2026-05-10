# Changelog

## [Unreleased] - 0.3.0

### Added
- `QualityLogger` backend: a four-color, terminal-rendered progress logger that reports per-iteration completion state in addition to overall progress.
- Rudimentary `Tuple` and `NamedTuple` support in `map` calls, with improved type stability for tuple inputs.
- Ability to pass `Progress` or `Backend` *types* (not just instances) directly to mapping calls, so callers can opt in to a backend without constructing it by hand.
- `LogLogger` now accepts `nlogs = 0` to suppress per-iteration log output.
- README visualizations (animated GIFs) demonstrating each progress backend.
- Monthly scheduled run added to the CI workflow.

### Changed
- Generalized the log-logging machinery so progress backends share a common path through the extensions.
- `QualityLogger` reworked for vector inputs and made more robust on irregular iteration counts.
- Loggers in general made more robust around channel sizing and edge cases.

### Fixed
- `DimensionalData` mapping: corrected behaviour when mapping over `Dim{}` arguments (a small test was added clarifying that `Iterators.product` is required for this case).
- Channel-length bug in the progress channel used by `LogLogger`.
- Compat fixes for `DimensionalData` and related extensions.
- Various test-suite fixes for the new logger backends.

### CI / Maintenance
- Bumped `actions/checkout` from 4 to 6 (#5).
- Tightened CI workflow configuration.
- Bumped project compat bounds.

## [0.2.1] - 2025-09-11

### Added
- Tests covering the `Distributed` and `Dagger` backends.

### Changed
- Switched to the newer `ProgressLogging` API.

### Fixed
- Docstring fix so `Documenter` builds cleanly.

## [0.2.0] - 2025-09-04

### Added
- Optional `level` argument for `LogLogger`, allowing callers to choose the log level used for progress messages.
- Docstrings across the public API, the backends (`Sequential`, `Threaded`, `Pmap`), and the `Dagger`, `ProgressLogging`, and `Term` extensions.

### Changed
- Renamed `InfoProgress` to `LogLogger` to better reflect that it is a generic logging backend rather than an info-only progress reporter.
- Removed the catch-all `All` export from `MoreMaps`.
- Tweaks and polish to the `Dagger` extension.

### Fixed
- Method-resolution fix in `LogLogger`.
- Doctest fixes across the extensions and backends.

## [0.1.0] - 2025-08-30

First tagged release.

### Added
- Package renamed from `Cartographer` to `MoreMaps`; this is the first release under the new name.
- Core mapping API with pluggable execution backends:
  - `Sequential`
  - `Threaded` (with a scheduler fix for Julia 1.10)
  - `Pmap` (Distributed)
  - `Daggermap` (via the `Dagger` weak-dep extension)
- `InfoProgress` progress backend, plus `ProgressLogging` and `Term` extensions for richer progress display.
- `DimensionalData` extension for mapping over dimensional arrays.
- `Expansion` utilities and `Leaves` handling.
- Initial test suite, including backend benchmarks and ambiguity checks.
- README with usage examples.

### Notes
- Generated from `PkgTemplates`.

[Unreleased]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.2.1...HEAD
[0.2.1]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/brendanjohnharris/MoreMaps.jl/releases/tag/v0.1.0
