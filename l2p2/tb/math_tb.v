// Testbench for the structural CPU running asm/math.asm
//
// math.asm (see its header) computes -N, popcount(N) via the SWAR mask
// ladder, and a shift-and-add product, storing all three results in
// RAM. The DUT is a 64-bit instance: N=64 with A=7, R=2, I=8 and L=0
// (64-bit RAM words, one word per instruction).
//     python3 asm/asm.py asm/math.asm --bits 64 --addr-bits 7 --imm-bits 8 \
//         --lanes 0 -o sim/math.hex
//     TB_NAME=math_tb ../sim.sh l2p2        (from l2p2/)

`timescale 1ns / 1ps

module math_tb;

    localparam int T = 10;  // clock period, in `timescale units

    integer       errors;
    integer       tests;

    wire          clk;
    reg           clear;
    wire    [4:0] status;

    clk_gen #(.T(T)) cg (.clk(clk));

    cpu #(
        .N (64),
        .A (7),
        .I (8),
        .D (0),
        .DF(0)
    ) dut (
        .clk      (clk),
        .clear    (clear),
        .ram_clear(1'b0),
        .status   (status)
    );

    // program image (asm/asm.py -> sim/math.hex)
    reg [63:0] img[128];

    // Place our loaded hex image directly into RAM to initialize
    genvar gi;
    generate
        for (gi = 0; gi < 128; gi = gi + 1) begin : g_poke
            initial begin
                #1;
                dut.mem.g_word[gi].bits.q = img[gi];
            end
        end
    endgenerate

    initial begin
        $dumpfile("sim/math_tb.vcd");
        $dumpvars;

        errors           = 0;
        tests            = 0;

        // power-up state: clear is synchronous, so before the first
        // posedge the control flops are X and an X on ram_we/reg_we
        // would corrupt storage at that edge -- initialize them here
        dut.state_reg.q  = 1'b0;  // FETCH
        dut.pc_reg.q     = 0;
        dut.ir_reg.q     = 0;
        dut.status_reg.q = 5'b00000;

        // program image -> img -> RAM
        $readmemh("sim/math.hex", img);

        // ---------------- run ----------------
        clear = 1;
        repeat (3) @(posedge clk);
        #1 clear = 0;

        // ~240 instructions (the multiply loop runs 30 times) x 2 cycles
        repeat (600) @(posedge clk);
        #1;

        // ---------------- checks ----------------
        // mem[101] = -N (two's complement of 0x123456789ABCDEF0)
        tests = tests + 1;
        if (dut.mem.g_word[101].bits.q !== 64'hEDCBA98765432110) begin
            errors = errors + 1;
            $display("FAIL: mem[101]=%h (exp EDCBA98765432110 = -N)", dut.mem.g_word[101].bits.q);
        end

        // mem[102] = popcount(N) = 32 via the SWAR mask ladder
        tests = tests + 1;
        if (dut.mem.g_word[102].bits.q !== 64'd32) begin
            errors = errors + 1;
            $display("FAIL: mem[102]=%0d (exp 32 one-bits)", dut.mem.g_word[102].bits.q);
        end

        // mem[105] = 123456789 * 987654321 via shift-and-add
        tests = tests + 1;
        if (dut.mem.g_word[105].bits.q !== 64'd121932631112635269) begin
            errors = errors + 1;
            $display("FAIL: mem[105]=%0d (exp 121932631112635269)", dut.mem.g_word[105].bits.q);
        end

        // pc sits in the halt loop
        tests = tests + 1;
        if (dut.pc_reg.q !== 7'd40) begin
            errors = errors + 1;
            $display("FAIL: pc=%0d (exp 40, halt loop)", dut.pc_reg.q);
        end

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
