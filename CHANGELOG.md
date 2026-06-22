# Changelog

## [0.5.0] - 2026-06-23

### Features

- Read binary PCK (`DAF/PCK`) orientation kernels via `Ephem::PCK`, exposing a
  body's Euler angles and rates over time (`angles_at`, `orientation_at`), the
  foundation for DE440-grade lunar libration ([#76], [#80])
- Add `Ephem::Core::Orientation` (Euler angles + optional rates) and
  `Ephem::Core::Rotation` (kernel-agnostic rotation-matrix helpers), plus
  `Orientation#to_matrix` / `OrientationSegment#matrix_at` for the built-in
  3-1-3 (Z-X-Z) reference→body convention
- Excerpt and the `excerpt` CLI now support binary PCK kernels, detecting the
  kernel kind automatically
- Download binary PCK lunar orientation kernels from NAIF via `Ephem::Download`
- Add `#inspect` and `#to_s` to `State` for easier debugging ([#67])

### Improvements

- Route queries to the covering segment when a body/pair spans multiple
  time-split segments (SPK and PCK), with no overhead for single-segment keys
- Share the type-2 Chebyshev machinery between SPK and PCK segments
- Evaluate position and velocity in a single Chebyshev pass
  (`ChebyshevPolynomial.evaluate_with_derivative`), speeding up every state /
  orientation query (`compute_and_differentiate`, `state_at`, `orientation_at`)
  with bit-for-bit identical results
- Correct the documented velocity unit to km/day (the actual, validated value)
- Remove the `numo-narray` dependency ([#65])
- Skip derivative evaluation in `Segment#compute` ([#57])
- Hoist loop-invariant `t2` computation in Chebyshev evaluation ([#58])
- Cache the `RecordParser` instance in `SummaryManager` ([#63])
- Eliminate a redundant `read_record` call in `SummaryManager` ([#62])
- Replace duplicated endianness format lookups with shared constants ([#64])
- Replace `instance_variable_get` with proper `attr_reader`s in `Excerpt`
  ([#66])
- Use separate error margins for position and velocity validation ([#61])
- Add a comprehensive benchmark suite ([#68])
- Upgrade default Ruby to 4.0.5 ([#81])
- Match SPICE last-loaded-wins precedence for overlapping segments ([#83])
- Add a dedicated spec for the shared type-2 Chebyshev evaluation ([#84])
- Bump standard from 1.50.0 to 1.55.0 by @dependabot ([#45], [#46], [#56],
  [#78])
- Bump actions/checkout from 4 to 7 by @dependabot ([#44], [#52], [#79])
- Bump rake from 13.3.0 to 13.4.2 by @dependabot ([#48], [#73])
- Bump zlib from 3.2.1 to 3.2.3 by @dependabot ([#49], [#70])
- Bump rspec from 3.13.1 to 3.13.2 by @dependabot ([#47])
- Bump parallel from 1.27.0 to 1.28.0 by @dependabot ([#71])
- Bump benchmark-ips from 2.14.0 to 2.15.1 by @dependabot ([#75])
- Bump json from 2.18.1 to 2.19.2 by @dependabot ([#77])

### Bug fixes

- Fix `compute_and_differentiate` returning mismatched velocities for an array
  of times
- Fix precision loss in `time_to_seconds` for dates far from J2000 ([#60])

[#44]: https://github.com/rhannequin/ruby-ephem/pull/44
[#45]: https://github.com/rhannequin/ruby-ephem/pull/45
[#46]: https://github.com/rhannequin/ruby-ephem/pull/46
[#47]: https://github.com/rhannequin/ruby-ephem/pull/47
[#48]: https://github.com/rhannequin/ruby-ephem/pull/48
[#49]: https://github.com/rhannequin/ruby-ephem/pull/49
[#52]: https://github.com/rhannequin/ruby-ephem/pull/52
[#56]: https://github.com/rhannequin/ruby-ephem/pull/56
[#57]: https://github.com/rhannequin/ruby-ephem/pull/57
[#58]: https://github.com/rhannequin/ruby-ephem/pull/58
[#60]: https://github.com/rhannequin/ruby-ephem/pull/60
[#61]: https://github.com/rhannequin/ruby-ephem/pull/61
[#62]: https://github.com/rhannequin/ruby-ephem/pull/62
[#63]: https://github.com/rhannequin/ruby-ephem/pull/63
[#64]: https://github.com/rhannequin/ruby-ephem/pull/64
[#65]: https://github.com/rhannequin/ruby-ephem/pull/65
[#66]: https://github.com/rhannequin/ruby-ephem/pull/66
[#67]: https://github.com/rhannequin/ruby-ephem/pull/67
[#68]: https://github.com/rhannequin/ruby-ephem/pull/68
[#70]: https://github.com/rhannequin/ruby-ephem/pull/70
[#71]: https://github.com/rhannequin/ruby-ephem/pull/71
[#73]: https://github.com/rhannequin/ruby-ephem/pull/73
[#75]: https://github.com/rhannequin/ruby-ephem/pull/75
[#76]: https://github.com/rhannequin/ruby-ephem/issues/76
[#77]: https://github.com/rhannequin/ruby-ephem/pull/77
[#78]: https://github.com/rhannequin/ruby-ephem/pull/78
[#79]: https://github.com/rhannequin/ruby-ephem/pull/79
[#80]: https://github.com/rhannequin/ruby-ephem/pull/80
[#81]: https://github.com/rhannequin/ruby-ephem/pull/81
[#83]: https://github.com/rhannequin/ruby-ephem/pull/83
[#84]: https://github.com/rhannequin/ruby-ephem/pull/84

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.4.1...v0.5.0

## [0.4.1] - 2025-08-03

### Improvements

- Exclude BSP files from release ([#42])

[#42]: https://github.com/rhannequin/ruby-ephem/pull/42

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.4.0...v0.4.1

## [0.4.0] - 2025-06-09

### Improvements

- Improve Chebyshev polynomial performance ([#33])
- Improve download file management ([#34])
- Validate against all kernels and date ranges ([#36])
- Add supported Ruby versions ([#35])
- Bump rspec from 3.13.0 to 3.13.1 by @dependabot ([#38])
- Bump rake from 13.2.1 to 13.3.0 by @dependabot ([#39])
- Bump csv from 3.3.4 to 3.3.5 by @dependabot ([#40])

[#33]: https://github.com/rhannequin/ruby-ephem/pull/33
[#34]: https://github.com/rhannequin/ruby-ephem/pull/34
[#35]: https://github.com/rhannequin/ruby-ephem/pull/35
[#36]: https://github.com/rhannequin/ruby-ephem/pull/36
[#38]: https://github.com/rhannequin/ruby-ephem/pull/38
[#39]: https://github.com/rhannequin/ruby-ephem/pull/39
[#40]: https://github.com/rhannequin/ruby-ephem/pull/40

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.3.1...v0.4.0

## [0.3.1] - 2025-05-16

### Bug fixes

- Write downloaded ephemeris in binary mode by @trevorturk ([#31])

### Improvements

- Bump standard from 1.49.0 to 1.50.0 by @dependabot ([#29])

### New Contributors

- @trevorturk made their first contribution in [#31]

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.3.0...v0.3.1

[#29]: https://github.com/rhannequin/ruby-ephem/pull/29
[#31]: https://github.com/rhannequin/ruby-ephem/pull/31

## [0.3.0] - 2025-04-30

## Features

- Improve find_interval with binary search ([#24])
- Use alias methods to get segment position or state ([#27])

## Improvements

- Bump irb from 1.15.1 to 1.15.2 by @dependabot ([#21])
- Bump standard from 1.47.0 to 1.49.0 by @dependabot ([#23])
- Bump csv from 3.3.3 to 3.3.4 by @dependabot ([#25])
- Bump parallel from 1.26.3 to 1.27.0 by @dependabot ([#26])

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.2.0...v0.3.0

[#21]: https://github.com/rhannequin/ruby-ephem/pull/21
[#23]: https://github.com/rhannequin/ruby-ephem/pull/23
[#24]: https://github.com/rhannequin/ruby-ephem/pull/24
[#25]: https://github.com/rhannequin/ruby-ephem/pull/25
[#26]: https://github.com/rhannequin/ruby-ephem/pull/26
[#27]: https://github.com/rhannequin/ruby-ephem/pull/27

## [0.2.0] - 2025-03-28

### Features

- Simplify download ([#12])
- SPK excerpt generator ([#13])
- Improve documentation on excerpts ([#16])
- IMCCE INPOP support ([#20])

### Improvements

- Add Dependabot ([#6])
- Replace testing kernel ([#17])
- Add `irb` to dev dependencies ([#14])
- Add support for Rubies `3.2.7` and `3.4.2` ([#15])
- Bump csv from 3.3.0 to 3.3.2 by @dependabot ([#7])
- Bump standard from 1.43.0 to 1.44.0 by @dependabot ([#8])
- Bump standard from 1.44.0 to 1.45.0 by @dependabot ([#9])
- Bump csv from 3.3.2 to 3.3.3 by @dependabot ([#11])
- Bump standard from 1.45.0 to 1.47.0 by @dependabot ([#10])
- Bump json from 2.10.1 to 2.10.2 by @dependabot ([#18])

### New Contributors

- @dependabot made their first contribution in [#7]

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.1.0...v0.2.0

[#6]: https://github.com/rhannequin/ruby-ephem/pull/6
[#7]: https://github.com/rhannequin/ruby-ephem/pull/7
[#8]: https://github.com/rhannequin/ruby-ephem/pull/8
[#9]: https://github.com/rhannequin/ruby-ephem/pull/9
[#10]: https://github.com/rhannequin/ruby-ephem/pull/10
[#11]: https://github.com/rhannequin/ruby-ephem/pull/11
[#12]: https://github.com/rhannequin/ruby-ephem/pull/12
[#13]: https://github.com/rhannequin/ruby-ephem/pull/13
[#14]: https://github.com/rhannequin/ruby-ephem/pull/14
[#15]: https://github.com/rhannequin/ruby-ephem/pull/15
[#16]: https://github.com/rhannequin/ruby-ephem/pull/16
[#17]: https://github.com/rhannequin/ruby-ephem/pull/17
[#18]: https://github.com/rhannequin/ruby-ephem/pull/18
[#20]: https://github.com/rhannequin/ruby-ephem/pull/20

## [0.1.0] - 2025-01-01

- Initial release
