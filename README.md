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

Ephem currently only support planetary ephemerides like DE421, DE430,
INPOP19A, etc.

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
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Earth-moon Barycenter (3)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Mars Barycenter (4)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Jupiter Barycenter (5)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Saturn Barycenter (6)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Uranus Barycenter (7)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Neptune Barycenter (8)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Pluto Barycenter (9)
# 1899-07-29..2053-10-09 Type 2 Solar System Barycenter (0) -> Sun (10)
# 1899-07-29..2053-10-09 Type 2 Earth-moon Barycenter (3) -> Moon (301)
# 1899-07-29..2053-10-09 Type 2 Earth-moon Barycenter (3) -> Earth (399)
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
```

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

`Ephem::Core::Rotation` provides kernel-agnostic helpers to turn Euler angles
into a 3x3 rotation matrix and apply it to a vector, so you can build a
body-fixed frame from the angles:

```rb
phi, theta, psi = angles.to_a
# Compose the inertial -> body-fixed rotation (3-1-3 sequence)
matrix = Ephem::Core::Rotation.multiply(
  Ephem::Core::Rotation.about_z(psi),
  Ephem::Core::Rotation.about_x(theta),
  Ephem::Core::Rotation.about_z(phi)
)
body_fixed = Ephem::Core::Rotation.apply(matrix, some_vector)
```

## CLI

The gem also provides a CLI to generate an excerpt from an original kernel file.

```bash
ruby-ephem excerpt [options] START_DATE END_DATE INPUT_FILE OUTPUT_FILE
```

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

## Accuracy

Data from this library has been tested against the Python library [jplephem]
by Brandon Rhodes.

The following kernels have been used:
* DE405
* DE421
* DE430t
* DE440s

The times tested are noon UTC for every day between 2000-01-01 and
2050-01-01. Vectors tested are always with `center` 0 (Solar System Barycenter),
and `target` from `1` (Mercury Barycenter) to `10` (Sun).

Rake tasks ensure data from this library match with `jplephem`. Positions match
exactly and velocities are within 0.002 mm/s.

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

## Benchmarks

Run the benchmark suite to measure performance across the computation pipeline:

```bash
bundle exec ruby benchmarks/run.rb
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

[MIT License]: (https://opensource.org/licenses/MIT)

## Code of Conduct

Everyone interacting in the Ephem project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow
the [code of conduct].

[code of conduct]: (https://github.com/rhannequin/ephem/blob/main/CODE_OF_CONDUCT.md)