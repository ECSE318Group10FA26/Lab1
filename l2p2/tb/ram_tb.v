// Testbench for the structural RAM (ram) and clock generator (clk_gen)

`timescale 1ns / 1ps

module ram_tb;

    localparam int T = 10;  // clock period, in `timescale units

    integer errors;
    integer tests;
    integer i;
    time    t0;

    // the clock generator under test also clocks the RAM DUTs
    wire clk;

    clk_gen #(.T(T)) cg (.clk(clk));

    // DUT A: 16 words x 8 bits, zero delays
    reg        we_a;
    reg  [3:0] addr_a;
    reg  [7:0] d_a;
    wire [7:0] q_a;

    ram #(
        .N (8),
        .A (4),
        .D (0),
        .DF(0)
    ) dut_a (
        .clk  (clk),
        .clear(1'b0),
        .we  (we_a),
        .addr(addr_a),
        .size(1'b0),
        .d   (d_a),
        .q   (q_a)
    );

    // DUT B: 2 words x 1 bit (minimal widths)
    reg  we_b;
    reg  addr_b;
    reg  d_b;
    wire q_b;

    ram #(
        .N (1),
        .A (1),
        .D (0),
        .DF(0)
    ) dut_b (
        .clk  (clk),
        .clear(1'b0),
        .we  (we_b),
        .addr(addr_b),
        .size(1'b0),
        .d   (d_b),
        .q   (q_b)
    );

    // DUT C: 16 words x 8 bits with D=2, DF=1 (delay plumbing)
    reg        we_c;
    reg  [3:0] addr_c;
    reg  [7:0] d_c;
    wire [7:0] q_c;

    ram #(
        .N (8),
        .A (4),
        .D (2),
        .DF(1)
    ) dut_c (
        .clk  (clk),
        .clear(1'b0),
        .we  (we_c),
        .addr(addr_c),
        .size(1'b0),
        .d   (d_c),
        .q   (q_c)
    );

    // DUT D: 16 words x 8 bits in 4-word blocks (L=2), sized access
    reg        we_d;
    reg  [ 3:0] addr_d;
    reg  [ 1:0] size_d;
    reg  [31:0] d_d;
    wire [31:0] q_d;

    ram #(
        .N (8),
        .A (4),
        .L (2),
        .D (0),
        .DF(0)
    ) dut_d (
        .clk  (clk),
        .clear(1'b0),
        .we  (we_d),
        .addr(addr_d),
        .size(size_d),
        .d   (d_d),
        .q   (q_d)
    );

    // DUT E: 4 words x 8 bits in one block (L=2=A: no block decode)
    reg        we_e;
    reg  [ 1:0] addr_e;
    reg  [ 1:0] size_e;
    reg  [31:0] d_e;
    wire [31:0] q_e;

    ram #(
        .N (8),
        .A (2),
        .L (2),
        .D (0),
        .DF(0)
    ) dut_e (
        .clk  (clk),
        .clear(1'b0),
        .we  (we_e),
        .addr(addr_e),
        .size(size_e),
        .d   (d_e),
        .q   (q_e)
    );

    // reference contents of DUT A
    reg [7:0] exp[16];

    // write v to address a of DUT A (inputs change away from the write edge)
    task automatic wr_a(input logic [3:0] a, input logic [7:0] v);
        begin
            @(negedge clk);
            addr_a = a;
            d_a    = v;
            we_a   = 1;
            @(posedge clk);
            #1 we_a = 0;
        end
    endtask

    // async-read check of DUT A address a against v
    task automatic rd_a(input logic [3:0] a, input logic [7:0] v);
        begin
            addr_a = a;
            #1;
            tests = tests + 1;
            if (q_a !== v) begin
                errors = errors + 1;
                if (errors <= 10) $display("FAIL: read addr=%0d q=%0d (exp %0d)", a, q_a, v);
            end
        end
    endtask

    // write a 2**s-word group of DUT D at address a (right-justified v)
    task automatic wr_d(input logic [3:0] a, input logic [1:0] s, input logic [31:0] v);
        begin
            @(negedge clk);
            addr_d = a;
            size_d = s;
            d_d    = v;
            we_d   = 1;
            @(posedge clk);
            #1 we_d = 0;
        end
    endtask

    // async-read check of the 2**s-word group of DUT D at address a
    task automatic rd_d(input logic [3:0] a, input logic [1:0] s, input logic [31:0] v);
        begin
            addr_d = a;
            size_d = s;
            #1;
            tests = tests + 1;
            if (q_d !== v) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL (sized): read addr=%0d size=%0d q=%h (exp %h)", a, s, q_d, v);
            end
        end
    endtask

    // write a 2**s-word group of DUT E at address a (one block total)
    task automatic wr_e(input logic [1:0] a, input logic [1:0] s, input logic [31:0] v);
        begin
            @(negedge clk);
            addr_e = a;
            size_e = s;
            d_e    = v;
            we_e   = 1;
            @(posedge clk);
            #1 we_e = 0;
        end
    endtask

    // async-read check of the 2**s-word group of DUT E at address a
    task automatic rd_e(input logic [1:0] a, input logic [1:0] s, input logic [31:0] v);
        begin
            addr_e = a;
            size_e = s;
            #1;
            tests = tests + 1;
            if (q_e !== v) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display("FAIL (one block): read addr=%0d size=%0d q=%h (exp %h)", a, s, q_e, v);
            end
        end
    endtask

    initial begin
        $dumpfile("sim/ram_tb.vcd");
        $dumpvars;

        errors = 0;
        tests  = 0;

        we_a   = 0;
        addr_a = 0;
        d_a    = 0;
        we_b   = 0;
        addr_b = 0;
        d_b    = 0;
        we_c   = 0;
        addr_c = 0;
        d_c    = 0;
        we_d   = 0;
        addr_d = 0;
        size_d = 0;
        d_d    = 0;
        we_e   = 0;
        addr_e = 0;
        size_e = 0;
        d_e    = 0;

        // clk_gen: 10 periods take 10*T time units
        @(posedge clk);
        t0 = $time;
        repeat (10) @(posedge clk);
        tests = tests + 1;
        if ($time - t0 != time'(10 * T)) begin
            errors = errors + 1;
            $display("FAIL: 10 periods took %0d (exp %0d)", $time - t0, 10 * T);
        end

        // fill DUT A and read all words back
        for (i = 0; i < 16; i = i + 1) begin
            exp[i] = 8'($unsigned((i << 4) | (15 - i)));
            wr_a(i[3:0], exp[i]);
        end
        for (i = 0; i < 16; i = i + 1) rd_a(i[3:0], exp[i]);

        // a posedge with we=0 must not write
        @(negedge clk);
        addr_a = 5;
        d_a    = 8'hFF;
        @(posedge clk);
        #1;
        rd_a(4'd5, exp[5]);

        // overwrite every word and read all back again
        for (i = 0; i < 16; i = i + 1) begin
            exp[i] = 8'($unsigned(255 - i));
            wr_a(i[3:0], exp[i]);
        end
        for (i = 0; i < 16; i = i + 1) rd_a(i[3:0], exp[i]);

        // DUT B: minimal widths
        @(negedge clk);
        addr_b = 0;
        d_b    = 1;
        we_b   = 1;
        @(posedge clk);
        #1 we_b = 0;
        @(negedge clk);
        addr_b = 1;
        d_b    = 0;
        we_b   = 1;
        @(posedge clk);
        #1 we_b = 0;

        addr_b = 0;
        #1;
        tests = tests + 1;
        if (q_b !== 1'b1) begin
            errors = errors + 1;
            $display("FAIL (N=1): read addr=0 q=%b (exp 1)", q_b);
        end
        addr_b = 1;
        #1;
        tests = tests + 1;
        if (q_b !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL (N=1): read addr=1 q=%b (exp 0)", q_b);
        end

        // a posedge with we=0 must not write (DUT B)
        @(negedge clk);
        addr_b = 1;
        d_b    = 1;
        @(posedge clk);
        #1;
        tests = tests + 1;
        if (q_b !== 1'b0) begin
            errors = errors + 1;
            $display("FAIL (N=1): hold wrote addr=1 q=%b (exp 0)", q_b);
        end

        // DUT C: non-zero delays (D=2, DF=1): the write decode's delay
        // exceeds T/2, so hold we across a full cycle; the
        // first posedge is a no-op (decode not settled), the second writes
        @(negedge clk);
        addr_c = 3;
        d_c    = 8'hA5;
        we_c   = 1;
        @(posedge clk);
        @(posedge clk);
        #2 we_c = 0;
        #20;
        tests = tests + 1;
        if (q_c !== 8'hA5) begin
            errors = errors + 1;
            $display("FAIL (delays): read addr=3 q=%h (exp a5)", q_c);
        end

        // DUT D: sized group access (L=2: 4-word blocks)
        // full-block write/read (size=2); the block bits ignore the
        // lane bits of the address
        wr_d(4'd4, 2'd2, 32'h44332211);  // block 1 = words 4..7
        rd_d(4'd4, 2'd2, 32'h44332211);
        rd_d(4'd5, 2'd2, 32'h44332211);
        rd_d(4'd7, 2'd2, 32'h44332211);

        // single-word access (size=0): only the addressed word changes;
        // the read is right-justified and zero-padded
        wr_d(4'd8, 2'd2, 32'hDEAD8AAB);  // block 2 = words 8..11
        wr_d(4'd9, 2'd0, 32'h0000001F);  // mem[9] = 8'h1F
        rd_d(4'd8, 2'd2, 32'hDEAD1FAB);
        rd_d(4'd9, 2'd0, 32'h0000001F);
        rd_d(4'd8, 2'd0, 32'h000000AB);

        // pair access (size=1): the aligned pair containing the address
        // (addr 10 and 11 name the same pair: the low size bits are
        // ignored)
        wr_d(4'd10, 2'd1, 32'h00008AAB);  // mem[10] = 8'hAB, mem[11] = 8'h8A
        rd_d(4'd11, 2'd1, 32'h00008AAB);
        rd_d(4'd10, 2'd0, 32'h000000AB);
        rd_d(4'd11, 2'd0, 32'h0000008A);
        rd_d(4'd8, 2'd2, 32'h8AAB1FAB);  // the block reflects it all

        // neighboring blocks are untouched
        rd_d(4'd4, 2'd2, 32'h44332211);

        // a size encoding above L writes nothing and reads as zero
        wr_d(4'd4, 2'd3, 32'hFFFFFFFF);
        rd_d(4'd4, 2'd2, 32'h44332211);
        rd_d(4'd4, 2'd3, 32'h00000000);

        // DUT E: one block fills the memory (L = A: no block decode)
        wr_e(2'd0, 2'd2, 32'h0B0A0908);  // the whole block (addr ignored)
        rd_e(2'd3, 2'd2, 32'h0B0A0908);
        wr_e(2'd1, 2'd1, 32'h00007766);  // the pair holding addr 1 (words 0..1)
        rd_e(2'd0, 2'd2, 32'h0B0A7766);
        rd_e(2'd1, 2'd1, 32'h00007766);
        wr_e(2'd3, 2'd0, 32'h00000055);  // word 3
        rd_e(2'd0, 2'd2, 32'h550A7766);
        rd_e(2'd3, 2'd0, 32'h00000055);

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
