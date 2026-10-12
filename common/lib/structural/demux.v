// demux.v - parameterized binary tree demultiplexer / one-hot decoder
//
//   demux #(1, 1) : the classic 1:2, 1-bit demux
//   demux #(8, 2) : 1:4 demux of 8-bit words
//
// The dual of mux: routes d to the output selected by sel and drives
// all other outputs with 0 -- i.e. a one-hot decode of sel ANDed with
// d. The tree mirrors mux.v: where the mux merges two halves at the
// top select bit, the demux steers d into one half at the top select
// bit and recurses.
//
// NOTE: relies on recursive module instantiation
// NOTE: Verilog has no array-of-vector ports, outputs are packed
//
// Depends: and2

module demux #(
    // data width of the input (and of each output), in bits
    parameter int N = 1,
    // select width, in bits -> the demux has 2**S outputs
    parameter int S = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [       N-1:0] d,
    input  wire [       S-1:0] sel,
    // packed outputs: output k = y[k*N +: N] = d when sel == k, else 0
    output wire [(1<<S)*N-1:0] y
);
    generate
        if (S == 1) begin : g_leaf
            // base case, 1:2 demux: y = {d & sel, d & ~sel}
            wire sel_n;

            not #(D) (sel_n, sel[0]);
            and2 #(
                .N(N),
                .D(D)
            ) g_lo (
                .a(d),
                .b({N{sel_n}}),
                .y(y[0+:N])
            );
            and2 #(
                .N(N),
                .D(D)
            ) g_hi (
                .a(d),
                .b({N{sel[0]}}),
                .y(y[N+:N])
            );
        end else begin : g_rec
            // outputs per half
            localparam int H = 1 << (S - 1);
            wire [N-1:0] lo, hi;  // d steered by the top select bit

            demux #(
                .N(N),
                .S(1),
                .D(D)
            ) d_top (
                .d  (d),
                .sel(sel[S-1]),
                .y  ({hi, lo})
            );

            demux #(
                .N(N),
                .S(S - 1),
                .D(D)
            ) d_lo (
                .d  (lo),
                .sel(sel[S-2:0]),
                .y  (y[0+:H*N])
            );
            demux #(
                .N(N),
                .S(S - 1),
                .D(D)
            ) d_hi (
                .d  (hi),
                .sel(sel[S-2:0]),
                .y  (y[H*N+:H*N])
            );
        end
    endgenerate
endmodule
