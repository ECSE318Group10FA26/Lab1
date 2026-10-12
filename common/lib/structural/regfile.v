// regfile.v - structural register file: 2**R registers x N bits
//
//   write: synchronous -- on posedge clk with we, regs[w_addr] <= w_data
//   read:  two asynchronous ports -- r_data_a = regs[r_addr_a],
//          r_data_b = regs[r_addr_b]
//   clear: synchronous -- on posedge clk with clear, all registers <= 0
//
// Same structure as ram: a demux of we by w_addr produces one write
// enable per register; each register is a dff_sc behind a write mux
// (load vs hold); each read port is a packed mux tree.
//
// Depends: demux, dff_sc, mux, gates (buf1)

module regfile #(
    // register width, in bits
    parameter int N  = 16,
    // register-address bits: the file holds 2**R registers
    parameter int R  = 2,
    // gate delay (decode + muxes), in `timescale units
    parameter int D  = 0,
    // flip-flop delay (clock-to-q), in `timescale units
    parameter int DF = 0
) (
    input  wire         clk,
    input  wire         clear,
    // write enable
    input  wire         we,
    input  wire [R-1:0] w_addr,
    input  wire [N-1:0] w_data,
    // read port A
    input  wire [R-1:0] r_addr_a,
    output wire [N-1:0] r_data_a,
    // read port B
    input  wire [R-1:0] r_addr_b,
    output wire [N-1:0] r_data_b
);
    // number of registers
    localparam int M = 1 << R;

    wire [  M-1:0] wen;  // per-register write enables
    // all registers, packed: register i = words[i*N +: N]
    wire [M*N-1:0] words;

    // write decode: one enable per register (we demuxed by w_addr)
    demux #(
        .N(1),
        .S(R),
        .D(D)
    ) g_we (
        .d  (we),
        .sel(w_addr),
        .y  (wen)
    );

    genvar i;
    generate
        for (i = 0; i < M; i = i + 1) begin : g_reg
            // storage register: flip-flops behind a write mux (load vs
            // hold)
            wire [N-1:0] q_i;
            wire [N-1:0] d_i;

            mux #(
                .N(N),
                .S(1),
                .D(D)
            ) w_mux (
                .d  ({w_data, q_i}),
                .sel(wen[i]),
                .y  (d_i)
            );

            dff_sc #(
                .N(N),
                .D(DF)
            ) bits (
                .clk  (clk),
                .clear(clear),
                .d    (d_i),
                .q    (q_i)
            );

            // pack the register for the read muxes
            buf1 #(
                .N(N)
            ) b (
                .a(q_i),
                .y(words[i*N+:N])
            );
        end
    endgenerate

    // read ports: asynchronous packed muxes over all registers
    mux #(
        .N(N),
        .S(R),
        .D(D)
    ) r_mux_a (
        .d  (words),
        .sel(r_addr_a),
        .y  (r_data_a)
    );

    mux #(
        .N(N),
        .S(R),
        .D(D)
    ) r_mux_b (
        .d  (words),
        .sel(r_addr_b),
        .y  (r_data_b)
    );
endmodule
