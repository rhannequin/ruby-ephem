# Ephem

Ephem is a Ruby gem that provides a simple interface to the SPICE binary kernel
files such as:
* _JPL [Development Ephemeris]_ (DE)
* _IMCCE [Intégrateur numérique planétaire de l'Observatoire de Paris]_ (INPOP)

[Development Ephemeris]: https://ssd.jpl.nasa.gov/planets/eph_export.html
[Intégrateur numérique planétaire de l'Observatoire de Paris]: https://www.imcce.fr/inpop

These files are a collection of numerical integrations of the equations of
motion of the Solar System, used to calculate the positions of the planets,
the Moon, and other celestial bodies with high precision.

Ephem supports planetary ephemerides like DE421, DE430, INPOP19A, etc. (SPK),
as well as binary PCK orientation kernels such as the lunar orientation kernel
`moon_pa_de440_200625.bpc`.

The library is in high development mode and does not have a stable version yet.
The API is subject to major changes at the moment, please keep that in mind if
you consider adding this gem as a dependency.

## Installation

Install the gem and add to the application's Gemfile by executing:

```bash
bundle add ephem
```

If bundler is not being used to manage dependencies, install the gem by
executing:

```bash
gem install ephem
```

## How to select the right kernel file

JPL and IMCCE produces many different kernels over the years, with different
accuracy and ranges of supported years. Here are some that we would recommend to
begin with:

* `de421.bsp`: from 1900 to 2050, 17 MB
* `de440s.bsp`: from 1849 to 2150, 32 MB
* `inpop19a.bsp`: from 1900 to 2100, 22 MB

## Usage

```rb
# Download and store the SPICE binary kernel file
Ephem::Download.call(name: "de421.bsp", target: "tmp/de421.bsp")

# Load the kernel
spk = Ephem::SPK.open("tmp/de421.bsp")

# Explore the kernel's capabilities
puts spk
# => SPK file with 15 segments:
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Mercury Barycenter (1)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Venus Barycenter (2)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Earth-Moon Barycenter (3)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Mars Barycenter (4)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Jupiter Barycenter (5)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Saturn Barycenter (6)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Uranus Barycenter (7)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Neptune Barycenter (8)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Pluto Barycenter (9)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Sun (10)
# 1899-07-29..2053-10-09 Type 2 Earth-Moon Barycenter (3) -> Moon (301)
# 1899-07-29..2053-10-09 Type 2 Earth-Moon Barycenter (3) -> Earth (399)
# 1899-07-29..2053-10-09 Type 2 Mercury Barycenter (1) -> Mercury (199)
# 1899-07-29..2053-10-09 Type 2 Venus Barycenter (2) -> Venus (299)
# 1899-07-29..2053-10-09 Type 2 Mars Barycenter (4) -> Mars (499)

# Define the center and target bodies
center = 0 # Solar system barycenter
target = 5 # Jupiter

# Get the right segment
segment = spk[center, target]

# Explore the segment's capabilities
puts segment.describe(verbose: true)
# => 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Jupiter Barycenter (5)
# frame=1 source=DE-0421LE-0421

# Get the position and velocity of the target body at a given time
# The time is expressed in Julian Date
time = 2460676.5
state = segment.state_at(time)

# Display the position and velocity vectors
puts "Position: #{state.position}"
# => Position: Vector[157123190.6507038, 684298787.8592143, 289489366.7262833]
# The position is expressed in km

puts "Velocity: #{state.velocity}"
# => Velocity: Vector[-1117315.1437825128, 254177.26336095092, 136149.03901534996]
# The velocity is expressed in km/day

# Close the kernel when you are done with it
spk.close

# Or pass a block: the kernel is closed when the block finishes, even if it
# raises, and the block's value is returned
position = Ephem::SPK.open("tmp/de421.bsp") do |kernel|
  kernel[0, 5].position_at(2460676.5)
end
```

### Positions between any two bodies

`spk[center, target]` only returns pairs stored in the kernel. A JPL DE
kernel, for instance, stores the Earth relative to the Earth-Moon
barycenter (3), not relative to the Solar System Barycenter (0) or to the
Moon. `SPK#position_at` and `SPK#state_at` find the stored pairs linking
any two bodies and add or subtract them for you:

```rb
time = 2460676.5

# Earth relative to the Solar System Barycenter: (0 -> 3) + (3 -> 399)
spk.position_at(target: 399, center: 0, tdb: time)

# Moon relative to the Earth: (3 -> 301) - (3 -> 399)
state = spk.state_at(target: 301, center: 399, tdb: time)
state.position # km
state.velocity # km/day

# Arrays of times and a split Julian Date are supported too
spk.position_at(target: 301, center: 399, tdb: [time, time + 1])
spk.position_at(target: 301, center: 399, tdb: 2460676, tdb2: 0.5)
```

A `KeyError` is raised when no chain of stored pairs links the two
bodies.

## Orientation kernels (binary PCK)

Binary PCK (`DAF/PCK`) kernels store the orientation of a body frame over time
as Euler angles, rather than position. The most common use is the Moon's
physical libration via a lunar orientation kernel such as
`moon_pa_de440_200625.bpc`.

```rb
# Download and load a binary PCK orientation kernel
Ephem::Download.call(
  name: "moon_pa_de440_200625.bpc",
  target: "tmp/moon_pa_de440_200625.bpc"
)
pck = Ephem::PCK.open("tmp/moon_pa_de440_200625.bpc")

puts pck
# => PCK file with 2 segments:
# 1549-12-21..2426-02-16 Type 2 orientation of frame 31008 relative to frame 1
# 2426-02-16..2650-01-25 Type 2 orientation of frame 31008 relative to frame 1

# Query a body frame by its NAIF frame ID (31008 = MOON_PA_DE440).
# The time is expressed in Julian Date (TDB).
frame = pck[31008]
orientation = frame.orientation_at(2451545.0)

# The three classical 3-1-3 (Z-X-Z) Euler angles, in radians
puts "phi:   #{orientation.phi}"
puts "theta: #{orientation.theta}"
puts "psi:   #{orientation.psi}"

# Rates are in radians/day (ephem's per-day convention, like SPK velocities)
puts "rates: #{orientation.rates.inspect}"

# Use #angles_at when you do not need the rates (it skips the derivative)
angles = frame.angles_at(2451545.0)

pck.close
```

### Building the body-fixed frame

The orientation maps the reference frame into the body-fixed frame through the
3-1-3 (Z-X-Z) Euler sequence `M = Rz(psi) * Rx(theta) * Rz(phi)`. That
convention is built in, so you can get the rotation matrix directly:

```rb
# Straight from a frame, at a given time
matrix = frame.matrix_at(2451545.0)

# ...or from an Orientation you already have
matrix = orientation.to_matrix

# Geocentric Earth->Moon vector (km) from the SPK kernel used above, in the
# same inertial frame (J2000) as the orientation
spk = Ephem::SPK.open("tmp/de421.bsp")
earth_to_moon = spk.position_at(target: 301, center: 399, tdb: 2451545.0)

# Project it into the body-fixed frame
body_fixed = Ephem::Core::Rotation.apply(matrix, earth_to_moon)

spk.close
```

`Ephem::Core::Rotation` also exposes the lower-level, kernel-agnostic building
blocks (`about_x`, `about_y`, `about_z`, `multiply`, `apply`) if you need a
different axis order or an additional fixed rotation (such as the PA -> ME
offset, whose constants the consumer supplies).

## Errors

Errors about kernels, coverage and downloads inherit from `Ephem::Error`, so
a single `rescue Ephem::Error` catches them. The most common ones are:

- `Ephem::OutOfRangeError`: a requested time is outside the kernel's
  coverage. The message names the time, the pair or body and the covered
  range, and `#out_of_range_times` returns every uncovered time as a Julian
  Date:

  ```
  JD 2400000.5 (1858-11-17) is outside the coverage of Solar System
  Barycenter (0) -> Earth-Moon Barycenter (3), which covers
  JD 2451536.5..2451920.5 (1999-12-24..2001-01-11)
  ```

- `Ephem::FileFormatError`: the file is not a valid kernel, is empty or
  truncated, or is the wrong kind (an SPK passed to `Ephem::PCK.open`, or the
  other way round).
- `Ephem::UnsupportedError`: the kernel uses a segment or data type the gem
  does not implement.
- `Ephem::InvalidInputError`: a `Vector` or `Orientation` was given
  non-numeric values, or a `Vector` was multiplied or divided by a
  non-number.

Some errors are Ruby's own and are not `Ephem::Error`:

- `KeyError`: `SPK#[]` or `PCK#[]` was asked for a pair or body the kernel
  does not contain.
- `IndexError`: `Vector#[]` or `Orientation#[]` was given an index other
  than 0, 1 or 2.
- `Errno::ENOENT`, `Errno::EACCES` and other file system errors, which are
  not wrapped.

## CLI

The gem also provides a CLI to generate an excerpt from an original kernel file.

```bash
ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE
```

`START_DATE` and `END_DATE` are read in the Gregorian calendar and converted
to the Julian Date at midnight of that day. Errors are written to stderr and
the command exits with a non-zero status.

For example, generate an excerpt from DE440s for the year 2025 only supporting
the Sun, the Earth, the Moon and the Earth-Moon Barycenter:

```bash
ruby-ephem excerpt --targets 3,10,301,399 2025-01-01 2026-01-01 /path/to/de440s.bsp 2025_excerpt.bsp
```

While DE440s originally supports 14 segments from 1849 to 2150 with a size of
32 MB, the excerpt will only support 4 segments from 2025 to 2026 with a size of
140 KB.

Not only the excerpt is smaller, but most importantly it is way more
efficient to parse and to use in your application.

The input kernel kind (SPK or binary PCK) is detected automatically, so the
same command excerpts orientation kernels too:

```bash
ruby-ephem excerpt --targets 31008 2000-01-01 2030-01-01 /path/to/moon_pa_de440.bpc moon_excerpt.bpc
```

## Accuracy

Data from this library has been tested against the Python library [jplephem]
by Brandon Rhodes.

The following kernels have been used:
* DE405
* DE421
* DE430t
* DE440s

The times tested are integer Julian Dates in TDB (noon TDB) for every day
between 2000-01-01 and 2050-01-01. Vectors tested are always with `center` 0
(Solar System Barycenter), and `target` from `1` (Mercury Barycenter) to `10`
(Sun).

Rake tasks ensure data from this library match with `jplephem`. Positions match
exactly and velocities are within 2e-9 km/day (about 2e-11 m/s).

You can run them by following this pattern:

```
rake validate_accuracy date=2000 kernel=de440s target=1
```

_Note: Only date=2000 is supported at the moment. It covers 2000 to 2050._

If you wish to test them all in parallel, you can run:

```
rake validate_accuracy:all
```

For every commit, one test is executed in CI to ensure quality and accuracy
is always respected. At the moment, we don't run them all in CI to save
usage time.

[jplephem]: https://pypi.org/project/jplephem/

## YJIT

Run Ephem with [YJIT] enabled: computations are about 2 to 2.5 times faster.

| Benchmark                           | Interpreter | YJIT    |
|-------------------------------------|-------------|---------|
| `compute` (Earth-Moon barycenter)   | 2.7 µs      | 1.1 µs  |
| `compute_and_differentiate` (EMB)   | 4.8 µs      | 2.2 µs  |
| `angles_at` (Moon PCK)              | 2.3 µs      | 0.96 µs |

Measured with `benchmarks/run.rb` on Ruby 4.0.5.

Enable it with `ruby --yjit`, `RUBY_YJIT_ENABLE=1`, or `RubyVM::YJIT.enable`
(for example in a Rails initializer).

[YJIT]: https://docs.ruby-lang.org/en/3.4/yjit/yjit_md.html

## Benchmarks

Run the benchmark suite to measure performance across the computation pipeline:

```bash
bundle exec ruby benchmarks/run.rb
```

Add `--yjit` to compare with [YJIT](#yjit) enabled:

```bash
bundle exec ruby --yjit benchmarks/run.rb
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bundle exec rspec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

### Documentation on SPK files and NASA JPL's Ephemeris Data

SPK files (Spacecraft and Planet Kernel files) from NASA JPL are part of the
SPICE (Spacecraft Planet Instrument C-matrix Events) toolkit, used extensively
in space science and planetary exploration.

SPK files are highly organized binary files containing precise positional and
velocity data (ephemeris data).

#### Header

The header contains metadata such as:

* File version (e.g., SPK-0004)
* Creation date
* Producer information
* Summary of contents (e.g., target objects, time intervals, reference frames)

#### Segments

Each file is divided into multiple segments, which store ephemeris data for
specific objects over defined time intervals. A segment includes:

* **Target object**: The celestial body or spacecraft described.
* **Time interval**: Range of validity for the data.
* **Reference frame**: Coordinate system (e.g., J2000, ICRF).
* **Data type**: Format of ephemeris data (e.g., discrete states, Chebyshev
polynomials).

##### Example of SPK Structure

```
SPK File
├── Header
│   ├── File Version: SPK-0004
│   ├── Producer: NASA JPL
│   └── Creation Date: 2025-01-01
└── Segments
    ├── Segment 1 (Earth-Moon System)
    │   ├── Time Interval: 2000-01-01 to 2050-01-01
    │   ├── Reference Frame: J2000
    │   └── Data: Chebyshev Polynomials
    └── Segment 2 (Earth-Sun System)
        ├── Time Interval: 2000-01-01 to 2050-01-01
        ├── Reference Frame: J2000
        └── Data: Chebyshev Polynomials
```

#### Data Blocks

Segments are further divided into data blocks, which store:

* **State vectors**: Position and velocity of the object at specific times.
* **Time tags**: Times at which the state vectors are valid.

#### Mathematical Representations in SPK Files

SPK files store data in various formats to balance precision and storage
efficiency. The most common representation is Chebyshev polynomials, which
provide smooth interpolation of positions and velocities.

Chebyshev polynomials approximate the position and velocity of an object over a
time interval. They are computationally efficient and ensure minimal error
across the interval.

```
Position(t) = Σ (Cᵢ * Tᵢ(t))
```

* `Cᵢ`: Coefficients that define the polynomial terms.
* `Tᵢ(t)`: Chebyshev basis polynomials of the first kind.
* `t`: Normalized time within the interval, scaled to the range [-1, 1].

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/rhannequin/ruby-ephem. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to adhere
to the [code of conduct].

## License

The gem is available as open source under the terms of the [MIT License].

[MIT License]: https://opensource.org/licenses/MIT

## Code of Conduct

Everyone interacting in the Ephem project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow
the [code of conduct].

[code of conduct]: https://github.com/rhannequin/ruby-ephem/blob/main/CODE_OF_CONDUCT.md