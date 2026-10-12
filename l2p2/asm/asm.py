#!/usr/bin/env python3
# This file is partially AI generated to help create hex images
# for the test CPU for this lab
#
# It will be replaced with a non-AI version in the future
"""asm.py - tiny assembler for the l2p2 CPU (../src/cpu.v)

Converts assembly text into a hex image ($readmemh format) that
tb/cpu_tb.v pokes into the CPU's RAM words.

Usage:  python3 asm.py prog.asm [-o out.hex]
            [--bits N] [--addr-bits A] [--reg-bits R] [--imm-bits I]
            [--lanes L]

Default output: <problem>/sim/program.hex (where the testbench looks
for it), i.e. the sim/ directory next to the asm/ directory holding the
source. A listing (address, word, source) is printed to stdout.
The CPU-parameter flags default to cpu_tb's instance (8/8/2/16, 2 lane
bits); e.g. math.asm targets a 64-bit single-word instance:
--bits 64 --addr-bits 7 --imm-bits 8 --lanes 0.

    load rd, [addr]      rd = mem[addr]     (alias for buf)
    store [addr], rs     mem[addr] = rs     (alias for buf)
    mov | ldi            aliases for buf (mov rd, rs / ldi rd, #imm)
    <alu> rd, src        rd = rd OP src:    add addu sub subu and or
                         xor nand nor xnor srl sra ror sll sla rol
                         slt seq sle sgt sne sge sltu sleu sgtu sgeu
                         buf (= MOV: dst = src) not (dst = ~src)
    <alu> rd             single operand:    inc incu dec decu
                         false (rd = 0) true (rd = 1)
    bra | be | bne tgt   branch to tgt; tgt may be a label/number
                         (immediate), rN (register), or [addr] (memory);
                         be/bne test Z. jmp rs is an alias for bra rs.
    bsr tgt, flag        branch if the status flag is set;
                         flag: v, c, z, n or p
    movsr rd             rd = status register (zero-extended)
    nop

Directives:
    label:               define a label at the current word address
    .org addr            set the word address (for data placement)
    .word v[, v, ...]    emit data words (decimal, 0x.., 0b.., or label)

Comments start with ';' or '//' ('#' is the immediate prefix).
"""

import argparse
import os
import re
import sys

# CPU instance parameters (see cpu.v; these defaults match cpu_tb, and
# the --bits/--addr-bits/--reg-bits/--imm-bits/--words flags override
# them)
N_BITS = 8  # RAM word size in bits (cpu parameter N): a "short"
ADDR_BITS = 8  # RAM address bits (cpu parameter A)
REG_BITS = 2  # register-address bits (cpu parameter R)
IMM_BITS = 16  # immediate width (cpu parameter I); may exceed N_BITS:
#   immediates live in the 2**L-word fetch block, not in one RAM word
LANE_BITS = 2  # lane bits: RAM words per access = 2**L (cpu parameter L)
FETCH_WORDS = 1 << LANE_BITS
WORDS = 1 << ADDR_BITS
REGS = 1 << REG_BITS

# instruction field shifts derived from the parameters; an instruction
# is one W-word fetch block, FW = N_BITS * FETCH_WORDS bits wide
FW = N_BITS * FETCH_WORDS
OP_SHIFT = FW - 7   # 7-bit opcode at the top
ST_SHIFT = FW - 9   # 2-bit source type
DT_SHIFT = FW - 10  # 1-bit destination type
DA_SHIFT = FW - 10 - REG_BITS  # R-bit dest/src register, just below
#   the dest type (matches cpu.v's top-anchored [FW-11 -: R])
# the source field is bottom-anchored (values OR in at bit 0), SW =
# max(REG_BITS, ADDR_BITS, IMM_BITS) bits wide; IW = 10+REG_BITS+SW must
# be <= FW, and any spare bits pad between the dest and source fields
S_BITS = max(REG_BITS, ADDR_BITS, IMM_BITS)
# the access-size field sits just above the source field (bit S_BITS),
# SZ bits wide; it is absent when L = 0 (SZ = clog2(L+1))
SZ = LANE_BITS.bit_length()
SIZE_SHIFT = S_BITS


