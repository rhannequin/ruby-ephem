# Changelog

## [0.5.0] - 2026-06-22

### Features

* Read binary PCK (`DAF/PCK`) orientation kernels via `Ephem::PCK`, exposing a
  body's Euler angles and rates over time (`angles_at`, `orientation_at`), the
  foundation for DE440-grade lunar libration ([#76])
* Add `Ephem::Core::Orientation` (Euler angles + optional rates) and
  `Ephem::Core::Rotation` (kernel-agnostic rotation-matrix helpers), plus
  `Orientation#to_matrix` / `OrientationSegment#matrix_at` for the built-in
  3-1-3 (Z-X-Z) reference→body convention
* Excerpt and the `excerpt` CLI now support binary PCK kernels, detecting the
  kernel kind automatically
* Download binary PCK lunar orientation kernels from NAIF via `Ephem::Download`

### Improvements

* Route queries to the covering segment when a body/pair spans multiple
  time-split segments (SPK and PCK), with no overhead for single-segment keys
* Share the type-2 Chebyshev machinery between SPK and PCK segments
* Fix `compute_and_differentiate` returning mismatched velocities for an array
  of times
* Correct the documented velocity unit to km/day (the actual, validated value)

[#76]: https://github.com/rhannequin/ruby-ephem/issues/76

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.4.1...v0.5.0

## [0.4.1] - 2025-08-03

### Improvements

* Exclude BSP files from release ([#42])

[#42]: https://github.com/rhannequin/ruby-ephem/pull/42

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.4.0...v0.4.1

## [0.4.0] - 2025-06-09

### Improvements

* Improve Chebyshev polynomial performance ([#33])
* Improve download file management ([#34])
* Validate against all kernels and date ranges ([#36])
* Add supported Ruby versions ([#35])
* Bump rspec from 3.13.0 to 3.13.1 by @dependabot ([#38])
* Bump rake from 13.2.1 to 13.3.0 by @dependabot ([#39])
* Bump csv from 3.3.4 to 3.3.5 by @dependabot ([#40])

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

* Write downloaded ephemeris in binary mode by @trevorturk ([#31])

### Improvements

* Bump standard from 1.49.0 to 1.50.0 by @dependabot ([#29])

### New Contributors

* @trevorturk made their first contribution in [#31]

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.3.0...v0.3.1

[#29]: https://github.com/rhannequin/ruby-ephem/pull/29
[#31]: https://github.com/rhannequin/ruby-ephem/pull/31

## [0.3.0] - 2025-04-30

## Features

* Improve find_interval with binary search ([#24])
* Use alias methods to get segment position or state ([#27])

## Improvements

* Bump irb from 1.15.1 to 1.15.2 by @dependabot ([#21])
* Bump standard from 1.47.0 to 1.49.0 by @dependabot ([#23])
* Bump csv from 3.3.3 to 3.3.4 by @dependabot ([#25])
* Bump parallel from 1.26.3 to 1.27.0 by @dependabot ([#26])

**Full Changelog**: https://github.com/rhannequin/ruby-ephem/compare/v0.2.0...v0.3.0

[#21]: https://github.com/rhannequin/ruby-ephem/pull/21
[#23]: https://github.com/rhannequin/ruby-ephem/pull/23
[#24]: https://github.com/rhannequin/ruby-ephem/pull/24
[#25]: https://github.com/rhannequin/ruby-ephem/pull/25
[#26]: https://github.com/rhannequin/ruby-ephem/pull/26
[#27]: https://github.com/rhannequin/ruby-ephem/pull/27

## [0.2.0] - 2025-03-28

### Features

* Simplify download ([#12])
* SPK excerpt generator ([#13])
* Improve documentation on excerpts ([#16])
* IMCCE INPOP support ([#20])

### Improvements

* Add Dependabot ([#6])
* Replace testing kernel ([#17])
* Add `irb` to dev dependencies ([#14])
* Add support for Rubies `3.2.7` and `3.4.2` ([#15])
* Bump csv from 3.3.0 to 3.3.2 by @dependabot ([#7])
* Bump standard from 1.43.0 to 1.44.0 by @dependabot ([#8])
* Bump standard from 1.44.0 to 1.45.0 by @dependabot ([#9])
* Bump csv from 3.3.2 to 3.3.3 by @dependabot ([#11])
* Bump standard from 1.45.0 to 1.47.0 by @dependabot ([#10])
* Bump json from 2.10.1 to 2.10.2 by @dependabot ([#18])

### New Contributors

* @dependabot made their first contribution in [#7]

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
