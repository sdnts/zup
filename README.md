# zup


`zup` (pronounced zee-up) is a tool to manage versions of the Zig toolchain (currently
the compiler and [zls](https://github.com/zigtools/zls)). It intends to make it
easy to work with multiple versions of the Zig compiler and ZLS across projects. 

These problems are in scope:

- [x] Install specific versions of Zig (and a compatible version of ZLS)
- [x] Install / update to the latest master / stable versions of these tools with a single command
- [x] Switch between installed tool versions with a single command
- [x] List all installed tool versions, and manually purge the ones you don't need
- [ ] Install / switch to the correct version of tools for projects with a `build.zig.zon` with a single command

These are also goals of the upcoming official Zig package manager. As such, I
expect it to supersede `zup` at some point.

### Installation

You can download a pre-built binary for a supported OS / arch from the 
[Releases](https://github.com/sdnts/zup/releases) page, extract, and
place it in a location that is in your $PATH. I recommend `~/.zup/bin`, since
that is also where Zup installs toolchains by default. You may also have to give
it execution permissions by running `chmod +x zup`.

Then, add `~/.zup/bin` to your $PATH:

```sh
# sh / bash / zsh
export PATH=$PATH:/home/sid/.zup/bin

#### OR ####

# fish
fish_add_path /home/sid/.zup/bin
```

### Configuration

The only configuration option currently is the `ZUP_PREFIX` environment variable.
Set it to a valid path to tell Zup where to place downloaded binaries. `ZUP_PREFIX`
defaults to `~/.zup`

```sh
# sh / bash / zsh
export ZUP_PREFIX=/usr/local/.zup

#### OR ####

# fish
set -x ZUP_PREFIX /usr/local/.zup
```

### Usage

Download, install & activate the latest `master` version of Zig and ZLS:
```sh
$ zup install

info(zup): Checking for updates on master
info(zup): Latest version on master is already installed, skipping download
info(zup): Setting 0.12.0-dev.3405+31791ae15 as active
```

Download, install & active the latest `stable` version of Zig and ZLS:
```sh
$ zup install stable
```

Download, install & activate a specific version of Zig and ZLS:
```sh
$ zup install 0.11.0
$ zup install 0.12.0-dev.2990+31763d28c 
```

List all currently downloaded versions of Zig and ZLS:
```sh
$ zup list
$ zup list master
$ zup list stable

info(zup): Install location: /Users/siddhant/.zup

0.12.0-dev.3029+723d13f83
  └─ Zig: 0.12.0-dev.3029+723d13f83
  └─ ZLS: 0.12.0-dev.438+8cca7a1
0.12.0-dev.3405+31791ae15
  └─ Zig: 0.12.0-dev.3405+31791ae15
  └─ ZLS: 0.12.0-dev.493+0844c71

```

Display all usage instructions:
```
$ zup --help
```

### Uninstallation

Uninstallation is a matter of deleting the `zup` binary, as well as all installed
toolchain versions.

Delete the `zup` binary from wherever you put it initially (run `which zup` to
find out).

Installed toolchains are not deleted automatically out of an abundance of caution.
If you overrode the `ZUP_PREFIX` environment variable, delete the directory it
points to, and unset the environment variable. Otherwise, delete the `~/.zup`
directory.

Also don't forget to remove `~/.zup/bin` from your $PATH.

---

### Development

Please be mindful of hitting ZLS / Zig servers during development, these projects
are community-funded and blob egress is expensive. I've included a mock server
for use during development under `/devserver`. This is currently a JS project,
so it requires [Bun](https://bun.sh) installed. Run `bun install`, followed by 
`bun run src/index.ts` to start up the mock server. Debug `zup` builds should
automatically talk to this dev server. Release builds talk to Zig / ZLS servers.

### Releases

Running the `Release` GitHub action with a version number tags the `HEAD` on `main`
and creates a release draft. This must be published by a human manually.