def configure(n, a, r, i, l):
    """set the CPU instance parameters (main() applies the CLI flags)"""
    global N_BITS, ADDR_BITS, REG_BITS, IMM_BITS, LANE_BITS
    global FETCH_WORDS, WORDS, REGS, FW
    global OP_SHIFT, ST_SHIFT, DT_SHIFT, DA_SHIFT, S_BITS, SZ, SIZE_SHIFT
    if not 0 <= l <= a:
        raise AsmError(f"--lanes {l} exceeds the {a} address bits (2**{a} words)")
    N_BITS, ADDR_BITS, REG_BITS, IMM_BITS, LANE_BITS = n, a, r, i, l
    FETCH_WORDS = 1 << l
    WORDS, REGS = 1 << a, 1 << r
    FW = n << l
    OP_SHIFT, ST_SHIFT, DT_SHIFT = FW - 7, FW - 9, FW - 10
    DA_SHIFT = FW - 10 - r
    S_BITS = max(r, a, i)
    SZ = l.bit_length()
    SIZE_SHIFT = S_BITS
    iw = 10 + r + SZ + S_BITS
    if FW < iw:
        raise AsmError(
            f"the instruction word ({iw} bits) does not fit the fetch block"
            f" ({n}*2**{l} = {FW} bits)"
        )

# alu_core op table (see common/lib/structural/alu/alu_core.v)
# two-operand ALU ops:  op dst, src   ->  dst = dst OP src
ALU2 = {
    "add": 0, "addu": 1, "sub": 2, "subu": 3,
    "and": 8, "or": 9, "xor": 10, "buf": 11, "nand": 12, "nor": 13,
    "xnor": 14, "not": 15,
    "srl": 16, "sra": 17, "ror": 18, "sll": 20, "sla": 21, "rol": 22,
    "slt": 33, "seq": 34, "sle": 35, "sgt": 36, "sne": 37, "sge": 38,
    "sltu": 41, "sleu": 43, "sgtu": 45, "sgeu": 46,
}
# single-operand ALU ops:  op rd
ALU1 = {
    "inc": 4, "incu": 5, "dec": 6, "decu": 7, "false": 32, "true": 39,
}
# special opcodes (nop's value is canonical; any undecoded special is a nop)
SPECIAL = {"bra": 64, "be": 65, "bne": 66, "bsr": 67, "movsr": 68, "nop": 69}
# status-register flag indices for bsr (status = {P, N, Z, C, V})
FLAGS = {"v": 0, "c": 1, "z": 2, "n": 3, "p": 4}
# aliases that share the buf/bra machinery
RENAME = {"load": "buf", "store": "buf", "mov": "buf", "ldi": "buf", "jmp": "bra"}


class AsmError(Exception):
    """assembly error, with line context in the message"""


def strip_comment(line):
    """remove a trailing // or ; comment ('#' is the immediate prefix!)"""
    pos = [p for p in (line.find(m) for m in ("//", ";")) if p != -1]
    return line[:min(pos)].strip() if pos else line.strip()


def split_args(args, lineno, n=2):
    """comma-separated operands; n = required count (None = any)"""
    parts = [a.strip() for a in args.split(",")]
    if n is not None and len(parts) != n:
        raise AsmError(f"line {lineno}: expected {n} operands, got '{args}'")
    return parts


def const(tok, lineno):
    """a literal number (no labels)"""
    try:
        return int(tok, 0)
    except ValueError:
        raise AsmError(f"line {lineno}: bad number '{tok}'")


def value(tok, labels, lineno):
    """a literal number or a label"""
    try:
        return int(tok, 0)
    except ValueError:
        pass
    if tok in labels:
        return labels[tok]
    raise AsmError(f"line {lineno}: undefined label or bad number '{tok}'")


def parse_reg(tok, lineno):
    tok = tok.strip().lower()
    if not re.fullmatch(r"r\d+", tok) or not 0 <= int(tok[1:]) < REGS:
        raise AsmError(f"line {lineno}: bad register '{tok}' (r0-r{REGS - 1})")
    return int(tok[1:])


def check_addr(addr, lineno, what="address"):
    if not 0 <= addr < WORDS:
        raise AsmError(f"line {lineno}: {what} {addr} out of range (0-{WORDS - 1})")
    return addr


def check_imm(imm, lineno):
    if not 0 <= imm < (1 << IMM_BITS):
        raise AsmError(
            f"line {lineno}: immediate {imm} out of range (0-{(1 << IMM_BITS) - 1})"
        )
    return imm


def parse_src(tok, labels, lineno):
    """source operand: register, [address] or immediate -> (type, value)"""
    tok = tok.strip()
    if tok.startswith("["):
        if not tok.endswith("]"):
            raise AsmError(f"line {lineno}: unbalanced '[', got '{tok}'")
        return (1, check_addr(value(tok[1:-1].strip(), labels, lineno), lineno))
    if tok.startswith("#"):
        tok = tok[1:].strip()
    if re.fullmatch(r"[rR]\d+", tok):
        return (0, parse_reg(tok, lineno))
    return (2, check_imm(value(tok, labels, lineno), lineno))


