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
 * @date   Created on March 13 2021, 00:31 AM
 */

import { Block, Instruction, Token } from './common';

const opcode_table: { [instr: string]: (tokens: Token[]) => Instruction } = {
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
const BRANCH_REGEX = /^b(?<id>eq|ne|cs|nc|ss|ns|ov|nv|ab|be|ge|lt|gt|le)?(?<link>l)?$/;

export function parseinstr(instr: string, tokens: Token[]) {
    let b = instr.match(BRANCH_REGEX);
    if(b && b.groups)
        return parse_branch(tokens, b.groups);
    if(!opcode_table[instr])
        throw `Unknown instruction "${instr}"`;
    return opcode_table[instr](tokens);
}

export function resolve(blocks: Block[],
                        symtab: { [id: string]: number }): Instruction[] {
    // Populate symtab with pc of each block
    let pc = 0;
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
    let res: Instruction[] = [];
    blocks.forEach(b => {
        b.instrs.forEach((v, i, arr) => {
            if(v?.type == 'i' && v.enc.imm16.offset != undefined) {
                let label = v.enc.imm16.offset;
                let T = v.enc.imm16.T;
                if(symtab[label] == undefined)
                    throw `Label not found "${label}"`;
                arr[i].enc.imm16 = T(symtab[label]) - pc;
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

export function tohexarray(blocks: Instruction[]): string[] {
    let res: string[] = [];
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

export function encodebytes(bytes: number[]) {
    return { type: 'b', enc: bytes };
}

///////////////////////////////////////////////////////////////////////////////

interface Placeholder {
    offset: string, T: (x: number) => Number
};

// Encodes i-type instruction
function enc_itype(op: number, rd: number, rm: number, imm16: number | Placeholder): Instruction {
    return {
        type: 'i',
        enc: { op: op, rd: rd, rm: rm, imm16: imm16 }
    }
}

// Encodes r-type instruction
function enc_rtype(op: number, rd: number, rm: number, rn: number,
                   sh5: number, dir: number, bank: number): Instruction {
    return {
        type: 'r',
        enc: { op: op, rd: rd, rm: rm, rn: rn, sh5: sh5, dir: dir, bank: bank }
    }
}

// Gets shift direction given instruction
function get_shift(name: string) {
    switch(name.toLocaleLowerCase()) {
        case 'shl': return 0;
        case 'shr': return 1;
        case 'srx': return 2;
        case 'ror': return 3;
        default: throw `Unknown shift type "${name}"`;
    }
}

// Returns register id (i.e., 0 for r0).
// If !banked, return bank = 0. Do not throw error if silent.
// Throw error if register name is invalid OR (is banked AND !banked).
// i.e., r0 is unbanked, r0u is banked.
function get_reginfo(name: string, banked?: boolean, silent?: boolean) {
    let id = name.toLocaleLowerCase();
    switch(id) {
        case 'mcr':return { reg: 12, bank: 0 };
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

// Sees if the type of tokens matches exactly with arr
// ['A', ['B', 'C']] will match sequence A, (B or C)
function match_token(tokens: Token[], arr: (string | string[])[]) {
    return tokens.length == arr.length &&
        arr.reduce((a, v, i) => {
            if(typeof v != 'string') {
                return a && v.reduce((a1, c) => a1 || tokens[i].type == c, false);
            } else {
                return a && tokens[i].type == v
            }
        }, true);
}

// Extracts register, shift and direction EVEN IF TOKEN ISN'T SHREG
function get_shreginfo(token: Token, silent?: boolean) {
    const is_shreg = token.type == 'SHREG';
    return {
        rn:  get_reginfo(is_shreg ? token.value[0] : token.value, false, silent)?.reg,
        sh5: is_shreg ? token.value[2] : 0,
        dir: is_shreg ? get_shift(token.value[1]) : 0
    }
}

// Extracts from 'OP' and 'NUM', the signed number (i.e., -6)
function get_signednum(sign: Token, num: Token): number {
    return (sign.value == '+' ? 1 : -1) * num.value;
}

// Expect token, value and undefined
function expect_token(tok: Token, sym: string) {
    if(tok.type != ',' && tok.value != sym) {
        throw `Unexpected token ${tok.value}`;
    }
}

///////////////////////////////////////////////////////////////////////////////

// Return preliminary encodings, let the caller fill in the NaN later.
function parse_addressing_mode(ptr: Token) {
    const tokens = ptr.value;
    if(ptr.type == 'OFFSET') {
        // [ reg + num ] or [ pc + ident + offset ]
        if(match_token(tokens, [ 'IDENT','OP','NUM' ])) {
            const rm = get_reginfo(tokens[0].value, false, true)?.reg;
            var num = tokens[2].value;
            if(tokens[1].value == '-') num = -num;
            if(rm == undefined)
                return enc_itype(NaN, NaN, 15, { offset: tokens[0].value, T: x => x + num });
            else
                return enc_itype(NaN, NaN, rm, num);
        }

        // [ reg + reg sh? ]
        if(match_token(tokens, [ 'IDENT','OP',['IDENT','SHREG'] ])) {
            const rm = get_reginfo(tokens[0].value, false).reg;
            const { rn, sh5, dir } = get_shreginfo(tokens[2]);
            if(tokens[1].value == '-') {
                throw 'Subtraction undefined for variant 001 instructions';
            }
            return enc_rtype(NaN, NaN, rm, rn, sh5, dir, 0);
        }
    }

    // [ num ] becomes [ pc + num ]
    if(ptr.type == 'NUM') {
        return enc_itype(NaN, NaN, 15, ptr.value);
    }

    // [ ident ] becomes [ pc + offset(ident) ] if ident is not reg
    if(ptr.type == 'IDENT') {
        const rm = get_reginfo(ptr.value, false, true)?.reg;
        if(rm == undefined)
            return enc_itype(NaN, NaN, 15, { offset: ptr.value, T: x => x });
        else
            return enc_itype(NaN, NaN, rm, 0);
    }

    throw 'Unrecognized addressing mode';
}

function parse_aluop(tokens: Token[], opt: string, sym: string, rtype: number) {
    // XXX Rd <- Rm ? sh(Rn)
    if(match_token(tokens, ['INSTR','IDENT',',','IDENT',[opt,','],['IDENT','SHREG']])) {
        expect_token(tokens[4], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const rm = get_reginfo(tokens[3].value).reg;
        const { rn, sh5, dir } = get_shreginfo(tokens[5], true);
        if(rn == undefined)
            return enc_itype(rtype + 0b100, rd, rm, { offset: tokens[5].value, T: x => x });
        else
            return enc_rtype(rtype, rd, rm, rn, sh5, dir, 0);
    }

    // XXX Rd <- Rm ? ident +/- offset
    if(match_token(tokens, ['INSTR','IDENT',',','IDENT',[opt,','],'IDENT','OP','OFFSET'])) {
        expect_token(tokens[4], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const rm = get_reginfo(tokens[3].value).reg;
        const num = get_signednum(tokens[6], tokens[7]);
        return enc_itype(rtype + 0b100, rd, rm, { offset: tokens[5].value, T: x => x + num });
    }

    // XXX Rd <- Rm ? imm
    if(match_token(tokens, ['INSTR','IDENT',',','IDENT',[opt,','],'NUM'])) {
        expect_token(tokens[4], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const rm = get_reginfo(tokens[3].value).reg;
        const imm16 = tokens[5].value;
        return enc_itype(rtype + 0b100, rd, rm, imm16);
    }

    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function parse_binary(tokens: Token[], opt: string, sym: string, rtype: number, rm?: boolean) {
    const _ = opt ? [opt, ','] : ',';
    // XXX Rd <- sh(Rn) or Rn or label
    if(match_token(tokens, ['INSTR','IDENT',_,['IDENT','SHREG']])) {
        expect_token(tokens[2], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const { rn, sh5, dir } = get_shreginfo(tokens[3], true);
        if(rn == undefined)
            return enc_itype(rtype + 0b100, rd, 0, { offset: tokens[3].value, T: x => x });
        else
            return enc_rtype(rtype, rd, rd, rn, sh5, dir, 0);
    }

    // XXX Rd <- label + offset
    if(match_token(tokens, ['INSTR','IDENT',_,'IDENT','OP','NUM'])) {
        expect_token(tokens[2], sym);
        const rd = get_reginfo(tokens[1].value, false, true)?.reg;
        const num = get_signednum(tokens[4], tokens[5]);
        return enc_itype(rtype + 0b100, rd, rd, { offset: tokens[3].value, T: x => x + num });
    }

    // XXX Rd <- imm
    if(match_token(tokens, ['INSTR','IDENT',_,'NUM'])) {
        expect_token(tokens[2], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const imm16 = tokens[3].value;
        return enc_itype(rtype + 0b100, rd, rd, imm16);
    }

    // XXX Rd <- +/-imm
    if(match_token(tokens, ['INSTR','IDENT',_,'OP','NUM'])) {
        expect_token(tokens[2], sym);
        const rd = get_reginfo(tokens[1].value).reg;
        const imm16 = get_signednum(tokens[3], tokens[4]);
        return enc_itype(rtype + 0b100, rd, rd, imm16);
    }

    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}

function parse_ldr(tokens: Token[]): Instruction {
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

function parse_str(tokens: Token[]): Instruction {
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

const branch_conds: {[id: string]: number} = {
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

function parse_branch(tokens: Token[], type: {id?: string, link?: string}): Instruction {
    let op = type.link ? 0b011_10_000 : 0b010_10_000;
    let cond = 0;
    if(type.id) {
        cond = branch_conds[type.id];
        if(cond == undefined)
            throw `Unknown branch conditional "${type.id}"`;
    }

    if(match_token(tokens, [ 'INSTR','NUM' ]))
        return enc_itype(op + cond, 0, 0, tokens[1].value);

    if(match_token(tokens, [ 'INSTR','OP','NUM' ]))
        return enc_itype(op + cond, 0, 0, get_signednum(tokens[1], tokens[2]));

    if(match_token(tokens, [ 'INSTR','IDENT' ]))
        return enc_itype(op + cond, 0, 0, { offset: tokens[1].value, T: x => x });

    if(match_token(tokens, [ 'INSTR','IDENT','OP','NUM' ])) {
        const num = get_signednum(tokens[2], tokens[3]);
        return enc_itype(op + cond, 0, 0, { offset: tokens[1].value, T: x => x + num });
    }

    console.dir(tokens, { depth: null });
    throw 'Unknown token sequence';
}
