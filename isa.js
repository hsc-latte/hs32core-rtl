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

const opcode_table = {
    ldr:    parse_ldr,
    str:    parse_str,
    mov:    (tokens) => parse_binary(tokens, null, null, 0b001_00_000),
    add:    (tokens) => parse_aluop(tokens, 'OP', '+', 0b010_00_000),
    addc:   (tokens) => parse_aluop(tokens, 'OP', '+', 0b010_00_001),
    sub:    (tokens) => parse_aluop(tokens, 'OP', '-', 0b011_00_000),
    subc:   (tokens) => parse_aluop(tokens, 'OP', '-', 0b011_00_010),
    and:    (tokens) => parse_aluop(tokens, 'OPL', '&', 0b100_00_000),
    or:     (tokens) => parse_aluop(tokens, 'OPL', '|', 0b101_00_000),
    xor:    (tokens) => parse_aluop(tokens, 'OPL', '^', 0b110_00_000),
    cmp:    (tokens) => parse_binary(tokens, null, null, 0b011_01_000),
    tst:    (tokens) => parse_binary(tokens, null, null, 0b100_01_000),

    // TODO: RSUB, MUL, RSUBC, BIC, INT
};

function parseinstr(instr, tokens) {
    let b = instr.match(/^b(?<id>eq|ne|cs|nc|ss|ns|ov|nv|ab|be|ge|lt|gt|le)?(?<link>l)?$/);
    if(b && b.groups)
        return parse_branch(tokens, b.groups);
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
            if(v.type == 'i' || v.type == 'r')
                pc += 4;
            else if(v.type == 'b')
                pc += v.enc.length;
        });
    });

    pc = 0;

    // Resolve symbol (2 loops allow for backref)
    let res = [];
    blocks.forEach(b => {
        b.instrs.forEach((v, i, arr) => {
            if(v?.type == 'i' && v.enc.imm16.offset != undefined) {
                let label = v.enc.imm16.offset;
                let f = v.enc.imm16.f;
                if(symtab[label] == undefined)
                    throw `Label not found "${label}"`;
                arr[i].enc.imm16 = f(symtab[label]) - pc;
            }
            if(v?.type == 'i' || v?.type == 'r')
                pc += 4;
            else if(v.type == 'b')
                pc += v.enc.length;
            res.push(arr[i]);
        });
    });

    return res;
}

function tohexarray(blocks) {
    let res = [];
    blocks.forEach(b => {
        if(b.type == 'i') {
            res.push(((
                ((b.enc.op & 0xFF) << 24) |
                ((b.enc.rd & 0x0F) << 20) |
                ((b.enc.rm & 0x0F) << 16) |
                ((b.enc.imm16 >>> 0) & 0xFFFF)
            ) >>> 0).toString(16).padStart(8,'0'));
        } else if(b.type == 'r') {
            res.push(((
                ((b.enc.op & 0xFF) << 24) |
                ((b.enc.rd & 0x0F) << 20) |
                ((b.enc.rm & 0x0F) << 16) |
                ((b.enc.rn & 0x0F) << 12) |
                ((b.enc.sh5 & 0x1F) << 7) |
                ((b.enc.dir & 0x03) << 5)
            ) >>> 0).toString(16).padStart(8,'0'));
        } else if(b.type == 'b') {
            for(var i = 0; i < b.enc.length; i += 4) {
                res.push(((
                    (b.enc[i] << 24) | (b.enc[i+1] << 16) |
                    (b.enc[i+2] << 8) | (b.enc[i+3])
                ) >>> 0).toString(16).padStart(8,'0'));
            }
        }
    });
    return res;
}

function encodebytes(bytes) {
    return { type: 'b', enc: bytes };
}

