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

These are also goals of the upcoming official Zig package manager. As such, I fully
expect it to supersede `zup` at some point.

### Installation

The simplest way to get set up is to download a pre-compiled binary for a supported
OS / arch from the [Releases](https://github.com/sdnts/zup/releases) page and
place it in a location that is in your $PATH. I recommend `~/.zup/bin`, since
that goes well with the default location Zup installs toolchains in (you can
override this as well).

- [ ] macOS: `brew tap sdnts/tools && brew install zup`

Add `~/.zup/bin` to your $PATH.

### Usage

Download, install & activate the latest `master` version of Zig and ZLS:
```sh
$ zup install
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
```

Display all usage instructions:
```
$ zup --help
```

---

By default, `zup` stores toolchains under `~/.zup`. Setting `ZUP_PREFIX` to a
valid path overrides this path.

### Development

Please be mindful of hitting ZLS / Zig servers during development, these projects
are community-funded and blob egress is expensive. I've included a mock server
for use during development under `/devserver`. This is currently a JS project,
so it requires [Bun](https://bun.sh) installed. Run `bun install`, followed by 
`bun run src/index.ts` to start up the mock server. Debug `zup` builds should
automatically talk to this dev server.
