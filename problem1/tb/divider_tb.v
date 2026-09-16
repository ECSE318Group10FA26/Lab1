// ==========================================================================
// divider_tb.v
//
// Testbench for the non-restoring divider (Lab 1 deliverable 2).
// Required test cases: 7/2, 6/2, 9/4
//
//   7/2 -> quotient = 3, remainder = 1
//   6/2 -> quotient = 3, remainder = 0
//   9/4 -> quotient = 2, remainder = 1
//
// The DUT is not implemented yet, so expect TIMEOUT messages until the
// datapath/control logic in src/divider.v is filled in.
// ==========================================================================

`timescale 1ns/1ps

module divider_tb;

    localparam N = 4;

    reg             clk;
    reg             rst;
    reg             start;
    reg  [N-1:0]    dividend;
    reg  [N-1:0]    divisor;
    wire [N-1:0]    quotient;
    wire [N:0]      remainder;
    wire            done;

    integer errors;

    // DUT
    divider #(.N(N)) dut (
        .clk       (clk),
        .rst       (rst),
        .start     (start),
        .dividend  (dividend),
        .divisor   (divisor),
        .quotient  (quotient),
        .remainder (remainder),
        .done      (done)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // ----------------------------------------------------------------------
    // run_test: apply one division, wait for done, check results
    // ----------------------------------------------------------------------
    task run_test;
        input [N-1:0] dvd;
        input [N-1:0] dvr;
        input [N-1:0] exp_q;
        input [N:0]   exp_r;
        integer timeout;
        begin
            @(negedge clk);
            dividend = dvd;
            divisor  = dvr;
            start    = 1'b1;
            @(negedge clk);
            start    = 1'b0;

            // wait for done (with timeout so the sim never hangs)
            timeout = 0;
            while (done !== 1'b1 && timeout < 200) begin
                @(posedge clk);
                timeout = timeout + 1;
            end

            if (done !== 1'b1) begin
                $display("FAIL: %0d/%0d  TIMEOUT waiting for done (divider not implemented yet?)",
                         dvd, dvr);
                errors = errors + 1;
            end else if (quotient === exp_q && remainder === exp_r) begin
                $display("PASS: %0d/%0d  quotient = %0d  remainder = %0d",
                         dvd, dvr, quotient, remainder);
            end else begin
                $display("FAIL: %0d/%0d  got quotient = %0d remainder = %0d, expected quotient = %0d remainder = %0d",
                         dvd, dvr, quotient, remainder, exp_q, exp_r);
                errors = errors + 1;
            end
        end
    endtask

    // ----------------------------------------------------------------------
    // Stimulus
    // ----------------------------------------------------------------------
    initial begin
        errors   = 0;
        rst      = 1'b1;
        start    = 1'b0;
        dividend = {N{1'b0}};
        divisor  = {N{1'b0}};

        repeat (3) @(negedge clk);
        rst = 1'b0;

        run_test(4'd7, 4'd2, 4'd3, 5'd1);   // 7/2
        run_test(4'd6, 4'd2, 4'd3, 5'd0);   // 6/2
        run_test(4'd9, 4'd4, 4'd2, 5'd1);   // 9/4

        $display("------------------------------------------------");
        if (errors == 0)
            $display("ALL TESTS PASSED");
        else
            $display("%0d TEST(S) FAILED", errors);
        $display("------------------------------------------------");

        $finish;
    end

    // Waveform dump (view with: vsim -view vsim.wlf, or convert with wlf2vcd)
    initial begin
        $dumpfile("sim/divider_tb.vcd");
        $dumpvars(0, divider_tb);
    end

endmodule
