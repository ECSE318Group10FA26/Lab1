// structural CPU: 2**R registers, one RAM, PC, status register
//
//   The ALU is ALWAYS FW bits wide: the flags describe the full-width
//   result, so arithmetic on a group wraps at FW, not at the group
//   width. Status regs are also FW, so smaller width is on software to
//   implement
//
//   Status: {P, N, Z, C, V} from the ALU, updated by every register-
//   destination ALU op (Z/N/P from the result, C/V = cout/v).
//
//   instruction format:  op dst, src  (fields anchored to parameters):
//     [FW-1 -: 7]   opcode (the alu_core table + specials below)
//     [FW-8 -: 2]   source type: 0 = register, 1 = memory, 2 = immediate
//     [FW-10]       destination type: 0 = register, 1 = memory
//     [FW-11 -: R]  destination register (the SOURCE register when the
//                   destination is memory)
//     [SW +: SZ]    access size for memory operands (SZ = clog2(L+1)
//                   bits; the field is absent when L = 0)
//     [SW-1:0]      source register # / memory address / immediate value,
//                   with SW = max(R, A, I): the field must fit the widest
//                   of a register number, an address and an immediate
//                   (without immediates this is max(R, A)); R and A are
//                   independent -- R > A (more registers than RAM words)
//                   is legal, the field just grows
//   (needs R >= 2 for the BSR select, and FW >= IW = 10+R+SZ+SW so the
//    instruction fits the fetch block; spare bits pad between the dest
//    and source fields. pc is a WORD address advancing by W per
//    instruction, so branch targets must be W-aligned)
//
//   opcodes 0-63:  ALU ops (the alu_core table): dst = dst OP src
//                  (compare with SUB/SUBU: Z=1 iff dst == src)
//                  BUF and NOT take the SOURCE through the ALU, so
//                  buf = MOV (load/store/ldi are all buf forms) and
//                  not dst, src = ~src. A memory destination turns any
//                  ALU op into a read-modify-write of the mem group.
//                  Memory operands are aligned groups of 2**size words:
//                  loads are zero-padded above the group, stores write
//                  the low 2**size words.
//   opcode 64 BRA: pc = src   (immediate address, register (JMP), or
//                  memory word -- the source type picks the mode)
//   opcode 65 BE:  if Z:  pc = src
//   opcode 66 BNE: if ~Z: pc = src
//   opcode 67 BSR: if status[sel]: pc = src
//                  (sel = {dtype, daddr}: 0=V 1=C 2=Z 3=N 4=P)
//   opcode 68 MOVSR: dst = status (zero-extended; register destination)
//   others:        NOP (no side effects)
//
// Depends: alu_core, ram, regfile, mux, demux, dff_sc, gates (and2,
//          and_2n, or2, or_2n, xor_2n, not1, buf1, shift_ext)

