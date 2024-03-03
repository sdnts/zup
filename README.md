# zup

`zup` (pronounced zee-up) is a tool to manage versions of the Zig toolchain (currently
the compiler and [zls](https://github.com/zigtools/zls). It aims to keep "compatible"
versions of these tools up-to-date.

### Installation

- macOS: `brew tap sdnts/tools && brew install zup`
- Others: You will need to bootstrap `zup` using an existing Zig installation

Add `~/.zig/bin` to your $PATH.

### Usage

Download and install the latest `master` version of Zig and ZLS:
```sh
$ zup
```

Download and install the latest `stable` version of Zig and ZLS:
```sh
$ zup --stable
```

Download and install a specific version of Zig and ZLS:
```sh
$ zup 0.8.0
$ zup install 0.11.0
$ zup install 0.12.0-dev.2990+31763d28c 
```

List all downloaded versions of Zig and ZLS:
```sh
$ zup list
$ zup list --master
$ zup list --stable
```

### Development

Please be mindful of hitting ZLS / Zig servers during development, these projects
are community-funded and blob egress is expensive. I've included a mock server
for use during development.
