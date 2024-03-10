# zup

`zup` (pronounced zee-up) is a tool to manage versions of the Zig toolchain (currently
the compiler and [zls](https://github.com/zigtools/zls). It aims to keep "compatible"
versions of these tools up-to-date.

### Installation

- macOS: `brew tap sdnts/tools && brew install zup`
- Others: You will need to bootstrap `zup` using an existing Zig installation

Add `~/.zup/bin` to your $PATH.

### Usage

Download and install the latest `master` version of Zig and ZLS:
```sh
$ zup install
```

Download and install the latest `stable` version of Zig and ZLS:
```sh
$ zup install stable
```

Download and install a specific version of Zig and ZLS:
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
