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
 * @file   enc.js
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on January 04 2021, 1:32 AM
 */

const fs = require('fs');

const blinky = [
    '2400FF00', // MOV r0 <- 0xFF00 ; AICT base address
    '24100FFF', // MOV r1 <- 0x0FFF ; Set GPIO mode out
    '34100080', // STR [r0+80] <- r1
    '241016E3', // MOV r1 <- 0x16E3 ; Timer match ~ 1 Hz
    '2420002D', // MOV r2 <- 0x2D   ; Timer config = 01 01 101 (toggle normal 1024)
    '341000A4', // STR [r0+0xA4] <- r1
    '342000A0', // STR [r0+0xA0] <- r2
    '50000000', // B<0000> 0
];

const uart = [
    '2400FF00', // MOV r0 <- 0xFF00 ; AICT base
    '24100068', // MOV r1 <- 0x68   ; 12Mhz/115200Hz
    '341000BC', // STR [r0+BC] <- r1
    '24100FFF', // MOV r1 <- 0x0FFF ; Set GPIO mode out
    '34100080', // STR [r0+80] <- r1
    '24100059', // MOV r1 <- [data-3]
    // Loop
    '14210000', // LDR r2 <- [r1]
    '842200FF', // AND r2 <- r2 & 0xFF
    '6C220000', // CMP r2, 0
    '51000010', // B<0001> [end]
    '70000018', // B<0000>L [write]
    '44110001', // ADD r1 <- r1 + 1
    '50FFFFE8', // B<0000> [loop]
    // End
    '24200800', // MOV r2 <- 0x0800 ; Set green LED
    '34200084', // STR [r0+84] <- r2
    '50000000', // B<0000> 0
    // Write subroutine
    '24300001', // MOV r3 <- 1  ; Do TX write (badness 1000)
    '342000B0', // STR [r0+B0] <- r2
    '343000B8', // STR [r0+B8] <- r3
    '144000B8', // LDR r4 <- [r0+B8]
    '8C040020', // TST r4, 0x20 ; Test TX ready
    '52FFFFF8', // B<0010> -8   ; Loop if not zero
    '20F0E000', // MOV pc <- lr ; Return
    // Data
    '48656c6c',
    '6f2c2077',
    '6f726c64',
    '21000000'
];

// Outputs the 4 bram files
// arr: string array of 32-bit hex
// sz : total size of ram (# of 32-bit words)
function encode(arr, sz) {
    let bram0 = '';
    let bram1 = '';
    let bram2 = '';
    let bram3 = '';
    for(let i = 0; i < sz; i++) {
        let sp = ' ';
        if((i+1) % 16 == 0) {
            if(i+1 < sz)
                sp = '\n';
            else
                sp = '';
        }
        bram3 += (arr[i] ? arr[i].substring(0, 2).toUpperCase() : '00') + sp;
        bram2 += (arr[i] ? arr[i].substring(2, 4).toUpperCase() : '00') + sp;
        bram1 += (arr[i] ? arr[i].substring(4, 6).toUpperCase() : '00') + sp;
        bram0 += (arr[i] ? arr[i].substring(6, 8).toUpperCase() : '00') + sp;
    }
    fs.writeFileSync('bench/bram0.hex', bram0, (e, d) => {});
    fs.writeFileSync('bench/bram1.hex', bram1, (e, d) => {});
    fs.writeFileSync('bench/bram2.hex', bram2, (e, d) => {});
    fs.writeFileSync('bench/bram3.hex', bram3, (e, d) => {});
}

///////////////////////////////////////////////////////////////////////////////

const default_sz = 1024;

const readline = require('readline');
const { exit } = require('process');
const ql = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});
function prompt(str) {
    return new Promise((resolve) => {
        ql.question(str, (d) => {
            resolve(d);
        });
    });
}
async function main() {
    let bits = await prompt(`32-bit words in ram (default ${default_sz}): `);
    bits = parseInt(bits);
    bits = bits ? bits : default_sz;
    let prog = [];
    console.log('Enter program hex array:');
    for(i = 0; i < bits; i++) {
        /** @type{string} */
        let line = await prompt('> ');
        if(!line) break;
        prog.push(line);
    }
    // console.log(prog);
    process.stdout.write('Encoding program... ');
    encode(prog, bits);
    console.log('Done.');
    exit(0);
}
const preamble =
`
 _         ____ ___                
| |_   ___|__ /|_  ) ___  _ _   __ 
| ' \\ (_-< |_ \\ / / / -_)| ' \\ / _|
|_||_|/__/|___//___|\\___||_||_|\\__|
                                   
  (c) 2020-2021 HS32 Core Authors
     Kevin Dai and Anthony Kung
`;
console.log(preamble);
let arg1 = process.argv[2];
if(!arg1) {
    main();
} else if(arg1 == 'blinky') {
    process.stdout.write('Encoding blinky... ');
    encode(blinky, default_sz);
} else if(arg1 == 'uart') {
    process.stdout.write('Encoding uart... ');
    encode(uart, default_sz);
} else if(arg1 == 'file') {
    let file = process.argv[3];
    let bits = process.argv[4];
    console.log(`Reading file ${file}... `);
    if(fs.existsSync(file)) {
        process.stdout.write('Encoding file... ');
        let prog = fs.readFileSync(file, { encoding: 'ascii' });
        prog = prog.split('\n').map(v => v.trim());
        //console.log(prog);
        bits = parseInt(bits);
        if(!bits) {
            console.warn(`Invalid word length. Defaulting to ${default_sz}.`);
            bits = default_sz;
        }
        encode(prog, bits);
    } else {
        console.error('File not found!');
        exit(-1);
    }
    encode(blinky, default_sz);
} else {
    console.error(`Unknown argument: ${arg1}.`);
    console.log('Usage: node ./enc.js [ blinky | file ] [filename?] [words?]');
    exit(-1);
}

console.log('Done.');
exit(0);
