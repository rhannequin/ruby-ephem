# Ephem

Ephem is a Ruby gem that provides a simple interface to the JPL Development
Ephemeris (DE) series as SPICE binary kernel files. The DE series is a
collection of numerical integrations of the equations of motion of the solar
system, used to calculate the positions of the planets, the Moon, and other
celestial bodies with high precision.

Ephem currently only support planetary ephemerides like DE405, DE421, de430,
etc.

The library in high development mode and does not have a stable version yet.
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

## Usage

```rb
# Download and store the SPICE binary kernel file
Ephem::IO::Download.call(
  name: "de421.bsp",
  target: "tmp/de421.bsp"
)

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
state = segment.compute_and_differentiate(time)

# Display the position and velocity vectors
puts "Position: #{state.position}"
# => Position: Vector[157123190.6507038, 684298787.8592143, 289489366.7262833]
# The position is expressed in km

puts "Velocity: #{state.velocity}"
# => Velocity: Vector[-1117315.1437825128, 254177.26336095092, 136149.03901534996]
# The velocity is expressed in km/day
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run
`bundle exec rspec` to run the tests. You can also run `bin/console` for an
interactive prompt that will allow you to experiment.

## Contributing

Bug reports and pull requests are welcome on GitHub at
https://github.com/rhannequin/ruby-ephem. This project is intended to be a
safe, welcoming space for collaboration, and contributors are expected to adhere
to
the [code of conduct](https://github.com/rhannequin/ephem/blob/main/CODE_OF_CONDUCT.md).

## License

The gem is available as open source under the terms of
the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ephem project's codebases, issue trackers, chat
rooms and mailing lists is expected to follow
the [code of conduct](https://github.com/rhannequin/ephem/blob/main/CODE_OF_CONDUCT.md).
