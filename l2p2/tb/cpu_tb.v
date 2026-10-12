// Testbench for the structural CPU (cpu)
//
// The program is ASSEMBLED: asm/asm.py converts asm/prog.asm into
// sim/program.hex (a $readmemh image), which this bench pokes into the
// RAM words:
//     python3 asm/asm.py asm/prog.asm && ../sim.sh l2p2   (from l2p2/)

`timescale 1ns / 1ps

module cpu_tb;

    localparam int T = 10;  // clock period, in `timescale units

    integer       errors;
    integer       tests;

    wire          clk;
    reg           clear;
    wire    [4:0] status;

    clk_gen #(.T(T)) cg (.clk(clk));

    cpu #(
        .N (8),
        .A (8),
        .I (16),
        .L (2),
        .D (0),
        .DF(0)
    ) dut (
        .clk      (clk),
        .clear    (clear),
        .ram_clear(1'b0),
        .status   (status)
    );

    // program image (asm/asm.py -> sim/program.hex): one RAM word (a
    // byte) per entry; one instruction spans W=4 consecutive entries
    reg [7:0] img[256];

    // Place our loaded hex image directly into RAM to initialize
    genvar gi;
    generate
        for (gi = 0; gi < 256; gi = gi + 1) begin : g_poke
            initial begin
                #1;
                dut.mem.g_word[gi].bits.q = img[gi];
            end
        end
    endgenerate

    initial begin
        $dumpfile("sim/cpu_tb.vcd");
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
        $readmemh("sim/program.hex", img);

        // ---------------- run ----------------
        clear = 1;
        repeat (3) @(posedge clk);
        #1 clear = 0;

        // 38 instructions x 2 cycles, then the halt loop
        repeat (96) @(posedge clk);
        #1;

        // ---------------- checks ----------------
        tests = tests + 1;
        if (dut.mem.g_word[162].bits.q !== 8'hA5) begin
            errors = errors + 1;
            $display("FAIL: skipped stores wrote mem[162]=%h (exp A5)",
                     dut.mem.g_word[162].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[163].bits.q !== 8'd27) begin
            errors = errors + 1;
            $display("FAIL: mem[163]=%0d (exp 27 = 24 via STORE + 3 via RMW ADD)",
                     dut.mem.g_word[163].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[164].bits.q !== 8'd0) begin
            errors = errors + 1;
            $display("FAIL: mem[164]=%0d (exp 0)", dut.mem.g_word[164].bits.q);
        end

        // mem[165] = the status snapshot MOVSR took after the SLE
        tests = tests + 1;
        if (dut.mem.g_word[165].bits.q !== 8'd20) begin
            errors = errors + 1;
            $display("FAIL: mem[165]=%0d (exp 20 = 5'b10100)", dut.mem.g_word[165].bits.q);
        end

        // mem[166] = the low word of ~3 via NOT (source through the ALU)
        tests = tests + 1;
        if (dut.mem.g_word[166].bits.q !== 8'hFC) begin
            errors = errors + 1;
            $display("FAIL: mem[166]=%h (exp FC)", dut.mem.g_word[166].bits.q);
        end

        // mem[167] = the alignment pad: the group writes must not spill
        tests = tests + 1;
        if (dut.mem.g_word[167].bits.q !== 8'd0) begin
            errors = errors + 1;
            $display("FAIL: mem[167]=%0d (exp 0, alignment pad untouched)",
                     dut.mem.g_word[167].bits.q);
        end

        // mem[168..169] = the store.2 of 0x8AAB (AB, 8A)
        tests = tests + 1;
        if (dut.mem.g_word[168].bits.q !== 8'hAB) begin
            errors = errors + 1;
            $display("FAIL: mem[168]=%h (exp AB, store.2 low word)",
                     dut.mem.g_word[168].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[169].bits.q !== 8'h8A) begin
            errors = errors + 1;
            $display("FAIL: mem[169]=%h (exp 8A, store.2 high word)",
                     dut.mem.g_word[169].bits.q);
        end

        // mem[170..171] = the 2-word round trip (load.2 -> store.2)
        tests = tests + 1;
        if (dut.mem.g_word[170].bits.q !== 8'hAB) begin
            errors = errors + 1;
            $display("FAIL: mem[170]=%h (exp AB, load.2 low word)",
                     dut.mem.g_word[170].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[171].bits.q !== 8'h8A) begin
            errors = errors + 1;
            $display("FAIL: mem[171]=%h (exp 8A, load.2 high word)",
                     dut.mem.g_word[171].bits.q);
        end

        // mem[172..175] = the store.4 (whole block): EF BE 00 00
        tests = tests + 1;
        if (dut.mem.g_word[172].bits.q !== 8'hAB) begin
            errors = errors + 1;
            $display("FAIL: mem[172]=%h (exp AB, store.4 word 0)",
                     dut.mem.g_word[172].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[173].bits.q !== 8'h8A) begin
            errors = errors + 1;
            $display("FAIL: mem[173]=%h (exp 8A, store.4 word 1)",
                     dut.mem.g_word[173].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[174].bits.q !== 8'd0) begin
            errors = errors + 1;
            $display("FAIL: mem[174]=%0d (exp 0, store.4 word 2)",
                     dut.mem.g_word[174].bits.q);
        end

        tests = tests + 1;
        if (dut.mem.g_word[175].bits.q !== 8'd0) begin
            errors = errors + 1;
            $display("FAIL: mem[175]=%0d (exp 0, store.4 word 3)",
                     dut.mem.g_word[175].bits.q);
        end

        // mem[176] = the block round trip's low word (load.4 -> store)
        tests = tests + 1;
        if (dut.mem.g_word[176].bits.q !== 8'hAB) begin
            errors = errors + 1;
            $display("FAIL: mem[176]=%h (exp AB, load.4 round trip)",
                     dut.mem.g_word[176].bits.q);
        end

        tests = tests + 1;
        if (dut.regs.g_reg[0].bits.q !== 32'd0) begin
            errors = errors + 1;
            $display("FAIL: R0=%0d (exp 0)", dut.regs.g_reg[0].bits.q);
        end

        tests = tests + 1;
        if (dut.regs.g_reg[1].bits.q !== 32'd3) begin
            errors = errors + 1;
            $display("FAIL: R1=%0d (exp 3)", dut.regs.g_reg[1].bits.q);
        end

        // R2 = the 16-bit immediate -- wider than a RAM word
        tests = tests + 1;
        if (dut.regs.g_reg[2].bits.q !== 32'h00008AAB) begin
            errors = errors + 1;
            $display("FAIL: R2=%h (exp 00008AAB)", dut.regs.g_reg[2].bits.q);
        end

        tests = tests + 1;
        if (dut.regs.g_reg[3].bits.q !== 32'd20) begin
            errors = errors + 1;
            $display("FAIL: R3=%0d (exp 20, MOVSR)", dut.regs.g_reg[3].bits.q);
        end

        tests = tests + 1;
        if (dut.pc_reg.q !== 8'd152) begin
            errors = errors + 1;
            $display("FAIL: pc=%0d (exp 152 = 38*4, halt loop)", dut.pc_reg.q);
        end

        tests = tests + 1;
        if (status !== 5'b10100) begin  // P=1, Z=1 (from the final AND), N=C=V=0
            errors = errors + 1;
            $display("FAIL: status=%b (exp 10100: P,Z)", status);
        end

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
