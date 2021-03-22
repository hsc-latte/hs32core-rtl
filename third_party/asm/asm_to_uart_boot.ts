/*
 * Copyright (c) 2021 The HSC Core Authors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     https://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 * @file   asm.ts
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on March 13 2021, 00:29 AM
 */

///////////////////////////////////////////////////////////////////////////////
import { ArgumentParser, RawTextHelpFormatter } from "argparse";
import * as fs from "fs";
import { exit } from "process";
import { normalize, parse } from "./asm";
import * as isa from "./isa";
import SerialPort = require("serialport");

// padd with leading 0 if <16
function i2hex(i: number) {
  return "0x" + ("0" + i.toString(16)).slice(-2);
}

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function encode_for_uart_boot(arr: string[], device: string) {
  let buf = new Uint8Array(arr.length * 4);

  for (let i = 0; i < arr.length; i++) {
    buf[i * 4 + 3] = (parseInt(arr[i], 16) >> 0) & 0xff;
    buf[i * 4 + 2] = (parseInt(arr[i], 16) >> 8) & 0xff;
    buf[i * 4 + 1] = (parseInt(arr[i], 16) >> 16) & 0xff;
    buf[i * 4 + 0] = (parseInt(arr[i], 16) >> 24) & 0xff;
  }
  const progsize = buf.length;
  console.log(`progsize is ${progsize}`);

  let sizeBuffer = Buffer.allocUnsafe(4); // Init buffer without writing all data to zeros
  sizeBuffer.writeUInt32BE(progsize);
  //   console.log("size buffer:");
  //   console.log(Array.from(sizeBuffer).map(i2hex).join(" "));

  //   console.log(Array.from(buf).map(i2hex).join(" "));
  //   console.log(Buffer.from(buf).toString("hex"));

  const combinedArray = Uint8Array.from([...sizeBuffer, ...buf, 0, 0, 0, 0]);
  console.log(Array.from(combinedArray).map(i2hex).join(" "));

  console.log("sending over uart!");

  const port = new SerialPort(device, {
    baudRate: 9600,
    autoOpen: false,
    parity: "none",
    stopBits: 1,
    dataBits: 8,
  });
  await sleep(50);

  // Open errors will be emitted as an error event
  port.on("error", function (err) {
    console.log("serial Error: ", err.message);
  });

  port.open(async function (err) {
    if (err) {
      return console.log("Error opening port: ", err.message);
    }

    // Because there's no callback to write, write errors will be emitted on the port:
    // port.write('main screen turn on')
    console.log("port has opened");
    await sleep(2500);

    // for (const value of combinedArray) {
    //   port.write(Buffer.from([value]), function (err) {
    //     if (err) {
    //       return console.log("Error on serial write: ", err.message);
    //     }
    //     console.log(`byte written ${[value]}`);
    //   });
    //   //   await sleep(20);
    // }

    port.write(Buffer.from(combinedArray), function (err) {
      if (err) {
        return console.log("Error on serial write: ", err.message);
      }
      console.log("message written");
    });
  });

  port.on("data", function (data) {
    console.log("got seral Data:", data);
  });

  //   fs.writeFileSync(file, buf, {
  //     encoding: "binary",
  //     flag: "w+",
  //   });
}

const preamble = `
__       ____ ___               
/ /  ___ |_  /|_  |___ ____ __ _ 
/ _ \\(_-<_/_ </ __// _ \`(_-</  ' \\
/_//_/___/____/____/\\_,_/___/_/_/_/
                                
                                
(c) 2020-2021 HS32 Core Authors
  Kevin Dai and Anthony Kung
`;

function uart_boot_main() {
  const parser = new ArgumentParser({
    description: "The HS32 Assembler with uart boot .",
    formatter_class: RawTextHelpFormatter,
  });
  parser.add_argument("-v", {
    help: "show the program's version number",
    action: "version",
  });

  parser.add_argument("input", {
    help: "input file name",
    metavar: "[input]",
  });
  parser.add_argument("-d", "--device", {
    help: "output serial device ",
    metavar: "[device]",
    required: false,
    default: "./",
  });
  const args = parser.parse_args(process.argv.slice(2));

  console.log(preamble);

  if (fs.existsSync(args.input)) {
    const prog = parse(normalize(fs.readFileSync(args.input, "utf8")));
    const size = 1024;

    encode_for_uart_boot(isa.tohexarray(prog), args.device);
  } else {
    console.error("Input file does not exist");
    exit(-1);
  }

  //   exit(0);
}
console.log("wtf");
if (require.main === module) {
  uart_boot_main();
}
