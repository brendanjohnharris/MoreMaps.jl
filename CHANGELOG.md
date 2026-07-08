# Changelog

## [0.5.0] - 2026-07-09

### Added
- `Asyncmap` backend (`Base.asyncmap`): single-process concurrency for IO-bound work.
- `OhMyThreaded` backend (extension, weakdep OhMyThreads): `tforeach` with chunked, load-balanced scheduling; keyword options forwarded to `tforeach`.
- `Polyestered` backend (extension, weakdep Polyester): `@batch` threading with very low per-iteration overhead; supports only `NoProgress`/`Monitor` (Polyester tasks must not yield, and channel-backed loggers yield on `put!`).
- `Monitor`: a progress-slot component that cheaply records each job's wall time, driver-side allocation bytes/count, GC time, element count, and backend; zero per-element cost. Compose with loggers via `CompositeLogger`.
- README table of backends and when each is useful, based on the unified benchmark.

### Changed
- `benchmark/backend_benchmark.jl` reworked into a unified sweep (per-element overhead, CPU-bound and IO-bound grids across all seven backends).

## [0.4.0] - 2026-07-08

### Breaking
- `Daggermap` now stores options as a `NamedTuple` (was `Base.Pairs`) and gains a `batchsize` field; the positional constructor signature changed. Keyword construction (`Daggermap(; single = 1)`) is unchanged.

### Added
- `CallbackLogger`: calls a user function per completed element with `(; i, done, total, y, elapsed)`, always on the driver process.
- `CompositeLogger`: forwards progress events to multiple child loggers.
- `Daggermap` batching: elements are grouped into `batchsize` chunks (default auto: four batches per process), one Dagger task per chunk, amortizing scheduler overhead.
- `Daggermap` options are passed via `Dagger.Options` (the documented function-form API) instead of splatting into `Dagger.@spawn`, and are now covered by tests.

### Changed
- Channel-holding loggers now share a `ChannelProgress` abstract type with common channel setup, consumer shutdown, and `Serialization.serialize` (removes four copies of the same plumbing).
- `QualityLogger` and `TermLogger` progress channels are bounded (were sized to the full input length).

### Fixed
- `ProgressLogger` with `nlogs = 0` no longer throws `DivideError`.
- `ProgressLogger` now stores its consumer task, so `close_log!` waits for pending progress events (fixes a shutdown race).

### Maintenance
- Removed dead `src/Threaded.jl` (the real backend lives in `src/backends/Threaded.jl`).
- Moved `test/backend_benchmark.jl` to `benchmark/` with its own `Project.toml` (it needs CairoMakie, which the test suite does not declare).

## [0.3.0] - 2026-05-10

### Added
- `QualityLogger` backend: a four-color, terminal-rendered progress logger that reports per-iteration completion state in addition to overall progress.
- `Tuple` and `NamedTuple` support in `map` calls, with improved type stability for tuple inputs.
- Ability to pass `Progress` or `Backend` types (not just instances) directly to mapping calls, so callers can opt in to a backend without constructing it by hand.
- `LogLogger` now accepts `nlogs = 0` to suppress per-iteration log output.
- README visualizations (animated GIFs) demonstrating each progress backend.
- Monthly scheduled run added to the CI workflow.
- Breaking: logging internals were generalized so progress backends share a common execution path.

### Changed
- Generalized the logging machinery so progress backends share a common path through the extensions.
- `QualityLogger` reworked for vector inputs and made more robust on irregular iteration counts.
- Loggers in general made more robust around channel sizing and edge cases.

### Fixed
- `DimensionalData` mapping: corrected behaviour when mapping over `Dim{}` arguments (a small test was added clarifying that `Iterators.product` is required for this case).
- Channel-length bug in the progress channel used by `LogLogger`.
- Compat fixes for `DimensionalData` and related extensions.
- Multiple test-suite fixes for backend and logger edge cases.

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

[Unreleased]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.5.0...HEAD
[0.5.0]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.2.1...v0.3.0
[0.2.1]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.2.0...v0.2.1
[0.2.0]: https://github.com/brendanjohnharris/MoreMaps.jl/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/brendanjohnharris/MoreMaps.jl/releases/tag/v0.1.0
