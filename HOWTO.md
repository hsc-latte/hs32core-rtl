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
Located in `third_party/` is a **dotnet core** distribution for Windows and Mac users only (for now).
In the workspace root, execute
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

You will need to build `yosys` first, then `icestorm` and finally `nextpnr-ice40`. Good luck if you're on Mac:
- Use Homebrew to install `yosys` and `icarus-verilog`
- Build `icestorm` and `nextpnr` manually (follow the instructions on the respective Github repositories).
- Be sure to follow the build instructions on the respective repositories.
- `sed` is broken and you need to install `sed` from Brew and override it by setting `PATH`.
  - If it doesn't work, do `sudo su`, manually set PATH and run `make install` from there.
- To install GtkWave, see https://ughe.github.io/2018/11/06/gtkwave-osx

**Word of caution:** Most of these packages build without any optimization enabled and are therefore painfully slow. Make sure to also:
- Build `yosys` with `ENABLE_NDEBUG=1`.
  - On Mac, do `brew edit yosys` and while you're at it, why not add `-j8` to the build args. Then issue `brew -v install yosys --build-from-source`
- When building `nextpnr`, pass `-DUSE_OPENMP=ON` to `cmake`
  - On Mac, you have brought pain upon yourself. Install `libomp` from Brew.
  - Open CMakeLists.txt and find `-fopenmp` and replace it with `-Xpreprocessor -fopenmp -L/usr/local/lib/ -lomp`. Turn on `USE_OPENMP` while you're at it.

## Running the flow manually

Instructions are for if you are not using VSCode.

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
