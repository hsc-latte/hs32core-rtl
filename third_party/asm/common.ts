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
 * @date   Created on March 13 2021, 00:30 AM
 */

export interface TokenRule {
    type: string,
    regex: RegExp
};

export interface Token {
    type: string,
    value: any
}

export interface SyntaxRule {
    type: string,
    rule: string[],
    parse: (x: Token[]) => any
};

export interface Instruction {
    type: string,
    enc: any
};

export interface Block {
    label: string,
    instrs: Instruction[]
};