module cpu #(
    // RAM word size (a "short"), in bits; the datapath is W words wide
    parameter int N   = 19,
    // RAM address bits: the memory holds 2**A words
    parameter int A   = 7,
    // register-address bits: 2**R registers
    parameter int R   = 2,
    // immediate width, in bits (the source field is max(R, A, I) wide;
    // it need not fit a RAM word -- immediates live in the fetch block)
    parameter int I   = A,
    // source-field width: the field holds a register number, a memory
    // address or an immediate, so it fits the widest of the three
    // (derived -- do not override)
    parameter int SW  = (R > A) ? ((R > I) ? R : I) : ((A > I) ? A : I),
    // lane bits, 0 <= L <= A: one instruction is one fetch block of
    // W = 2**L RAM words, so W*N must fit the instruction word; the
    // default is the smallest L that does, upper-bounding the size
    // field's width by clog2(A+1) (SZ depends on L, hence the bound)
    parameter int L   = $clog2((10 + R + SW + $clog2(A + 1) + N - 1) / N),
    // the rest are derived -- do not override:
    // RAM words per access: 2**L
    parameter int W   = 1 << L,
    // size-field width: memory access sizes 0..L ($clog2(1) = 0: the
    // field is absent when L = 0)
    parameter int SZ  = $clog2(L + 1),
    // minimum instruction width of the format above: 7 (opcode) +
    // 2 (source type) + 1 (dest type) + R (dest) + SZ (size) +
    // SW (source field); an instruction lives in one fetch block, so
    // the block must cover it
    parameter int IW  = 10 + R + SZ + SW,
    // datapath width (a "long"): the W-word fetch block
    parameter int FW  = W * N,
    // the RAM size input's width (a wire must be at least 1 bit)
    parameter int ZSW = (SZ > 0) ? SZ : 1,
    // gate delay, in `timescale units
    parameter int D   = 0,
    // flip-flop delay (clock-to-q), in `timescale units
    parameter int DF  = 0
) (
    input  wire       clk,
    // synchronous clear: pc, state, IR, registers and status reset to 0
    input  wire       clear,
    // synchronous clear of the RAM contents (separate: a CPU reset
    // must not wipe the program)
    input  wire       ram_clear,
    // status register contents {P, N, Z, C, V}
    output wire [4:0] status
);

    generate
        if (FW < IW || L > A) begin : g_fit
            initial $fatal(
                1,
                "cpu: bad L=%0d (N=%0d, A=%0d, IW=%0d): need 0 <= L <= A and (2**L)*N >= IW",
                L, N, A, IW
            );
        end
    endgenerate

    // ---------------- state: FETCH (0) / EXECUTE (1) ----------------
    wire state;  // 1 = EXECUTE
    wire state_n;  // 1 = FETCH (also the toggle input)

    not1 #(
        .N(1),
        .D(D)
    ) g_state_n (
        .a(state),
        .y(state_n)
    );

    dff_sc #(
        .N(1),
        .D(DF)
    ) state_reg (
        .clk  (clk),
        .clear(clear),
        .d    (state_n),
        .q    (state)
    );

    // ---------------- instruction register ----------------
    wire [FW-1:0] ir;
    wire [FW-1:0] ram_q;  // the addressed RAM block
    wire [FW-1:0] ir_d;

    mux #(
        .N(FW),
        .S(1),
        .D(D)
    ) ir_mux (
        .d  ({ram_q, ir}),  // FETCH -> load the block from RAM
        .sel(state_n),
        .y  (ir_d)
    );

    dff_sc #(
        .N(FW),
        .D(DF)
    ) ir_reg (
        .clk  (clk),
        .clear(clear),
        .d    (ir_d),
        .q    (ir)
    );

    // ---------------- instruction field aliases ----------------
    // pure wiring (no gates): names for the ir fields, anchored to the
    // parameters (top-anchored opcode/types/dest, bottom-anchored source)
    wire          special;  // ir[FW-1]:       1 = special op (not ALU)
    wire [   5:0] sop;  // ir[FW-2 -: 6]:  special-op subfield / ALU op
    wire [   1:0] stype;  // ir[FW-8 -: 2]:  source type
    wire          dtype;  // ir[FW-10]:      destination type
    wire [ R-1:0] daddr;  // ir[FW-11 -: R]: dest reg (src reg on stores)
    wire [SW-1:0] sfield;  // ir[SW-1:0]: source reg/address/immediate
    wire [ A-1:0] saddr;  // the address interpretation (low A bits)
    wire [   2:0] fsel;  // {dtype, daddr}: BSR flag select

    assign special = ir[FW-1];
    assign sop     = ir[FW-2-:6];
    assign stype   = ir[FW-8-:2];
    assign dtype   = ir[FW-10];
    assign daddr   = ir[FW-11-:R];
    assign sfield  = ir[SW-1:0];
    assign saddr   = sfield[A-1:0];
    assign fsel    = {ir[FW-10], ir[FW-11-:2]};

    // ---------------- decode ----------------
    wire is_alu;
    wire [5:0] sop_n;

    not1 #(
        .N(1),
        .D(D)
    ) g_isalu (
        .a(special),
        .y(is_alu)
    );

    not1 #(
        .N(6),
        .D(D)
    ) g_sopn (
        .a(sop),
        .y(sop_n)
    );

    // special-op decode: dec[k] = special & (sop == k)
    //   0 BRA, 1 BE, 2 BNE, 3 BSR, 4 MOVSR (NOP needs no decode: any
    //   undecoded special op has no side effects)
    // the specials are opcodes 64..68 = special=1 with sop <= 4, so
    // qualify on sop[5:3] == 0 (reusing sop_n) and demux the low bits;
    // dec8[5..7] (NOP included) are unused
    wire [4:0] dec;
    wire       sq;  // special & sop[5:3] == 0
    wire [7:0] dec8;

    and_2n #(
        .N(1),
        .I(4),
        .D(D)
    ) g_sq (
        .d({special, sop_n[5], sop_n[4], sop_n[3]}),
        .y(sq)
    );

    demux #(
        .N(1),
        .S(3),
        .D(D)
    ) g_dec (
        .d  (sq),
        .sel(sop[2:0]),
        .y  (dec8)
    );

    assign dec = dec8[4:0];

    // BUF and NOT take the source through the ALU: they are the ops
    // with sop = 6'b001?11 (11 = BUF, 15 = NOT)
    wire is_swap;

    and_2n #(
        .N(1),
        .I(6),
        .D(D)
    ) g_swap (
        .d({is_alu, sop_n[5], sop_n[4], sop[3], sop[1], sop[0]}),
        .y(is_swap)
    );

    // ---------------- control ----------------
    wire zf;  // status Z
    wire zf_n;
    wire be_t;
    wire bne_t;
    wire zt;
    wire bsr_t;
    wire bsr_flag;
    wire taken;

    not1 #(
        .N(1),
        .D(D)
    ) g_zfn (
        .a(zf),
        .y(zf_n)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_be (
        .a(dec[1]),
        .b(zf),
        .y(be_t)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_bne (
        .a(dec[2]),
        .b(zf_n),
        .y(bne_t)
    );

    or2 #(
        .N(1),
        .D(D)
    ) g_zt (
        .a(be_t),
        .b(bne_t),
        .y(zt)
    );

    // BSR: branch if the selected status bit is set
    mux #(
        .N(1),
        .S(3),
        .D(D)
    ) flag_mux (
        .d  ({3'b000, status}),  // sel: 0=V 1=C 2=Z 3=N 4=P
        .sel(fsel),
        .y  (bsr_flag)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_bsr (
        .a(dec[3]),
        .b(bsr_flag),
        .y(bsr_t)
    );

    or_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_taken (
        .d({dec[0], zt, bsr_t}),
        .y(taken)
    );

    // strobes (writes commit on the posedge ending EXECUTE)
    //   pc_we   = FETCH | taken        (~state | (state & taken) absorbs)
    //   reg_we  = EXECUTE & register-dest & (ALU | MOVSR)
    //   ram_we  = EXECUTE & memory-dest & ALU
    //   flag_we = EXECUTE & register-dest & ALU
    wire pc_we;
    wire reg_we;
    wire ram_we;
    wire flag_we;
    wire dtype_n;
    wire alu_ms;

    or2 #(
        .N(1),
        .D(D)
    ) g_pcwe (
        .a(state_n),
        .b(taken),
        .y(pc_we)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_dtn (
        .a(dtype),
        .y(dtype_n)
    );

    or2 #(
        .N(1),
        .D(D)
    ) g_ams (
        .a(is_alu),
        .b(dec[4]),
        .y(alu_ms)
    );

    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_rwe (
        .d({state, dtype_n, alu_ms}),
        .y(reg_we)
    );

    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_mwe (
        .d({state, dtype, is_alu}),
        .y(ram_we)
    );

    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_fwe (
        .d({state, dtype_n, is_alu}),
        .y(flag_we)
    );

    // ---------------- register file ----------------
    wire [FW-1:0] ra_val;  // regs[daddr]
    wire [FW-1:0] rs_val;  // regs[the source register]
    wire [FW-1:0] reg_wd;

    regfile #(
        .N (FW),
        .R (R),
        .D (D),
        .DF(DF)
    ) regs (
        .clk     (clk),
        .clear   (clear),
        .we      (reg_we),
        .w_addr  (daddr),
        .w_data  (reg_wd),
        .r_addr_a(daddr),
        .r_data_a(ra_val),
        .r_addr_b(sfield[R-1:0]),
        .r_data_b(rs_val)
    );

    // ---------------- source operand ----------------
    // the RAM returns the addressed group right-justified and
    // zero-padded, so ram_q feeds the source mux directly (the access
    // size comes from the instruction's size field -- see the RAM)
    wire [FW-1:0] imm_ext;  // zero-extended immediate
    wire [FW-1:0] src_val;  // the source operand's value

    shift_ext #(
        .N(I),
        .S(0),
        .W(FW)
    ) g_imx (
        .w(sfield[I-1:0]),
        .y(imm_ext)
    );

    mux #(
        .N(FW),
        .S(2),
        .D(D)
    ) src_mux (
        // 0 = register, 1 = memory, 2 = immediate (3: register)
        .d  ({rs_val, imm_ext, ram_q, rs_val}),
        .sel(stype),
        .y  (src_val)
    );

    // ---------------- ALU ----------------
    wire [A-1:0]  pc;
    wire [FW-1:0] pc_ext;
    wire [FW-1:0] wstep;  // the fetch stride W: pc advances one block
    wire [FW-1:0] a_norm;  // destination value (mem word on a RMW)
    wire [FW-1:0] a_swapped;  // source through the a port on BUF/NOT
    wire [FW-1:0] alu_a;
    wire [FW-1:0] alu_b;
    wire [  5:0]  alu_op;
    wire [FW-1:0] alu_o;
    wire          alu_cout;
    wire          alu_v;

    shift_ext #(
        .N(A),
        .S(0),
        .W(FW)
    ) g_pcx (
        .w(pc),
        .y(pc_ext)
    );

    buf1 #(
        .N(FW)
    ) g_wstep (
        .a(FW'(W)),
        .y(wstep)
    );

    // b operand: the source value (on memory destinations the source
    // register lives in the daddr field instead); FETCH computes
    // pc+W, so the b port gets the fetch stride
    mux #(
        .N(FW),
        .S(2),
        .D(D)
    ) b_mux (
        .d  ({ra_val, src_val, wstep, wstep}),
        .sel({state, dtype}),
        .y  (alu_b)
    );

    mux #(
        .N(FW),
        .S(1),
        .D(D)
    ) anorm_mux (
        .d  ({ram_q, ra_val}),
        .sel(dtype),
        .y  (a_norm)
    );

    mux #(
        .N(FW),
        .S(1),
        .D(D)
    ) aswap_mux (
        .d  ({alu_b, a_norm}),  // BUF/NOT: the source drives the a port
        .sel(is_swap),
        .y  (a_swapped)
    );

    mux #(
        .N(FW),
        .S(1),
        .D(D)
    ) a_mux (
        .d  ({a_swapped, pc_ext}),  // FETCH -> pc
        .sel(state),
        .y  (alu_a)
    );

    mux #(
        .N(6),
        .S(1),
        .D(D)
    ) op_mux (
        .d  ({sop, 6'd0}),  // FETCH -> ADD (pc+W), EXECUTE -> the op field
        .sel(state),
        .y  (alu_op)
    );

    alu_core #(
        .N(FW),
        .D(D)
    ) alu (
        .a   (alu_a),
        .b   (alu_b),
        .cin (1'b0),
        .op  (alu_op),
        .o   (alu_o),
        .cout(alu_cout),
        .v   (alu_v)
    );

    // ---------------- PC ----------------
    // branch target: the source operand (immediate address, register,
    // or memory word)
    wire [A-1:0] pc_in;
    wire [A-1:0] pc_d;

    mux #(
        .N(A),
        .S(1),
        .D(D)
    ) pc_mux (
        .d  ({src_val[A-1:0], alu_o[A-1:0]}),  // FETCH -> pc+W
        .sel(state),
        .y  (pc_in)
    );

    mux #(
        .N(A),
        .S(1),
        .D(D)
    ) pcw_mux (
        .d  ({pc_in, pc}),
        .sel(pc_we),
        .y  (pc_d)
    );

    dff_sc #(
        .N(A),
        .D(DF)
    ) pc_reg (
        .clk  (clk),
        .clear(clear),
        .d    (pc_d),
        .q    (pc)
    );

    // ---------------- RAM (program + data) ----------------
    // during EXECUTE the RAM addresses the source/dest field
    wire [  A-1:0] ram_addr;
    wire [ZSW-1:0] ram_size;

    mux #(
        .N(A),
        .S(1),
        .D(D)
    ) ram_addr_mux (
        .d  ({saddr, pc}),
        .sel(state),
        .y(ram_addr)
    );

    // access size: FETCH reads the whole block (L), EXECUTE the
    // instruction's size field (ir[SW +: SZ]; absent when L = 0)
    generate
        if (SZ > 0) begin : g_rsz
            mux #(
                .N(SZ),
                .S(1),
                .D(D)
            ) rsz_mux (
                .d  ({ir[SW+:SZ], SZ'(L)}),
                .sel(state),
                .y  (ram_size)
            );
        end else begin : g_norsz
            buf1 #(
                .N(1)
            ) b (
                .a(1'b0),
                .y(ram_size)
            );
        end
    endgenerate

    // a data write stores the result's low 2**size lanes into the
    // aligned group containing the address (the RAM justifies and
    // replicates)
    ram #(
        .N (N),
        .A (A),
        .L (L),
        .D (D),
        .DF(DF)
    ) mem (
        .clk (clk),
        .clear(ram_clear),
        .we  (ram_we),
        .addr(ram_addr),
        .size(ram_size),
        .d   (alu_o),
        .q   (ram_q)
    );

    // register write data: ALU result, or the status register on MOVSR
    wire [FW-1:0] status_ext;

    shift_ext #(
        .N(5),
        .S(0),
        .W(FW)
    ) g_srx (
        .w(status),
        .y(status_ext)
    );

    mux #(
        .N(FW),
        .S(1),
        .D(D)
    ) wd_mux (
        .d  ({status_ext, alu_o}),
        .sel(dec[4]),
        .y  (reg_wd)
    );

    // ---------------- status register: {P, N, Z, C, V} ----------------
    wire       nz;
    wire       z_new;
    wire       pa;  // odd parity of the ALU result
    wire       p_new;  // even parity
    wire [4:0] flags_d;

    or_2n #(
        .N(1),
        .I(FW),
        .D(D)
    ) g_nz (
        .d(alu_o),
        .y(nz)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_z (
        .a(nz),
        .y(z_new)
    );

    xor_2n #(
        .N(1),
        .I(FW),
        .D(D)
    ) g_pa (
        .d(alu_o),
        .y(pa)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_p (
        .a(pa),
        .y(p_new)
    );

    mux #(
        .N(5),
        .S(1),
        .D(D)
    ) flags_mux (
        .d  ({p_new, alu_o[FW-1], z_new, alu_cout, alu_v, status}),
        .sel(flag_we),
        .y  (flags_d)
    );

    dff_sc #(
        .N(5),
        .D(DF)
    ) status_reg (
        .clk  (clk),
        .clear(clear),
        .d    (flags_d),
        .q    (status)
    );

    assign zf = status[2];  // Z flag
endmodule
