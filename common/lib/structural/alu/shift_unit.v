// structural barrel shifter: logical/arithmetic shifts and rotates
//
//   op = 0 (SRL): o = a >>  shamt   (zero fill)
//   op = 1 (SRA): o = a >>> shamt   (sign fill)
//   op = 2 (ROR): o = a ror shamt   (wrap)
//   op = 3:       alias of ROR
//   op = 4 (SLL): o = a <<  shamt   (zero fill)
//   op = 5 (SLA): alias of SLL      (arithmetic left == logical left)
//   op = 6 (ROL): o = a rol shamt   (wrap)
//   op = 7:       alias of ROL
//
// encoding: op[2] = left, op[1] = rotate, op[0] = arithmetic (SRA only)
//
// structure: left ops reverse the operand, run the right shifter and
// reverse back (rol/sll = rev(ror/srl(rev))); the right shifter is
// ceil(log2(N)) mux stages, stage k shifting by 2**k with a selectable
// fill: zero, sign (SRA), or wraparound (rotate). Shift amounts >= N
// produce all-fill; rotates wrap modulo N.
//
// Depends: mux, bit_rev, gates (and2, and_2n, not1, buf1)

module shift_unit #(
    // width of the datapath in bits
    parameter int N = 16,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [                      N-1:0] a,
    input  wire [(N > 1 ? $clog2(N) : 1)-1:0] shamt,
    input  wire [                        2:0] op,
    output wire [                      N-1:0] o
);
    // number of barrel stages (0 for N=1)
    localparam int LG = (N > 1) ? $clog2(N) : 0;

    // op decode: SRA (op == 1) is the only sign-filling op
    wire op1_n;
    wire op2_n;
    // True if op is specifically SRA
    wire arith;

    not1 #(
        .N(1),
        .D(D)
    ) g_op1_n (
        .a(op[1]),
        .y(op1_n)
    );

    not1 #(
        .N(1),
        .D(D)
    ) g_op2_n (
        .a(op[2]),
        .y(op2_n)
    );

    and_2n #(
        .N(1),
        .I(3),
        .D(D)
    ) g_arith (
        .d({op[0], op1_n, op2_n}),
        .y(arith)
    );

    genvar k;
    generate
        if (N == 1) begin : g_n1
            // single bit: rotates and SRA are the identity (wraparound /
            // sign fill reproduce the bit); a nonzero logical shift
            // shifts the only bit out.
            //   kill = shamt nonzero & ~rotate & ~arith
            wire arith_n;
            wire kill;
            wire kill_n;

            not1 #(
                .N(1),
                .D(D)
            ) g_arith_n (
                .a(arith),
                .y(arith_n)
            );

            and_2n #(
                .N(1),
                .I(3),
                .D(D)
            ) g_kill (
                .d({shamt[0], op1_n, arith_n}),
                .y(kill)
            );

            not1 #(
                .N(1),
                .D(D)
            ) g_kill_n (
                .a(kill),
                .y(kill_n)
            );

            and2 #(
                .N(1),
                .D(D)
            ) g_o (
                .a(a[0]),
                .b(kill_n),
                .y(o)
            );
        end else begin : g_barrel
            // direction adjustment: reverse the operand for left ops
            wire [N-1:0] a_rev;
            wire [N-1:0] din;

            bit_rev #(
                .N(N)
            ) rev_in (
                .a(a),
                .y(a_rev)
            );

            mux #(
                .N(N),
                .S(1),
                .D(D)
            ) in_mux (
                .d  ({a_rev, a}),
                .sel(op[2]),
                .y  (din)
            );

            // barrel stages: stage k shifts right by 2**k when shamt[k]
            wire [(LG+1)*N-1:0] chain;

            buf1 #(
                .N(N)
            ) seed (
                .a(din),
                .y(chain[0+:N])
            );

            for (k = 0; k < LG; k = k + 1) begin : g_stage
                // shift amount of this stage
                localparam int S = 1 << k;

                // fill bit: operand sign on SRA, zero otherwise
                wire fill;

                and2 #(
                    .N(1),
                    .D(D)
                ) g_fill (
                    .a(arith),
                    .b(chain[k*N+N-1]),
                    .y(fill)
                );

                // top S bits of the shifted word: wraparound on rotate,
                // fill otherwise
                wire [S-1:0] hi;

                mux #(
                    .N(S),
                    .S(1),
                    .D(D)
                ) fill_mux (
                    .d  ({chain[k*N+:S], {S{fill}}}),
                    .sel(op[1]),
                    .y  (hi)
                );

                // shift by 2**k when the amount bit is set
                mux #(
                    .N(N),
                    .S(1),
                    .D(D)
                ) shift_mux (
                    .d  ({{hi, chain[k*N+S+:N-S]}, chain[k*N+:N]}),
                    .sel(shamt[k]),
                    .y  (chain[(k+1)*N+:N])
                );
            end

            wire [N-1:0] dout;

            buf1 #(
                .N(N)
            ) out_buf (
                .a(chain[LG*N+:N]),
                .y(dout)
            );

            // un-reverse for left ops
            wire [N-1:0] o_rev;

            bit_rev #(
                .N(N)
            ) rev_out (
                .a(dout),
                .y(o_rev)
            );

            mux #(
                .N(N),
                .S(1),
                .D(D)
            ) out_mux (
                .d  ({o_rev, dout}),
                .sel(op[2]),
                .y  (o)
            );
        end
    endgenerate
endmodule