exports.parseinstr = parseinstr;
exports.resolve = resolve;
exports.tohexarray = tohexarray;
exports.encodebytes = encodebytes;

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
        type: 'r',
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
    let id = name.toLocaleLowerCase();
    switch(id) {
        case 'sp': return { reg: 13, bank: 0 };
        case 'lr': return { reg: 14, bank: 0 };
        case 'pc': return { reg: 15, bank: 0 };
    }
    let matches = id.match(/^[rR](?<id>\d{1,2})$/);
    if(!matches || !matches.groups) {
        if(banked)
            throw "Unimplemented: Register banking";
        else if(!silent)
            throw `Error, unknown register "${name}"`;
        return undefined;
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
                return a && v.reduce((a1, c) =>
                    a1 || tokens[i].type == c
                , false);
            } else {
                return a && tokens[i].type == v
            }
        }, true);
}

/**
 * Extracts register, shift and direction EVEN IF TOKEN ISN'T SHREG
 * @param {*} token Token to extract info from
 * @returns Object { rn:, sh5:, dir: }
 */
function get_shreginfo(token, silent) {
    const is_shreg = token.type == 'SHREG';
    return {
        rn:  get_reginfo(is_shreg ? token.value[0] : token.value, false, silent)?.reg,
        sh5: is_shreg ? token.value[2] : 0,
        dir: is_shreg ? get_shift(token.value[1]) : 0
    }
}

///////////////////////////////////////////////////////////////////////////////

/**
 * Return preliminary encodings, let the caller fill in the NaN later.
 * @param {*} ptr POINTER type token
 * @returns Instruction encoding struct
 */
