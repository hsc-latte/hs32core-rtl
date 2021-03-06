## Table of Contents
- [Table of Contents](#table-of-contents)
- [Get iceFUNprog (console version)](#get-icefunprog--console-version-)
- [Install VSCode extensions](#install-vscode-extensions)
- [Install the RTL toolchain](#install-the-rtl-toolchain)
  * [Installing from APIO (all platforms)](#installing-from-apio--all-platforms-)
  * [Building the toolchain from source](#building-the-toolchain-from-source)
- [Running the flow manually](#running-the-flow-manually)
---

## Get iceFUNprog (console version)
Located in `third_party/` is a **dotnet core** distribution for
Windows and dMac users only (for now).
In the workspace root, simply execute
```
cd third_party/icefunprog && dotnet publish -c Release
```
and optionally add the `.exe` to your PATH (on Windows).

## Install VSCode extensions

For VSCode users,
install the following recommended extensions (all optional):
- spmeesseman.vscode-taskexplorer
- theonekevin.icarusext

## Install the RTL toolchain

Ensure you have all the tools needed under your environment PATH variable, this includes:
`yosys`, `nextpnr-ice40`, `icepack`, `iverilog`, `vvp`, `gtkwave`, `verilator`. Windows users, ensure you have WSL enabled and the GNU toolchain installed.

### Installing from APIO (all platforms)

**Beware, these packages are woefully outdated**.
Install the APIO toolchain:

```
pip3 install apio
```

Install the drivers:

```
apio install -a
```

You should add yosys, iverilog and gtkwave to your path. The binaries are located in subdirectories under:
```
~/.apio/packages
```
(or equivalent Windows directories).

### Building the toolchain from source

You will need to build `yosys` first, then `icestorm` and finally `nextpnr-ice40`. Good luck if you're on MacOS:
- Use Homebrew to install `yosys` and `icarus-verilog`
- Build `icestorm` and `nextpnr` manually (follow the instructions on the respective Github repositories).
- `sed` is broken and you need to install `sed` fom Brew and override it by setting `PATH`.
- To install GtkWave, see https://ughe.github.io/2018/11/06/gtkwave-osx

## Running the flow manually

Instructions are for if you are not using vscode.

**!! MAKE SURE YOU RUN ALL COMMANDS FROM THE ROOT DIRECTORY, `rtl` !!**

Check out `.vscode/tasks.json` for the complete list of commands.

To simulate, first compile:
```
iverilog machine/tb.v -o a.out
```

Then run:
```
vvp a.out
```

You should be able to open the `.vcd` files in something like GTKWave.
