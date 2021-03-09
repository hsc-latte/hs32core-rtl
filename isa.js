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
 * @file   isa.js
 * @author Kevin Dai <kevindai02@outlook.com>
 * @date   Created on December 31 1969, 7:00 PM
 */

// Contains all the arch-specific parsing and encoding

function parseinstr(instr, tokens) {
    if(!opcode_table[instr])
        throw `Unknown instruction "${instr}"`;
    return opcode_table[instr](tokens);
}

function resolve(blocks, symtab) {
    let pc = 0;

    // Populate symtab with pc of each block
    blocks.forEach(b => {
        symtab[b.label] = pc;
        b.instrs.forEach(v => {
            if(v.type == 'i' || v.type == 'j')
                pc += 4;
            // TODO: ...
        });
    });

    // Resolve symbol (2 loops allow for backref)
    let res = [];
    blocks.forEach(b => {
        symtab[b.label] = pc;
        b.instrs.forEach((v, i, arr) => {
            if(v?.type == 'i' && v.enc.imm16.offset != undefined) {
                let label = v.enc.imm16.offset;
                if(symtab[label] == undefined)
                    throw `Label not found "${label}"`;
                arr[i].enc.imm16 = pc - symtab[label];
            }
            if(v?.type == 'i' || v?.type == 'j')
                pc += 4;
            res.push(arr[i]);
        });
    });

    return res;
}

exports.parseinstr = parseinstr;
exports.resolve = resolve;

///////////////////////////////////////////////////////////////////////////////

// Encodes i-type instruction
function enc_itype(op, rd, rm, imm16) {
    return {
        type: 'i',
        enc: { op: op, rd: rd, rm: rm, imm16: imm16 }
    }
}

// Encodes r-type instruction
function enc_rtype(op, rd, rm, rn, sh5, dir, bank) {
    return {
        type: 'j',
        enc: { op: op, rd: rd, rm: rm, rn: rn, sh5: sh5, dir: dir, bank: bank }
    }
}

// Gets shift direction given instruction
function get_shift(/** @type{string} */ name) {
    switch(name.toLocaleLowerCase()) {
        case 'shl': return 0;
        case 'shr': return 1;
        case 'srx': return 2;
        case 'ror': return 3;
        default: throw `Unknown shift type "${name}"`;
    }
}

/**
 * Throw error if register name is invalid.
 * Throw error if register name is banked AND !banked.
 * (i.e., r0 is unbanked, r0u is banked).
 * @param {string}  name    Register name
 * @param {bool}    banked  If !banked, return bank = 0
 * @param {bool?}   silent  Supress errors
 * @returns Register id (i.e., 0 for r0)
 */
function get_reginfo(name, banked, silent) {
    let matches = name.toLocaleLowerCase().match(/^[rR](?<id>\d{1,2})$/);
    if(!matches || !matches.groups) {
        if(banked)
            throw "Unimplemented: Register banking";
        else if(!silent)
            throw `Error, unknown register "${name}"`;
    }
    return { reg: parseInt(matches.groups.id), bank: 0 };
}

/**
 * Sees if the type of tokens matches exactly with arr
 * ['A', ['B', 'C']] will match sequence A, (B or C)
 * @param {array} tokens Token sequence
 * @param {string[]} arr Token type sequence to match
 */
function match_token(tokens, arr) {
    return tokens.length == arr.length &&
        arr.reduce((a, v, i) => {
            if(typeof v != 'string') {
                return a & v.reduce((a1, c) => {
                    a1 || tokens[i].type == c
                }, false);
            } else {
                return a & tokens[i].type == v
            }
        }, true);
}

/**
 * Extracts register, shift and direction EVEN IF TOKEN ISN'T SHREG
 * @param {*} token Token to extract info from
 * @returns Object { rn:, sh5:, dir: }
 */
function get_shreginfo(token) {
    const is_shreg = token.type == 'SHREG';
    return {
        rn:  get_reginfo(is_shreg ? tokens.value[0] : tokens.value, false).reg,
        sh5: is_shreg ? tokens.value[2] : 0,
        dir: is_shreg ? get_shift(tokens.value[1]) : 0
    }
}

/**
 * Return preliminary encodings, let the caller fill in the NaN later.
 * @param {*} ptr POINTER type token
 * @returns Instruction encoding struct
 */
function parse_addressing_mode(ptr) {
    const tokens = ptr.value;
    if(ptr.type == 'OFFSET') {
        // [ reg + num ]
        if(match_token(tokens, [ 'IDENT','OP','NUM' ])) {
            const rm = get_reginfo(tokens[0].value, false).reg;
            var num = tokens[2].value;
            if(tokens[1].value == '-') num = -num;
            return enc_itype(NaN, NaN, rm, num);
        }

        // [ reg + reg sh? ]
        else if(match_token(tokens, [ 'IDENT','OP',['IDENT','SHREG'] ])) {
            const rm = get_reginfo(tokens[0].value, false).reg;
            const { rn, sh5, dir } = get_shreginfo(tokens[2]);
            if(tokens[1].value == '-') throw 'Subtraction undefined for variant 001 instructions';
            return enc_rtype(NaN, NaN, rm, rn, sh5, dir, 0);
        }
    }

    // [ num ] becomes [ pc + num ]
    else if(ptr.type == 'NUM')
        return enc_itype(NaN, NaN, 15, ptr.value);
    
    // [ ident ] becomes [ pc + offset(ident) ] if ident is not reg
    else if(ptr.type == 'IDENT') {
        const rm = get_reginfo(ptr.value, false, true).reg;
        if(rm)  return enc_itype(NaN, NaN, rm, 0);
        else    return enc_itype(NaN, NaN, 15, { offset: ptr.value });
    }
    
    throw 'Unrecognized addressing mode';
}

///////////////////////////////////////////////////////////////////////////////

const opcode_table = {
    ldr: instr_ldr,
    str: instr_str,
    mov: instr_mov,
    // TODO: ...
};

function instr_ldr(tokens) {
    // LDR Rd <- [PTR]
    if(match_token(tokens, [ 'INSTR','IDENT',',','PTR' ])) {
        let enc = parse_addressing_mode(tokens[3].value);
        enc.enc.rd = get_reginfo(tokens[1].value, false).reg;
        if(enc.type == 'i') enc.enc.op = 0b000_10_100;
        if(enc.type == 'j') enc.enc.op = 0b000_10_001;
        return enc;
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function instr_str(tokens) {
    // STR [PTR] <- Rd
    if(!match_token(tokens, [ 'INSTR','PTR',',','IDENT' ])) {
        let enc = parse_addressing_mode(tokens[2].value);
        enc.enc.rd = get_reginfo(tokens[3].value, false).reg;
        if(enc.type == 'i') enc.enc.op = 0b001_10_100;
        if(enc.type == 'j') enc.enc.op = 0b001_10_001;
        return enc;
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function instr_mov(tokens) {
    // MOV Rd <- sh(Rn) or Rn
    if(match_token(tokens, ['INSTR','IDENT',',',['IDENT','SHREG']])) {
        const rd = get_reginfo(tokens[1].value);
        const { rn, sh5, dir } = get_shreginfo(tokens[3]);
        return enc_rtype(0b001_00_000, rd, 0, rn, sh5, dir, 0);
    }
    // MOV Rd <- imm
    if(match_token(tokens, ['INSTR','IDENT',',','NUM'])) {
        const rd = get_reginfo(tokens[1]);
        const imm16 = tokens[3].value;
        return enc_itype(0b001_00_100, rd, 0, imm16);
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

// TODO: ...