function parse_addressing_mode(ptr) {
    const tokens = ptr.value;
    if(ptr.type == 'OFFSET') {
        // [ reg + num ] or [ pc + ident + offset ]
        if(match_token(tokens, [ 'IDENT','OP','NUM' ])) {
            const rm = get_reginfo(tokens[0].value, false, true)?.reg;
            var num = tokens[2].value;
            if(tokens[1].value == '-') num = -num;
            if(rm == undefined) return enc_itype(NaN, NaN, 15, { offset: rm, f: x => x + num });
            else                return enc_itype(NaN, NaN, rm, num);
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
        const rm = get_reginfo(ptr.value, false, true)?.reg;
        if(rm == undefined) return enc_itype(NaN, NaN, 15, { offset: ptr.value, f: x => x });
        else                return enc_itype(NaN, NaN, rm, 0);
    }
    console.dir(ptr, { depth: null });
    throw 'Unrecognized addressing mode';
}

/**
 * Encodes an ALU instruction
 * @param {*} tokens    Input token sequence
 * @param {*} opt       Operation token type
 * @param {*} sym       Operation token symbol value
 * @param {*} rtype     rtype opcode, itype is just rtype | 0b100
 * @returns Fully encoded instruction
 */
function parse_aluop(tokens, opt, sym, rtype) {
    // XXX Rd <- Rm ? sh(Rn)
    if(match_token(tokens, ['INSTR','IDENT',',','IDENT',[opt,','],['IDENT','SHREG']])) {
        if(tokens[4].value != sym) {
            throw `Unexpected token ${tokens[4].value}`;
        }
        const rd = get_reginfo(tokens[1].value).reg;
        const rm = get_reginfo(tokens[3].value).reg;
        const { rn, sh5, dir } = get_shreginfo(tokens[5]);
        return enc_rtype(rtype, rd, rm, rn, sh5, dir, 0);
    }
    // XXX Rd <- Rm ? imm
    if(match_token(tokens, ['INSTR','IDENT',',','IDENT',[opt,','],'NUM'])) {
        if(tokens[4].value != sym) {
            throw `Unexpected token ${tokens[4].value}`;
        }
        const rd = get_reginfo(tokens[1].value).reg;
        const rm = get_reginfo(tokens[3].value).reg;
        const imm16 = tokens[5].value;
        return enc_itype(rtype + 0b100, rd, rm, imm16);
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function parse_binary(tokens, delim, sym, rtype) {
    const mydelim = delim ? [delim, ','] : ',';
    // XXX Rd <- sh(Rn) or Rn or label
    if(match_token(tokens, ['INSTR','IDENT',mydelim,['IDENT','SHREG']])) {
        if(delim && tokens[2].value != sym) {
            throw `Unexpected token ${tokens[2].value}`;
        }
        const rd = get_reginfo(tokens[1].value).reg;
        const { rn, sh5, dir } = get_shreginfo(tokens[3], true);
        if(rn == undefined) return enc_itype(rtype, rd, 0, { offset: tokens[3].value, f:x => x });
        else                return enc_rtype(rtype, rd, 0, rn, sh5, dir, 0);
    }
    // XXX Rd <- label + offset
    if(match_token(tokens, ['INSTR','IDENT',mydelim,'IDENT','OP','NUM'])) {
        if(delim && tokens[2].value != sym) {
            throw `Unexpected token ${tokens[2].value}`;
        }
        const rd = get_reginfo(tokens[1].value, false, true)?.reg;
        const num = (tokens[4].value == '+' ? 1 : -1) * tokens[5].value;
        return enc_itype(rtype, rd, 0, { offset: tokens[3].value, f:x => x + num });
    }
    // XXX Rd <- imm
    if(match_token(tokens, ['INSTR','IDENT',mydelim,'NUM'])) {
        if(delim && tokens[2].value != sym) {
            throw `Unexpected token ${tokens[2].value}`;
        }
        const rd = get_reginfo(tokens[1].value).reg;
        const imm16 = tokens[3].value;
        return enc_itype(rtype + 0b100, rd, 0, imm16);
    }
    // XXX Rd <- +/-imm
    if(match_token(tokens, ['INSTR','IDENT',mydelim,'OP','NUM'])) {
        if(delim && tokens[2].value != sym) {
            throw `Unexpected token ${tokens[2].value}`;
        }
        const rd = get_reginfo(tokens[1].value).reg;
        const imm16 = (tokens[3].value == '+' ? 1 : -1) * tokens[4].value;
        return enc_itype(rtype + 0b100, rd, 0, imm16);
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function parse_ldr(tokens) {
    // LDR Rd <- [PTR]
    if(match_token(tokens, [ 'INSTR','IDENT',',','PTR' ])) {
        let enc = parse_addressing_mode(tokens[3].value);
        enc.enc.rd = get_reginfo(tokens[1].value, false).reg;
        if(enc.type == 'i') enc.enc.op = 0b000_10_100;
        if(enc.type == 'r') enc.enc.op = 0b000_10_001;
        return enc;
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function parse_str(tokens) {
    // STR [PTR] <- Rd
    if(match_token(tokens, [ 'INSTR','PTR',',','IDENT' ])) {
        let enc = parse_addressing_mode(tokens[1].value);
        enc.enc.rd = get_reginfo(tokens[3].value, false).reg;
        if(enc.type == 'i') enc.enc.op = 0b001_10_100;
        if(enc.type == 'r') enc.enc.op = 0b001_10_001;
        return enc;
    }
    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

const branch_conds = {
    eq: 1,
    ne: 2,
    cs: 3,
    nc: 4,
    ss: 5,
    ns: 6,
    ov: 7,
    nv: 8,
    ab: 9,
    be: 10,
    ge: 11,
    lt: 12,
    gt: 13,
    le: 14,
}

function parse_branch(tokens, type) {
    let op = type.link ? 0b011_10_000 : 0b010_10_000;
    let cond = 0;
    if(type.id) {
        cond = branch_conds[type.id];
        if(cond == undefined)
            throw `Unknown branch conditional "${type.id}"`;
    }

    if(match_token(tokens, [ 'INSTR','NUM' ])) {
        return enc_itype(op + cond, 0, 0, tokens[1].value);
    }

    if(match_token(tokens, [ 'INSTR','OP','NUM' ])) {
        return enc_itype(op + cond, 0, 0, (tokens[1].value == '+' ? 1 : -1) * tokens[2].value);
    }

    if(match_token(tokens, [ 'INSTR','IDENT' ])) {
        return enc_itype(op + cond, 0, 0, { offset: tokens[1].value, f: x => x });
    }

    if(match_token(tokens, [ 'INSTR','IDENT','OP','NUM' ])) {
        const num = (tokens[2].value == '+' ? 1 : -1) * tokens[3].value;
        return enc_itype(op + cond, 0, 0, { offset: tokens[1].value, f: x => x + num });
    }

    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}