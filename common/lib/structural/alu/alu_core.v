// structural ALU: arithmetic, logic, shift and compare cores on one
// datapath, sharing ONE carry chain (the arith core doubles as the
// comparator's subtractor)
//
//   op =  0.. 7  ADD  ADDU SUB SUBU       (arith_unit; cout/v = its flags)
//                  INC  INCU DEC DECU
//   op =  8..15  AND  OR   XOR BUF        (logic_unit; cout=v=0)
//                  NAND NOR  XNOR NOT
//   op = 16..31  SRL  SRA  ROR -          (shift_unit; shamt = b[lgN-1:0];
//                  SLL  SLA  ROL -          cout=v=0; op[3]=1 aliases)
//   op = 32..63  FALSE SLT SEQ SLE        (comp_unit on the shared
//                  SGT  SNE SGE TRUE        subtractor; cout=v=0)
//                + unsigned variants at op[3]=1 (SLTU/SLEU/SGTU/SGEU);
//                  op[4]=1 aliases
//
// encoding: op[5:3] selects the core (000 arith, 001 logic, 01x shift,
// 1xx comp) and the low bits map DIRECTLY onto each core's native
// function field: op[2:0] = arith/logic/shift fn, op[3:0] = comp mask
// -- no translation logic.
//
// Depends: arith_unit, logic_unit, shift_unit, comp_unit, mux,
//          gates (and2, and_2n, or2, not1)

module alu_core #(
    // width of the datapath in bits
    parameter int N = 16,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire         cin,
    input  wire [  5:0] op,
    output wire [N-1:0] o,
    output wire         cout,
    output wire         v
);
    // shift-amount width
    localparam int LG = (N > 1) ? $clog2(N) : 1;

    // the shared adder subtracts during compare ops (op[5] = comp region)
    wire [2:0] arith_op;

    mux #(
        .N(3),
        .S(1),
        .D(D)
    ) arith_op_mux (
        .d  ({3'b010, op[2:0]}),  // comp region -> SUB
        .sel(op[5]),
        .y  (arith_op)
    );

    // arithmetic core (doubles as the comparator's subtractor)
    wire [N-1:0] arith_o;
    wire         arith_cout;
    wire         arith_v;

    arith_unit #(
        .N(N),
        .D(D)
    ) arith (
        .a   (a),
        .b   (b),
        .cin (cin),
        .op  (arith_op),
        .o   (arith_o),
        .cout(arith_cout),
        .v   (arith_v)
    );

    // logic core
    wire [N-1:0] logic_o;

    logic_unit #(
        .N(N),
        .D(D)
    ) logic_ (
        .a  (a),
        .b  (b),
        .sel(op[2:0]),
        .y  (logic_o)
    );

    // shift core: shift amount comes from b's low bits
    wire [N-1:0] shift_o;

    shift_unit #(
        .N(N),
        .D(D)
    ) shift (
        .a    (a),
        .shamt(b[LG-1:0]),
        .op   (op[2:0]),
        .o    (shift_o)
    );

    // compare core: flag logic on the shared subtractor
    wire [N-1:0] comp_o;

    comp_unit #(
        .N(N),
        .D(D)
    ) comp (
        .diff(arith_o),
        .cout(arith_cout),
        .ovf (arith_v),
        .op  (op[3:0]),
        .o   (comp_o)
    );

    // core select decode: sel = 00 arith, 01 logic, 10 shift, 11 comp
    //   sel[1] = op[4] | op[5]
    //   sel[0] = op[5] | (op[3] & ~op[4] & ~op[5])
    wire [1:0] sel;
    wire       op3_n;
    wire       op4_n;
    wire       op5_n;
    wire       sel0_t;
    wire       arith_sel;

    not1 #(
        .N(1),
        .D(D)
    ) g_op3_n (
        .a(op[3]),
        .y(op3_n)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_op4_n (
        .a(op[4]),
        .y(op4_n)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_op5_n (
        .a(op[5]),
        .y(op5_n)
    );

    or2 #(
        .N(1),
        .D(D)
    ) g_sel1 (
        .a(op[4]),
        .b(op[5]),
        .y(sel[1])
    );

    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_sel0_t (
        .d({op[3], op4_n, op5_n}),
        .y(sel0_t)
    );

    or2 #(
        .N(1),
        .D(D)
    ) g_sel0 (
        .a(op[5]),
        .b(sel0_t),
        .y(sel[0])
    );

    // flags: the arithmetic flags on arith ops, 0 otherwise
    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_asel (
        .d({op3_n, op4_n, op5_n}),
        .y(arith_sel)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_cout (
        .a(arith_cout),
        .b(arith_sel),
        .y(cout)
    );

    and2 #(
        .N(1),
        .D(D)
    ) g_v (
        .a(arith_v),
        .b(arith_sel),
        .y(v)
    );

    // result mux over the four cores
    mux #(
        .N(N),
        .S(2),
        .D(D)
    ) out_mux (
        .d  ({comp_o, shift_o, logic_o, arith_o}),
        .sel(sel),
        .y  (o)
    );
endmodule
