// mux.v - parameterized binary tree multiplexer
//
//   mux #(1, 1) : the classic 2:1, 1-bit mux
//   mux #(8, 2) : 4:1 mux of 8-bit words
//
// NOTE: relies on recursive module instantiation
// NOTE: Verilog has no array-of-vector ports, inputs are packed
//
// Depends: and2, or2

module mux #(
    // data width of each input, in bits
    parameter N = 1,
    // select width, in bits -> the mux has 2**S inputs
    parameter S = 1
) (
    // packed inputs: input k = d[k*N +: N]
    input  wire [(1<<S)*N-1:0] d,
    input  wire [S-1:0]        sel,
    output wire [N-1:0]        y
);
    generate
        if (S == 1) begin : g_leaf
            // base case, 2:1 mux: y = sel ? d[1] : d[0]
            wire         sel_n;
            wire [N-1:0] lo, hi;

            not (sel_n, sel[0]);
            and2 #(N) g_lo (.a(d[N-1:0]),   .b({N{sel_n}}),  .y(lo));
            and2 #(N) g_hi (.a(d[2*N-1:N]), .b({N{sel[0]}}), .y(hi));
            or2  #(N) g_or (.a(lo), .b(hi), .y(y));
        end else begin : g_rec
            // Inputs per half
            localparam H = 1 << (S-1);
            wire [N-1:0] lo, hi;

            mux #(.N(N), .S(S-1)) m_lo (
                .d   (d[0 +: H*N]),
                .sel (sel[S-2:0]),
                .y   (lo)
            );
            mux #(.N(N), .S(S-1)) m_hi (
                .d   (d[H*N +: H*N]),
                .sel (sel[S-2:0]),
                .y   (hi)
            );
            mux #(.N(N), .S(1)) m_top (
                .d   ({hi, lo}),
                .sel (sel[S-1]),
                .y   (y)
            );
        end
    endgenerate
endmodule