def parse_dest(tok, labels, lineno):
    """destination operand: register or [address] -> (type, value)"""
    tok = tok.strip()
    if tok.startswith("["):
        if not tok.endswith("]"):
            raise AsmError(f"line {lineno}: unbalanced '[', got '{tok}'")
        return (1, check_addr(value(tok[1:-1].strip(), labels, lineno), lineno))
    if tok.startswith("#"):
        raise AsmError(f"line {lineno}: an immediate can't be a destination")
    return (0, parse_reg(tok, lineno))


def parse_flag(tok, lineno):
    flag = FLAGS.get(tok.strip().lower())
    if flag is None:
        flag = const(tok, lineno)
    if not 0 <= flag <= 4:
        raise AsmError(f"line {lineno}: bad flag '{tok}' (v, c, z, n or p)")
    return flag


def parse_mnemonic(op, lineno):
    """split an optional .N size suffix (an access of N words: 1,2,4,...)
    -> (base mnemonic, log2 N)"""
    base, dot, suffix = op.partition(".")
    if not dot:
        return op, 0
    try:
        words = int(suffix, 10)
    except ValueError:
        raise AsmError(f"line {lineno}: bad size suffix '.{suffix}'")
    if words < 1 or words & (words - 1) or words > FETCH_WORDS:
        raise AsmError(
            f"line {lineno}: bad access size {words}"
            f" (a power of 2 from 1 to {FETCH_WORDS})"
        )
    return base, words.bit_length() - 1


def check_align(addr, sz, lineno):
    """a sized access must land on a 2**sz-word boundary"""
    if addr % (1 << sz):
        raise AsmError(
            f"line {lineno}: address {addr} is not {1 << sz}-word aligned"
        )


def check_size(op_has_mem, sz, lineno):
    """a size suffix needs a memory operand"""
    if sz and not op_has_mem:
        raise AsmError(f"line {lineno}: size suffix but no memory operand")


def encode(op, sz, args, labels, lineno):
    """one instruction -> its word (see cpu.v for the field layout);
    sz is the access size (log2 of the group width in words)"""
    op = RENAME.get(op, op)
    if op in ALU2:
        dst_tok, src_tok = split_args(args, lineno)
        dt, dv = parse_dest(dst_tok, labels, lineno)
        st, sv = parse_src(src_tok, labels, lineno)
        if dt == 1:
            # memory destination: the [address] lives in the source field
            # and the source register in the dest field (cpu.v constraint)
            if st != 0:
                raise AsmError(
                    f"line {lineno}: a memory destination needs a register source"
                )
            check_align(dv, sz, lineno)
            return ((ALU2[op] << OP_SHIFT) | (sz << SIZE_SHIFT)
                    | (st << ST_SHIFT) | (1 << DT_SHIFT)
                    | (sv << DA_SHIFT) | dv)
        if st == 1:
            check_align(sv, sz, lineno)
        else:
            check_size(False, sz, lineno)
        return ((ALU2[op] << OP_SHIFT) | (sz << SIZE_SHIFT)
                | (st << ST_SHIFT) | (dt << DT_SHIFT)
                | (dv << DA_SHIFT) | sv)
    if op in ALU1:
        check_size(False, sz, lineno)
        rd = parse_reg(args, lineno)
        return (ALU1[op] << OP_SHIFT) | (rd << DA_SHIFT)
    if op in ("bra", "be", "bne", "bsr"):
        check_size(False, sz, lineno)
        if op == "bsr":
            tgt_tok, flag_tok = split_args(args, lineno)
            flag = parse_flag(flag_tok, lineno)
        else:
            tgt_tok, flag = args, 0
        st, sv = parse_src(tgt_tok, labels, lineno)
        if st == 2 and sv % FETCH_WORDS:
            raise AsmError(
                f"line {lineno}: branch target {sv} is not instruction-aligned"
                f" (instructions are {FETCH_WORDS} words)"
            )
        return ((SPECIAL[op] << OP_SHIFT) | (st << ST_SHIFT)
                | ((flag >> 2) << DT_SHIFT) | ((flag & 3) << DA_SHIFT) | sv)
    if op == "movsr":
        check_size(False, sz, lineno)
        rd = parse_reg(args, lineno)
        return (SPECIAL[op] << OP_SHIFT) | (rd << DA_SHIFT)
    if op == "nop":
        check_size(False, sz, lineno)
        if args.strip():
            raise AsmError(f"line {lineno}: nop takes no operands")
        return SPECIAL["nop"] << OP_SHIFT
    raise AsmError(f"line {lineno}: unknown mnemonic '{op}'")


def emit(words, addr, word, srcline, lineno):
    if addr in words:
        raise AsmError(
            f"line {lineno}: address {addr} already used by line {words[addr][2]}"
        )
    words[addr] = (word & ((1 << N_BITS) - 1), srcline, lineno)


