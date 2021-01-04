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
    '2400FF00', // MOV r0 <- 0xFF00
    '24100000', // MOV r1 <- 0x0000
    '34100084', // STR [r0+0x84] <- r1
    '241001FF', // MOV r1 <- 0x01FF
    '34100080', // STR [r0+0x80] <- r1
    '2420FFFF', // MOV r2 <- 0xFFFF
    '64220001', // SUB r2 <- r2 - 1
    '6C220000', // CMP r2, 0
    '52FFFFF8', // B<0010> -8
    '24100001', // MOV r1 <- 0x0001
    '34100084', // STR [r0+0x84] <- r1
    '2420FFFF', // MOV r2 <- 0xFFFF
    '64220001', // SUB r2 <- r2 - 1
    '6C220000', // CMP r2, 0
    '52FFFFF8', // B<0010> -8
    '24F00000', // MOV PC, 0
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
    let bits = await prompt('32-bit words in ram (default 256): ');
    bits = parseInt(bits);
    bits = bits ? bits : 256;
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
    encode(blinky, 256);
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
            console.warn(`\u001b[33m%s\u001b[0m`, 'Invalid word length. Defaulting to 256.');
            bits = 256;
        }
        encode(prog, bits);
    } else {
        console.error('File not found!');
        exit(-1);
    }
    encode(blinky, 256);
} else {
    console.error(`Unknown argument: ${arg1}.`);
    console.log('Usage: node ./enc.js [ blinky | file ] [filename?] [words?]');
    exit(-1);
}

console.log('Done.');
exit(0);
