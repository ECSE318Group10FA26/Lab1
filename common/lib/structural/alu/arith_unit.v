// structural ALU arithmetic core: add/subtract/increment/decrement
//
//   op = 0 (ADD):  cout, o = a + b + cin, v = signed overflow
//   op = 1 (ADDU): cout, o = a + b + cin, v = unsigned overflow (carry out)
//   op = 2 (SUB):  cout, o = a - b,       v = signed overflow
//                  (cin is ignored; cout = 1 means NO borrow)
//   op = 3 (SUBU): cout, o = a - b,       v = unsigned underflow (borrow)
//   op = 4 (INC):  cout, o = a + 1,       v = signed overflow
//   op = 5 (INCU): cout, o = a + 1,       v = unsigned overflow (carry out)
//   op = 6 (DEC):  cout, o = a - 1,       v = signed overflow
//                  (cout = 1 means NO borrow)
//   op = 7 (DECU): cout, o = a - 1,       v = unsigned underflow (borrow)
//                  (b and cin are ignored on the INC/DEC ops)
//
// v = overflow flag of the result, signed or unsigned per op[0].
//     Signedness does not change the sum bits, only the meaning of the flag.
//
// v calculation:
//   v = op[0] ? v_unsigned : v_signed, where
//
//   v_signed = (a[N-1] == b_op[N-1]) & (o[N-1] != a[N-1])
//     signed overflow needs same-sign addends and an opposite-sign sum.
//     b_op is the addend the carry chain actually sees (b or the forced
//     INC/DEC constant, inverted on SUB), so one expression covers
//     every operation: a - b overflows exactly when a and b differ in
//     sign, i.e. when a and ~b agree.
//
//   v_unsigned = cout ^ sub
//     ADD/INC: unsigned overflow is the carry out of the MSB. SUB/DEC:
//     the chain computes a + ~b + 1, whose carry out is 1 exactly when
//     a >= b (NOT borrow), so unsigned underflow is ~cout.
//
// encoding: op[1] subtracts, op[0] selects the unsigned flag, op[2]
// ignores b and adds/subtracts 1 instead (the +-1 rides the same carry
// chain through the ADD path: b forced to 0 with the +1 injected
// through the carry-in on INC, b forced to all-ones (-1) on DEC). A
// top-level ALU combines this core with the logic/shift/compare cores,
// muxing the core outputs by the upper op bits.
//
// Depends: lookahead_adder, mux, gates (and2, or2, xor2, not1)

module arith_unit #(
    // width of the datapath in bits
    parameter int N = 16,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire         cin,
    input  wire [  2:0] op,
    output wire [N-1:0] o,
    output wire         cout,
    output wire         v
);
    // INC/DEC (op[2]) ignore b and ride the same carry chain with a
    // forced operand, both through the ADD path: b = 0 with the +1
    // injected through the carry-in on INC (a + 0 + 1), b = all-ones
    // (-1) with cin = 0 on DEC. Routing DEC through ADD rather than
    // SUB with b = 1 keeps the addend's sign bit honest at N = 1,
    // where 1 == -1 and the two would be indistinguishable.
    wire [N-1:0] b_used;

    mux #(
        .N(N),
        .S(1),
        .D(D)
    ) b_mux (
        .d  ({{N{op[1]}}, b}),  // 0 on INC, all-ones on DEC
        .sel(op[2]),
        .y  (b_used)
    );

    // subtract: invert b and inject the +1 through the carry-in, so one
    // carry chain adds or subtracts:
    //   a - b = a + ~b + 1
    wire         op2_n;
    wire         sub;  // invert b on SUB only (DEC adds its constant)
    wire [N-1:0] b_op;
    wire         c_in;

    not1 #(
        .N(1),
        .D(D)
    ) g_op2_n (
        .a(op[2]),
        .y(op2_n)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_sub (
        .a(op[1]),
        .b(op2_n),
        .y(sub)
    );

    xor2 #(
        .N(N),
        .D(D)
    ) g_binv (
        .a(b_used),
        .b({N{sub}}),
        .y(b_op)
    );

    // carry-in: cin on ADD, forced 1 on SUB and INC, forced 0 on DEC:
    //   c_in = (cin & ~op[2]) | (op[1] ^ op[2])
    wire cin_add;
    wire cdir;

    xor2 #(
        .N(1),
        .D(D)
    ) g_cdir (
        .a(op[1]),
        .b(op[2]),
        .y(cdir)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_ccin (
        .a(cin),
        .b(op2_n),
        .y(cin_add)
    );

    or2 #(
        .N(1),
        .D(D)
    ) g_cin (
        .a(cin_add),
        .b(cdir),
        .y(c_in)
    );

    // the adder drives the outputs directly
    lookahead_adder #(
        .N(N),
        .D(D)
    ) addsub (
        .addend(a),
        .augend(b_op),
        .cin   (c_in),
        .result(o),
        .cout  (cout)
    );

    // signed overflow = sign of a differs from sign of the sum while the
    // addends' signs agree; b_op is the addend the carry chain actually
    // sees, so this covers subtraction as well as addition
    wire sdiff;  // a[N-1] ^ o[N-1]
    wire seq_n;  // a[N-1] ^ b_op[N-1]
    wire seq;
    wire v_signed;
    wire v_unsigned;

    xor2 #(
        .N(1),
        .D(D)
    ) g_sdiff (
        .a(a[N-1]),
        .b(o[N-1]),
        .y(sdiff)
    );

    xor2 #(
        .N(1),
        .D(D)
    ) g_seq (
        .a(a[N-1]),
        .b(b_op[N-1]),
        .y(seq_n)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_seqn (
        .a(seq_n),
        .y(seq)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_vs (
        .a(sdiff),
        .b(seq),
        .y(v_signed)
    );

    // unsigned overflow = carry out on add; the carry chain reports
    // NOT borrow on subtract, so invert it
    xor2 #(
        .N(1),
        .D(D)
    ) g_vu (
        .a(cout),
        .b(op[1]),
        .y(v_unsigned)
    );

    // flag: op[0] muxes signed/unsigned overflow
    mux #(
        .N(1),
        .S(1),
        .D(D)
    ) v_mux (
        .d  ({v_unsigned, v_signed}),
        .sel(op[0]),
        .y  (v)
    );
endmodule
