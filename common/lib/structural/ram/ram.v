// structural RAM: 2**A words x N bits, accessed as an aligned group of
// 2**size words at a time
//
//   The port is W = 2**L words (W*N bits) wide. An access of size
//   2**size (size = 0..L) reads or writes the aligned 2**size-word
//   group containing the address: the block bits addr[A-1:L] select
//   one of 2**(A-L) blocks of W consecutive words and the group bits
//   addr[L-1:size] select the group within the block (the low size
//   address bits are ignored). Group data is right-justified at the
//   port:
//     read:  q = {zeros, group}    (asynchronous, zero-padded above)
//     write: the group takes d's low 2**size lanes (synchronous, on
//            posedge clk with we)
//   clear: synchronous -- on posedge clk with clear, all words <= 0
//   size = L accesses a whole block; size = 0 a single word. L = 0
//   (the default) is the plain single-word RAM with size unused.
//   Encodings above L read as zero and write nothing. 0 <= L <= A.
//
// Depends: dff_sc, mux, demux, gates (buf1, shift_ext)

module ram #(
    // word size, in bits
    parameter int N  = 16,
    // number of address bits: the memory holds 2**A words
    parameter int A  = 6,
    // lane bits, 0 <= L <= A: the port is W = 2**L words wide
    parameter int L  = 0,
    // words per access: 2**L (derived -- do not override)
    parameter int W  = 1 << L,
    // size-field width (derived -- do not override)
    parameter int ZS = (L > 0) ? $clog2(L + 1) : 1,
    // gate delay (decode + muxes), in `timescale units
    parameter int D  = 0,
    // flip-flop delay (clock-to-q), in `timescale units
    parameter int DF = 0
) (
    input  wire           clk,
    input  wire           clear,
    // write strobe
    input  wire           we,
    input  wire [A-1:0]   addr,
    // access size: 2**size words (0 <= size <= L)
    input  wire [ZS-1:0]  size,
    input  wire [W*N-1:0] d,
    output wire [W*N-1:0] q
);
    // number of words
    localparam int M = 1 << A;
    // block-address bits (BA = 0 when one block fills the memory)
    localparam int BA = A - L;
    // size-select inputs: 2**ZS >= L+1
    localparam int NS = 1 << ZS;

    wire [M-1:0] wen;  // per-word write enables
    // all words, packed for the read mux: word i = words[i*N +: N]
    wire [M*N-1:0] words;
    wire [  W-1:0] wmask;  // per-lane write mask within the block
    wire [W*N-1:0] drep;  // d replicated to the access's period
    wire [W*N-1:0] block;  // the addressed block

    // the write decode and the block read both key on the block address
    // (the word address above the lane bits); a single block needs
    // neither
    generate
        if (BA > 0) begin : g_dec
            wire [BA-1:0] baddr;

            buf1 #(
                .N(BA)
            ) g_b (
                .a(addr[L+:BA]),
                .y(baddr)
            );

            // write decode: the mask demuxed by block -- block j gets
            // wmask and all other blocks 0
            demux #(
                .N(W),
                .S(BA),
                .D(D)
            ) g_we (
                .d  (wmask),
                .sel(baddr),
                .y  (wen)
            );

            // the addressed block: packed mux over the blocks
            // (block j = words[j*W*N +: W*N])
            mux #(
                .N(W*N),
                .S(BA),
                .D(D)
            ) r_mux (
                .d  (words),
                .sel(baddr),
                .y  (block)
            );
        end else begin : g_nodec
            // one block fills the memory: the mask IS the per-word
            // enables (W = 2**A = M) and the read is the block
            buf1 #(
                .N(W)
            ) g_we (
                .a(wmask),
                .y(wen)
            );

            buf1 #(
                .N(W*N)
            ) g_q (
                .a(words),
                .y(block)
            );
        end
    endgenerate

    // per-size access logic (L = 0: every access is the one word)
    genvar s;
    generate
        if (L > 0) begin : g_sized
            // per-size candidates, packed: size s = [s*WIDTH +: WIDTH];
            // encodings above L are padded with zero
            wire [  NS*W-1:0] masks;  // per-lane write mask per size
            wire [NS*W*N-1:0] dreps;  // replicated write data per size
            wire [NS*W*N-1:0] rgrps;  // right-justified read group per size

            for (s = 0; s <= L; s = s + 1) begin : g_sz
                localparam int GW = 1 << s;  // words per group at size s

                // write data: replicate the low GW lanes with period GW
                // (aligned groups are periodic, so each lane of the
                // group then carries the right data)
                buf1 #(
                    .N(W*N)
                ) dr (
                    .a({(1 << (L - s)) {d[GW*N-1:0]}}),
                    .y(dreps[s*W*N+:W*N])
                );

                if (s == L) begin : g_full
                    // full block: every lane writes, the read is the block
                    buf1 #(
                        .N(W)
                    ) m (
                        .a({W{we}}),
                        .y(masks[s*W+:W])
                    );

                    buf1 #(
                        .N(W*N)
                    ) rg (
                        .a(block),
                        .y(rgrps[s*W*N+:W*N])
                    );
                end else begin : g_grp
                    // write mask: the GW-lane group containing the address
                    demux #(
                        .N(GW),
                        .S(L - s),
                        .D(D)
                    ) m (
                        .d  ({GW{we}}),
                        .sel(addr[L-1:s]),
                        .y  (masks[s*W+:W])
                    );

                    // read: the group containing the address,
                    // right-justified and zero-padded
                    wire [GW*N-1:0] grp;

                    mux #(
                        .N(GW*N),
                        .S(L - s),
                        .D(D)
                    ) g (
                        .d  (block),
                        .sel(addr[L-1:s]),
                        .y  (grp)
                    );

                    shift_ext #(
                        .N(GW*N),
                        .S(0),
                        .W(W*N)
                    ) rg (
                        .w(grp),
                        .y(rgrps[s*W*N+:W*N])
                    );
                end
            end

            // pad the unused size encodings with zero (a size above L
            // reads as zero and writes nothing)
            for (s = L + 1; s < NS; s = s + 1) begin : g_pad
                buf1 #(
                    .N(W)
                ) m (
                    .a({W{1'b0}}),
                    .y(masks[s*W+:W])
                );

                buf1 #(
                    .N(W*N)
                ) dr (
                    .a({(W * N) {1'b0}}),
                    .y(dreps[s*W*N+:W*N])
                );

                buf1 #(
                    .N(W*N)
                ) rg (
                    .a({(W * N) {1'b0}}),
                    .y(rgrps[s*W*N+:W*N])
                );
            end

            // size selects
            mux #(
                .N(W),
                .S(ZS),
                .D(D)
            ) g_ms (
                .d  (masks),
                .sel(size),
                .y  (wmask)
            );

            mux #(
                .N(W*N),
                .S(ZS),
                .D(D)
            ) g_ds (
                .d  (dreps),
                .sel(size),
                .y  (drep)
            );

            mux #(
                .N(W*N),
                .S(ZS),
                .D(D)
            ) g_qs (
                .d  (rgrps),
                .sel(size),
                .y  (q)
            );
        end else begin : g_plain
            buf1 #(
                .N(1)
            ) m (
                .a(we),
                .y(wmask)
            );

            buf1 #(
                .N(N)
            ) dr (
                .a(d),
                .y(drep)
            );

            buf1 #(
                .N(N)
            ) rg (
                .a(block),
                .y(q)
            );
        end
    endgenerate

    // storage: each word is a register behind a write mux (load vs
    // hold) fed by its lane of the replicated write data
    genvar i;
    generate
        for (i = 0; i < M; i = i + 1) begin : g_word
            // this word's d lane: lane k = i%W (W is 2**L)
            localparam int LN = i % W;

            wire [N-1:0] q_i;
            wire [N-1:0] d_i;

            mux #(
                .N(N),
                .S(1),
                .D(D)
            ) w_mux (
                .d  ({drep[LN*N+:N], q_i}),
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

            // pack the word for the read mux
            buf1 #(
                .N(N)
            ) b (
                .a(q_i),
                .y(words[i*N+:N])
            );
        end
    endgenerate
endmodule
