// structural bitwise logic unit: and/or/xor/buf and their complements
//
//   sel = 0 (AND):  y = a & b     sel = 4 (NAND): y = ~(a & b)
//   sel = 1 (OR):   y = a | b     sel = 5 (NOR):  y = ~(a | b)
//   sel = 2 (XOR):  y = a ^ b     sel = 6 (XNOR): y = ~(a ^ b)
//   sel = 3 (BUF):  y = a         sel = 7 (NOT):  y = ~a
//         (b is ignored on BUF/NOT)
//
// encoding: sel[1:0] selects the base function, sel[2] inverts it
// (NOT is just the inverted identity)
//
// Depends: mux, gates (and2, or2, xor2, buf1)

module logic_unit #(
    // data width of the operands, in bits
    parameter int N = 16,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    input  wire [  2:0] sel,
    output wire [N-1:0] y
);
    wire [N-1:0] and_o;
    wire [N-1:0] or_o;
    wire [N-1:0] xor_o;
    wire [N-1:0] buf_o;

    and2 #(
        .N(N),
        .D(D)
    ) g_and (
        .a(a),
        .b(b),
        .y(and_o)
    );

    or2 #(
        .N(N),
        .D(D)
    ) g_or (
        .a(a),
        .b(b),
        .y(or_o)
    );

    xor2 #(
        .N(N),
        .D(D)
    ) g_xor (
        .a(a),
        .b(b),
        .y(xor_o)
    );

    buf1 #(
        .N(N)
    ) g_buf (
        .a(a),
        .y(buf_o)
    );

    // base function
    wire [N-1:0] base;

    mux #(
        .N(N),
        .S(2),
        .D(D)
    ) out_mux (
        .d  ({buf_o, xor_o, or_o, and_o}),
        .sel(sel[1:0]),
        .y  (base)
    );

    // sel[2] inverts the base function: nand/nor/xnor/not
    xor2 #(
        .N(N),
        .D(D)
    ) g_inv (
        .a(base),
        .b({N{sel[2]}}),
        .y(y)
    );
endmodule
