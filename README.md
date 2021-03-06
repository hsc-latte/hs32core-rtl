# HS32 Core RTL Repository

Verilog Defines:
- `SOC` Compile with internal BRAM memory interface instead
- `SIM` Compile for simulations
- `PROG` Compile for SRAM programmer

See [HOWTO.md](HOWTO.md) for more details on setting up the toolchain.

# Preparing the Devboard

Ensure the FPGA is socketed and connected properly.

Ensure all power rails measure at the correct voltage.

**Solder a jumper wire from MISO to the BHE# pad**

Beware, the UART RX and TX pins run at 3.3V instead of 5V. The FPGA is NOT 5V tolerant.

# Running and uploading Blinky

Let's see how you would run and upload your first program using VSCode.

First, we need to generate the `bram0.hex` to `bram4.hex` files.

Use `enc.js` to select from a premade compiled program.
```
node enc.js blinky
```
Under `bench/` you will find generate files.
Next, run the `Build All` task and select `SOC`
to configure the project for our devboard.
Finally, plug in the devboard and run the `Upload`
task.

