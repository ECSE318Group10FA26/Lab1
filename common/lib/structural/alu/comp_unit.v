// structural comparison unit: flag logic on a SHARED subtractor
//
//   op = 0:        FALSE   o = 0
//   op = 1 (SLT):  o = (a <  b) signed
//   op = 2 (SEQ):  o = (a == b)
//   op = 3 (SLE):  o = (a <= b) signed
//   op = 4 (SGT):  o = (a >  b) signed
//   op = 5 (SNE):  o = (a != b)
//   op = 6 (SGE):  o = (a >= b) signed
//   op = 7:        TRUE    o = 1
//   op = 8-15:     the same with unsigned ordering (op[3] = unsigned);
//                  SEQ/SNE alias (equality is sign-agnostic)
//
// This unit has no carry chain of its own: a top-level ALU shares one
// adder between the arithmetic and comparison cores. During a compare,
// drive the shared adder as a subtractor (arith_unit op = SUB) and route
// its outputs here:
//   diff = a - b          (arith o)
//   cout = its carry out  (for SUB: 1 means NO borrow)
//   ovf  = its signed overflow flag (arith v on op = SUB)
//
// The predicates fall out of those flags:
//   EQ = (diff == 0)
//   LT = sign(diff) ^ ovf   (signed)   |   ~cout   (unsigned borrow)
//   GT = ~(LT | EQ)
//
// encoding: op[2:0] is an OR mask over the three disjoint events
// {GT, EQ, LT}: every predicate is an OR of a subset (SLE = LT|EQ,
// SNE = LT|GT, ...). op[3] selects the unsigned less-than.
//
// Depends: mux, gates (and2, nor2, not1, xor2, or_2n, shift_ext)

module comp_unit #(
    // width of the datapath in bits
    parameter int N = 16,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] diff,  // a - b from the shared adder (SUB)
    input  wire         cout,  // its carry out (1 = no borrow)
    input  wire         ovf,   // its signed overflow (SUB)
    input  wire [  3:0] op,
    output wire [N-1:0] o
);
    // EQ = (diff == 0)
    wire nz;
    wire eq;

    or_2n #(
        .N(1),
        .I(N),
        .D(D)
    ) g_nz (
        .d(diff),
        .y(nz)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_eq (
        .a(nz),
        .y(eq)
    );

    // less-than: signed = sign of difference, flipped on overflow;
    // unsigned = borrow = inverted carry out
    wire lt_s;
    wire lt_u;
    wire lt;

    xor2 #(
        .N(1),
        .D(D)
    ) g_lts (
        .a(diff[N-1]),
        .b(ovf),
        .y(lt_s)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_ltu (
        .a(cout),
        .y(lt_u)
    );

    mux #(
        .N(1),
        .S(1),
        .D(D)
    ) lt_mux (
        .d  ({lt_u, lt_s}),
        .sel(op[3]),
        .y  (lt)
    );

    // GT = ~(LT | EQ)   (of the muxed, signedness-selected LT)
    wire gt;

    nor2 #(
        .N(1),
        .D(D)
    ) g_gt (
        .a(lt),
        .b(eq),
        .y(gt)
    );

    // partition: op[2:0] = OR mask over {GT, EQ, LT}
    wire [2:0] m;  // masked events, packed {GT, EQ, LT}
    wire       cmp;

    and2 #(
        .N(3),
        .D(D)
    ) g_m (
        .a(op[2:0]),
        .b({gt, eq, lt}),
        .y(m)
    );

    or_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_cmp (
        .d(m),
        .y(cmp)
    );

    // zero-extend the predicate bit onto the datapath
    shift_ext #(
        .N(1),
        .S(0),
        .W(N)
    ) g_ext (
        .w(cmp),
        .y(o)
    );
endmodule
