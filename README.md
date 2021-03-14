# HS32 Core RTL Repository

[![](https://img.shields.io/badge/License-Apache-blue.svg?style=flat-square)](https://opensource.org/licenses/Apache-2.0)
[![](https://img.shields.io/static/v1?label=HS32&message=RTL&color=orange&style=flat-square)]()

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Getting started](#getting-started)
- [Preparing the devboard](#preparing-the-devboard)
- [Uploading prebuilt firmware](#uploading-prebuilt-firmware)
- [Regenerating the BRAM firmware](#regenerating-the-bram-firmware)
- [Connecting to UART with an Arduino](#connecting-to-uart-with-an-arduino)

## Getting started

> Note: If you're only interested in uploading code, you do not need to
setup and install the RTL toolchain.

See [HOWTO.md](HOWTO.md) for more details on setting up your environment.

Build configurations (Verilog defines):
- `SOC` Compile with internal BRAM memory interface instead
- `SIM` Compile for simulations
- `PROG` Compile for SRAM programmer

## Preparing the dev board

- Ensure the FPGA is socketed and properly connected.
- Ensure all power rails measure at the correct voltage.
- **Solder a jumper wire from MISO to the BHE# pad**
- Beware, the UART RX and TX pins run at 3.3V instead of 5V. The FPGA is **NOT** 5V tolerant.

## Uploading prebuilt firmware

...

## Regenerating the BRAM firmware

Let's see how you would run and upload your blinky program using VSCode.

> For this, you need to have the RTL toolchain installed

First, we need to generate the `bench/bram0.hex` to `bram4.hex` files. Use `asm.js` to select from a list of premade programs. Here, we will select "blinky":
```
node build/asm firmware/blinky.asm -fhex -o bench/
```
Next, run the `Build All` task and select `SOC` to configure the project for our dev board. Finally, plug in the dev board and run the `Upload` task.

## Connecting to UART with an Arduino

For a UART connection, you can use an Arduino and a level shifter. For this example, we will use the 74LS245 bus transceiver as the level shifter.

> Before you begin, ensure you read the [datasheet pinout here](https://www.ti.com/lit/ds/symlink/sn74lvc245a.pdf?HQS=TI-null-null-digikeymode-df-pf-null-wwe&ts=1594325733882)

Ensure you have a 3.3V supply (the dev board's 3.3V supply should be fine).
- Connect DIR to GND.
- Connect OE# to GND.
- Connect VCC and GND to 3.3V and ground, respectively.

Here, the A-side will be 3.3V **output**, and the B-side will be 5V-tolerant **input**. Thus,
- Connect A1 to dev board RX and B1 to Arduino PIN X
- Connect B2 to dev board TX and A2 to Arduino PIN Y

Keep note of what X and Y are (I chose 3 and 2). Make sure you don't use the dedicated serial pins 0 and 1 on the UNO and similar pins on other boards.

> Before you continue, ensure the output levels are correct or you will fry the FPGA.

We will use the Arduino to pass through serial connections:
```c++
#include <SoftwareSerial.h>

// Our side's RX, TX (which is TX, RX on the devboard)
SoftwareSerial devSerial(Y, X);

void setup() {
    Serial.begin(9600);
    while(!Serial);
    devSerial.begin(9600);
}

void loop() {
    if(devSerial.available())
        Serial.write(devSerial.read());
    if(Serial.available())
        devSerial.write(Serial.read());
}
```