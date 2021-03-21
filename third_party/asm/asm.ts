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

import { Block, Instruction, SyntaxRule, Token, TokenRule } from './common';
import * as isa from './isa';

const tokenrules : TokenRule[] = [
    { type: "SPACE",    regex: /\s+/ },
    { type: "SHIFT",    regex: /(shr|shl|ror|shx)/ },
    { type: "(",        regex: /(\()/ },
    { type: ")",        regex: /(\))/ },
    { type: "[",        regex: /(\[)/ },
    { type: "]",        regex: /(\])/ },
    { type: ",",        regex: /(,|<-)/ },
    { type: ":",        regex: /(:)/ },
    
    // Operators
    { type: "OPL",      regex: /(&|\||\*|\^)/ },
    { type: "OP",       regex: /(\+|-)/ },

    { type: "STR",      regex: /(["'])((?:\\.|[^\\])*?)\1/ },
    { type: "LIT_HEX",  regex: /(?:0x|0X)([A-Fa-f0-9_]+)/ },
    { type: "LIT_HEX",  regex: /([A-Fa-f0-9_]+)(?:h|H)/ },
    { type: "LIT_BIN",  regex: /(?:0b|0B)([01_]+)/ },
    { type: "LIT_BIN",  regex: /([01_]+)(?:b|B)/ },
    { type: "LIT_DEC",  regex: /([0-9]+)/ },
    { type: "IDENT",    regex: /([A-Za-z0-9_]+)/ },
];

// Reduction rules (combining multiple tokens)
const syntaxrules : SyntaxRule[] = [
    { type: "NUM",      rule: [ 'LIT_HEX' ], parse: x => parseInt(x[0].value.replace(/_/, ''), 16)},
    { type: "NUM",      rule: [ 'LIT_DEC' ], parse: x => parseInt(x[0].value.replace(/_/, ''), 10)},
    { type: "NUM",      rule: [ 'LIT_BIN' ], parse: x => parseInt(x[0].value.replace(/_/, ''),  2)},
    
    { type: "LABEL",    rule: [ 'IDENT',':' ],            parse: x => x[0].value },
    { type: "SHREG",    rule: [ 'IDENT','SHIFT','NUM' ],  parse: x => [ x[0].value, x[1].value, x[2].value ]},

    { type: "OFFSET",   rule: [ '[','IDENT','OP','NUM',']' ],   parse: x => [ x[1], x[2], x[3] ]},
    { type: "OFFSET",   rule: [ '[','IDENT','OP','SHREG',']' ], parse: x => [ x[1], x[2], x[3] ]},
    { type: "OFFSET",   rule: [ '[','IDENT','OP','IDENT',']' ], parse: x => [ x[1], x[2], x[3] ]},
    { type: "PTR",      rule: [ '[','IDENT',']' ],              parse: x => x[1]},
    { type: "PTR",      rule: [ '[','NUM',']' ],                parse: x => x[1]},
    { type: "PTR",      rule: [ 'OFFSET' ],                     parse: x => x[0]},
    { type: "PTR",      rule: [ '[','OP','NUM',']' ], 
        parse: x => {
            return {
                type: "NUM",
                value: (x[1].value == '-' ? -1 : 1) * x[2].value
            }
        }
    },
];

// Brute force match and reduce once, returning reduced array + status
function matchsyntax(tokens : Token[]) {
    let hasMatch = false;
    for(let i = 0; i < syntaxrules.length; i++) {
        const rule    = syntaxrules[i].rule;
        const parsefn = syntaxrules[i].parse;

        // Given rule, find matching token sequence
        // Then combine tokens using the reduction rule

        for(let j = 0; j + rule.length-1 < tokens.length; j++) {
            if(rule.reduce((a, v, k) => a && tokens[j+k].type == v, true)) {
                const raw = tokens.slice(j, j+rule.length);
                const value = parsefn ? parsefn(raw) : raw;
                tokens.splice(j, rule.length, {
                    type: syntaxrules[i].type,
                    value: value
                });
                hasMatch = true;
                break;
            }
        }
    }
    return { a: hasMatch, b: tokens };
}

// A simple tokenize and reduce function
function tokenize(input: string): Token[] {
    let line = input.replace(/;.*/, '').trim();
    let hasMatch = true;
    let tokens : Token[] = [];
    while(hasMatch) {
        hasMatch = false;
        for(let i = 0; i < tokenrules.length; i++) {
            const match = line.match(tokenrules[i].regex);
            if(match && match.length > 0 && match.index == 0) {
                line = line.substr(match[0].length);
                hasMatch = true;
                if(tokenrules[i].type !== "SPACE")
                    tokens.push({
                        type: tokenrules[i].type,
                        value: tokenrules[i].type == "STR" ? match[2] : match[1]
                    });
                break;
            }
        }
        // Continue until we have no more matches
    }
    if(line !== "") {
        throw `Tokenizer error with residue "${line}"`;
    }
    // Try matching and reducing now
    hasMatch = true;
    while(hasMatch) {
        const tmp = matchsyntax(tokens);
        hasMatch = tmp.a, tokens = tmp.b;
    }
    return tokens;
}

///////////////////////////////////////////////////////////////////////////////

function parseargs(tokens: Token[]): Token[] {
    var ret = [];
    var expectDelim = false;
    for(let i = 0; i < tokens.length; i++) {
        if(expectDelim && tokens[i].type == ',') {
            // Do nothing
        } else if(!expectDelim && tokens[i].type != ',') {
            ret.push(tokens[i]);
        } else {
            throw `Malformed argument statement`;
        }
        expectDelim = !expectDelim;
    }
    return ret;
}

// Parse token array into labelled meta-instruction
function parseline(tokens: Token[]): Instruction | null {
    if(!tokens || tokens.length == 0) return null;
    if(tokens[0].type !== "INSTR") {
        throw `Statements must begin with token "INSTR", found "${tokens[0].type}" instead`;
    }

    // Convert the instruction into a meta-instruction,
    // the implementation of these structures are opaque to asm.js

    const instr : string = tokens[0].value.toLocaleLowerCase();
    switch(instr) {
        // Declare bytes
        case 'db': {
            let bytes: number[] = [];
            parseargs(tokens.slice(1, )).forEach(x => {
                if(x.type == 'NUM') {
                    bytes.push(x.value & 0xFF);
                } else if(x.type == 'STR') {
                    bytes = bytes.concat([...Buffer.from(x.value)]);
                }
            });
            bytes = bytes.concat(Array(bytes.length % 4).fill(0));
            return isa.encodebytes(bytes);
        }
        
        // All other instructions
        default: return isa.parseinstr(instr, tokens);
    }
}

// Mainly deals with blocks of code to allow jumping + refs
function parse(lines: string[]) {
    const blocks: Block[] = [];
    const symtab: { [id: string]: number } = { // For efficient lookup
        "_start": 0
    };
    let current : Block = {
        label: "_start", instrs: []
    };

    // Create new block per label
    lines.forEach(line => {
        let tokens = tokenize(line);
        if(!tokens || tokens.length == 0)
            return;
        while(tokens[0] && tokens[0].type == "LABEL") {
            var label = tokens[0].value;
            if(symtab[label] != undefined) {
                throw `Label "${label}" already exists.`
            }
            blocks.push(current);
            symtab[label] = 0;
            current = { label: label, instrs: [] };
            tokens.splice(0, 1);
        }
        if(!tokens || tokens.length == 0)
            return;
        // Bestow upon the first token, the title of INSTR
        tokens[0].type = 'INSTR';
        let instr = parseline(tokens);
        if(instr) current.instrs.push(instr);
    });
    blocks.push(current);

    // Go back and resolve symbols
    return isa.resolve(blocks, symtab);
}

function normalize(lines: string): string[] {
    return lines.match(/[^\r\n]+/g).map(x => x.trim());
}

///////////////////////////////////////////////////////////////////////////////

import { RawTextHelpFormatter, ArgumentParser } from 'argparse';
import * as fs from 'fs';
import path = require('path');
import { exit } from 'process';

// Outputs the 4 bram files
// arr: string array of 32-bit hex
// sz : total size of ram (# of 32-bit words)
function encode_bram(arr: string[], sz: number, folder: string) {
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
    fs.writeFileSync(path.join(folder, 'bram0.hex'), bram0);
    fs.writeFileSync(path.join(folder, 'bram1.hex'), bram1);
    fs.writeFileSync(path.join(folder, 'bram2.hex'), bram2);
    fs.writeFileSync(path.join(folder, 'bram3.hex'), bram3);
}

function encode_binary(arr: string[], file: string) {
    let buf = new Uint8Array(arr.length * 4);
    
    for(let i = 0; i < arr.length; i++) {
        buf[i*4 + 3] = (parseInt(arr[i], 16) >> 0) & 0xFF;
        buf[i*4 + 2] = (parseInt(arr[i], 16) >> 8) & 0xFF;
        buf[i*4 + 1] = (parseInt(arr[i], 16) >> 16) & 0xFF;
        buf[i*4 + 0] = (parseInt(arr[i], 16) >> 24) & 0xFF;
    }

    fs.writeFileSync(file, buf, {
        encoding: 'binary',
        flag: 'w+'
    });
}

const preamble =
`
   __       ____ ___               
  / /  ___ |_  /|_  |___ ____ __ _ 
 / _ \\(_-<_/_ </ __// _ \`(_-</  ' \\
/_//_/___/____/____/\\_,_/___/_/_/_/
                                   
                                   
  (c) 2020-2021 HS32 Core Authors
     Kevin Dai and Anthony Kung
`;

function main() {
    const parser = new ArgumentParser({
        description: "The HS32 Assembler.",
        formatter_class: RawTextHelpFormatter
    });
    parser.add_argument('-v', { help: "show the program's version number", action: "version" });
    parser.add_argument('-f', {
        help:
    `out - output hex and assembly to stdout, output will be ignored.\r\n` +
    `hex - output bram0.hex to bram3.hex files, output must be a folder.\r\n` +
    `bin - output to a binary file, output must be a file.`,
        choices: [ 'out', 'hex', 'bin' ],
        default: 'hex'
    })
    parser.add_argument('input', {
        help: "input file name",
        metavar: '[input]'
    });
    parser.add_argument('-o', '--output', {
        help: 'output file/folder name',
        metavar: '[output]',
        required: false,
        default: './'
    });
    const args = parser.parse_args(process.argv.slice(2));

    console.log(preamble);

    if(fs.existsSync(args.input)) {
        const prog = parse(normalize(fs.readFileSync(args.input, 'utf8')));
        const size = 1024;

        switch(args.f) {
            case 'out': {
                console.log(isa.tohexarray(prog));
                break;
            }
            case 'hex': {
                if(fs.existsSync(args.output)) {
                    if(fs.statSync(args.output).isDirectory()) {
                        encode_bram(isa.tohexarray(prog), size, args.output);
                    } else {
                        console.error('Output path is not a directory.');
                        exit(-1);
                    }
                } else {
                    console.error('Output directory does not exist.');
                    exit(-1);
                }
                break;
            }
            case 'bin': {
                if(fs.existsSync(args.output))
                    console.error('Output file exists, overwriting...');
                encode_binary(isa.tohexarray(prog), args.output);
                break;
            }
        }
    } else {
        console.error('Input file does not exist');
        exit(-1);
    }
    
    exit(0);
}

main();
