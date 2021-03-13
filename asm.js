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
 * @file   asm.js
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on December 31 1969, 7:00 PM
 */

// Token regex rules (for tokenization)
const tokenrules = [
    { type: "SPACE",    regex: /\s+/ },
    { type: "SHIFT",    regex: /(shr|shl|ror|shx)/ },
    { type: "(",        regex: /\(/ },
    { type: ")",        regex: /\)/ },
    { type: "[",        regex: /\[/ },
    { type: "]",        regex: /\]/ },
    { type: ",",        regex: /(?:,|<-)/ },
    { type: ":",        regex: /:/ },
    
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
]

// Reduction rules (combining multiple tokens)
const syntaxrules = [
    { type: "NUM",    rule: [ 'LIT_HEX' ], parse: x => parseInt(x[0].value.replace(/_/, ''), 16)},
    { type: "NUM",    rule: [ 'LIT_DEC' ], parse: x => parseInt(x[0].value.replace(/_/, ''), 10)},
    { type: "NUM",    rule: [ 'LIT_BIN' ], parse: x => parseInt(x[0].value.replace(/_/, ''),  2)},
    { type: "LABEL",  rule: [ 'IDENT',':' ], parse: x => x[0].value },
    { type: "SHREG",  rule: [ 'IDENT','SHIFT','NUM' ], parse: x => [ x[0].value, x[1].value, x[2].value ]},
    { type: "OFFSET", rule: [ '[','IDENT','OP','NUM',']' ], parse: x => [ x[1], x[2], x[3] ]},
    { type: "OFFSET", rule: [ '[','IDENT','OP','SHREG',']' ], parse: x => [ x[1], x[2], x[3] ]},
    { type: "OFFSET", rule: [ '[','IDENT','OP','IDENT',']' ], parse: x => [ x[1], x[2], x[3] ]},
    { type: "PTR",    rule: [ '[','IDENT',']' ], parse: x => x[1]},
    { type: "PTR",    rule: [ '[','NUM',']' ], parse: x => x[1]},
    { type: "PTR",    rule: [ '[','OP','NUM',']' ], parse: x => {
        return {
            type: "NUM",
            value: (x[1].value == '-' ? -1 : 1) * x[2].value
        }
    }},
    { type: "PTR", rule: [ 'OFFSET' ], parse: x => x[0]},
]

// A simple tokenize and reduce function
function tokenize(/** @type{string} */ input) {
    let line = input.replace(/;.*/, '').trim();
    let hasMatch = true;
    let tokens = [];
    while(hasMatch) {
        hasMatch = false;
        for(var i = 0; i < tokenrules.length; i++) {
            let match = line.match(tokenrules[i].regex);
            if(match?.length > 0 && match.index == 0) {
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
        var tmp = matchsyntax(tokens);
        hasMatch = tmp[0], tokens = tmp[1];
    }
    return tokens;
}

// Brute force match and reduce once, returning reduced array + status
function matchsyntax(/** @type{array} */ input) {
    let tokens = input;
    let hasMatch = false;
    for(var i = 0; i < syntaxrules.length; i++) {
        let rule    = syntaxrules[i].rule;
        let parsefn = syntaxrules[i].parse;

        // Given rule, find matching token sequence
        // Then combine tokens using the reduction rule

        for(var j = 0; j + rule.length-1 < tokens.length; j++) {
            if(rule.reduce((a, v, k) => a & tokens[j+k].type == v, true)) {
                let raw = tokens.slice(j, j+rule.length);
                let value = parsefn ? parsefn(raw) : raw;
                tokens.splice(j, rule.length, {
                    type: syntaxrules[i].type,
                    value: value
                });
                hasMatch = true;
                break;
            }
        }
    }
    return [ hasMatch, tokens ];
}

///////////////////////////////////////////////////////////////////////////////

const isa = require('./isa.js');

function parseargs(/** @type{array} */ tokens) {
    var ret = [];
    var expectDelim = false;
    for(var i = 0; i < tokens.length; i++) {
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
function parseline(/** @type{array} */ tokens) {
    if(!tokens || tokens.length == 0) return null;
    if(tokens[0].type !== "INSTR") {
        throw `Statements must begin with token "INSTR", found "${tokens[0].type}" instead`;
    }

    // Convert the instruction into a meta-instruction,
    // the implementation of these structures are opaque to asm.js

    let instr = tokens[0].value.toLocaleLowerCase();
    switch(instr) {
        // Declare bytes
        case 'db': {
            let bytes = [];
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
function parse(/** @type{string[]} */ lines) {
    let blocks = [];
    let symtab = { // For efficient lookup
        "_start": 0
    };
    let current = {
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
                throw new Error(`Label "${label}" already exists.`)
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

///////////////////////////////////////////////////////////////////////////////

function normalize(/** @type{string} */ lines) {
    return lines.match(/[^\r\n]+/g).map(x => x.trim());
}

code = normalize(`
; _start:
    MOV r0 <- FF00h         ; AICT base
    MOV r1 <- 68h           ; 12Mhz/115200Hz
    STR [r0+BCh] <- r1
    MOV r1 <- 0FFFh         ; Set GPIO mode out
    STR [r0+80h] <- r1
    MOV r1 <- data+17       ; We need to offset at pc-3 = 17

loop:
    LDR r2 <- [r1]
    AND r2 <- r2 & FFh
    CMP r2, 0
    BEQ end
    BL write
    ADD r1 <- r1 + 1
    B loop

end:
    MOV r2 <- 0800h     ; Set green LED
    STR [r0+84h] <- r2
    B 0

write:
    MOV r3 <- 1         ; Do TX write (badness 1000)
    STR [r0+B0h] <- r2
    STR [r0+B8h] <- r3
readtx:
    LDR r4 <- [r0+B8h]
    TST r4, 20h         ; Test TX ready
    BNE readtx          ; Loop if not zero
    MOV pc <- lr        ; Return

data: db "Hello, World!", 0h
`);

try {
    console.log(isa.tohexarray(parse(code)));
    console.log((parse(code)));
} catch(msg) {
    console.error(msg);
}