def assemble(text):
    """assembly text -> {address: (word, source line, lineno)}"""
    # split into (lineno, labels, mnemonic, operand string, source line)
    stmts = []
    for lineno, raw in enumerate(text.splitlines(), 1):
        line = strip_comment(raw)
        if not line:
            continue
        labs = []
        while (m := re.match(r"([A-Za-z_]\w*)\s*:", line)) is not None:
            labs.append(m.group(1))
            line = line[m.end():].strip()
        op, args = "", ""
        if line:
            parts = line.split(None, 1)
            op = parts[0].lower()
            args = parts[1] if len(parts) > 1 else ""
        stmts.append((lineno, labs, op, args, raw.strip()))

    mnemonics = set(ALU2) | set(ALU1) | set(SPECIAL) | set(RENAME)

    # pass 1: label addresses
    labels = {}
    pc = 0
    for lineno, labs, op, args, _ in stmts:
        for lab in labs:
            if lab in labels:
                raise AsmError(f"line {lineno}: duplicate label '{lab}'")
            labels[lab] = pc
        if not op:
            continue
        if op == ".org":
            pc = const(args, lineno)
        elif op == ".word":
            pc += len(split_args(args, lineno, None)) if args.strip() else 0
        else:
            base, _ = parse_mnemonic(op, lineno)
            if base not in mnemonics:
                raise AsmError(f"line {lineno}: unknown mnemonic '{op}'")
            pc += FETCH_WORDS  # an instruction is one W-word block
        if pc > WORDS:
            raise AsmError(f"line {lineno}: out of memory ({WORDS} words)")

    # pass 2: emit words
    words = {}
    pc = 0
    for lineno, _, op, args, srcline in stmts:
        if not op:
            continue
        if op == ".org":
            pc = const(args, lineno)
        elif op == ".word":
            for tok in split_args(args, lineno, None):
                emit(words, pc, value(tok, labels, lineno), srcline, lineno)
                pc += 1
        else:
            if pc % FETCH_WORDS:
                raise AsmError(
                    f"line {lineno}: instruction at word {pc} is not"
                    f" instruction-aligned ({FETCH_WORDS} words)"
                )
            base, sz = parse_mnemonic(op, lineno)
            instr = encode(base, sz, args, labels, lineno)
            # one instruction = W RAM words, the low word first (lane k
            # of the block holds instruction bits [k*N +: N])
            for lane in range(FETCH_WORDS):
                emit(words, pc, instr >> (lane * N_BITS), srcline, lineno)
                pc += 1
    return words


def main():
    ap = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    ap.add_argument("src", help="assembly source file")
    ap.add_argument(
        "-o",
        "--output",
        help="hex output file (default: <problem>/sim/program.hex, "
        "i.e. the sim/ dir next to the asm/ dir holding the source)",
    )
    ap.add_argument("--bits", type=int, default=N_BITS,
                    help="word size (cpu parameter N; default %(default)s)")
    ap.add_argument("--addr-bits", type=int, default=ADDR_BITS,
                    help="RAM address bits (cpu parameter A; default %(default)s)")
    ap.add_argument("--reg-bits", type=int, default=REG_BITS,
                    help="register-address bits (cpu parameter R; default %(default)s)")
    ap.add_argument("--imm-bits", type=int, default=IMM_BITS,
                    help="immediate width (cpu parameter I; default %(default)s)")
    ap.add_argument("--lanes", type=int, default=LANE_BITS,
                    help="lane bits: RAM words per access/fetch = 2**L "
                         "(cpu parameter L; default %(default)s)")
    args = ap.parse_args()

    with open(args.src) as f:
        text = f.read()

    try:
        configure(args.bits, args.addr_bits, args.reg_bits, args.imm_bits,
                  args.lanes)
        words = assemble(text)
    except AsmError as e:
        print(f"asm.py: error: {e}", file=sys.stderr)
        return 1

    out = args.output
    if out is None:
        prob = os.path.dirname(os.path.dirname(os.path.abspath(args.src)))
        out = os.path.join(prob, "sim", "program.hex")
    os.makedirs(os.path.dirname(out), exist_ok=True)

    digits = (N_BITS + 3) // 4  # hex digits per word
    with open(out, "w") as f:
        last = -2  # force an address marker on the first word
        for a in sorted(words):
            if a != last + 1:
                f.write(f"@{a:02x}\n")
            f.write(f"{words[a][0]:0{digits}x}\n")
            last = a

    # listing for the user: address, word, source
    print(f"# {out}")
    for a in sorted(words):
        w, srcline, lineno = words[a]
        print(f"  {a:4d}  {w:0{digits}x}  {srcline}   (line {lineno})")
    return 0


if __name__ == "__main__":
    sys.exit(main())
