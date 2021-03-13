# HS32 Core RTL Repository

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

## Preparing the devboard

- Ensure the FPGA is socketed and properly connected.
- Ensure all power rails measure at the correct voltage.
- **Solder a jumper wire from MISO to the BHE# pad**
- Beware, the UART RX and TX pins run at 3.3V instead of 5V. The FPGA is **NOT** 5V tolerant.

## Uploading prebuilt firmware

...

## Regenerating the BRAM firmware

Let's see how you would run and upload your a blinky program using VSCode.

> For this, you need to have the RTL toolchain installed

First, we need to generate the `bram0.hex` to `bram4.hex` files. Use `enc.js` to select from a list of premade programs. Here, we will select "blinky":
```
node enc.js blinky
```
Under `bench/` you will find the generated files. Next, run the `Build All` task and select `SOC` to configure the project for our devboard. Finally, plug in the devboard and run the `Upload` task.

## Connecting to UART with an Arduino

For a UART connection, you can use an Arduino and a level shifter. For this example, we will use the 74LS245 bus transceiver as the level shifter.

> Before you begin, ensure you read the [datasheet pinout here](https://www.ti.com/lit/ds/symlink/sn74lvc245a.pdf?HQS=TI-null-null-digikeymode-df-pf-null-wwe&ts=1594325733882)

Ensure you have a 3.3V supply. The devboard's 3.3V supply should be fine.
- Connect DIR to ground.
- Connect OE# to ground.
- Connect VCC and GND to 3.3V and ground respectively.

Here, the A side will be 3.3V **output** and B side will be 5V-tolerant **input**.
Thus,
- Connect A1 to devboard RX and B1 to Arduino PIN X
- Connect B2 to devboard TX and A2 to Arduino PIN Y

Keep note of what X and Y are (I chose 3 and 2). Make sure you don't choose the dedicated serial pins 0 and 1 on the UNO and similar pins on other boards.

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