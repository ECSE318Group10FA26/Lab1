// Testbench for the bit-serial adder
//
//   (a/b) Correctness: both the structural and the behavioral model are
//         checked against the golden reference {cout,sum} = addend+augend+cin.
//   (c)   Equivalence: both models receive identical stimulus and their
//         outputs are compared vector by vector (the structural model's
//         result is sampled after its n shift/add cycles; the behavioral
//         model holds its result, so both are compared at the same time).
//
// Stimulus: directed vectors (incl. the handout example 5 + 1 = 6),
// followed by an exhaustive sweep of all 2^(2N+1) operand/cin combinations.

`timescale 1ns/1ps

module adder_tb;

    localparam N = 4;

    reg             clk;
    reg             clear;
    reg             load;
    reg             cin;
    reg  [N-1:0]    addend;
    reg  [N-1:0]    augend;

    wire [N-1:0]    result_s;   // structural model (part a)
    wire            cout_s;
    wire [N-1:0]    result_b;   // behavioral model (part b)
    wire            cout_b;

    integer errors;             // failures vs. the golden reference
    integer mismatches;         // structural vs. behavioral differences
    integer tests;
    reg     verbose;            // module-level flag read by run_test
                                // (Verilog-2001 has no bool type: use a reg)

    // DUTs - both models see exactly the same stimulus
    serial_adder_structural #(.N(N)) dut_structural (
        .clk    (clk),
        .clear  (clear),
        .load   (load),
        .cin    (cin),
        .addend (addend),
        .augend (augend),
        .result (result_s),
        .cout   (cout_s)
    );

    serial_adder_behavioral #(.N(N)) dut_behavioral (
        .clk    (clk),
        .clear  (clear),
        .load   (load),
        .cin    (cin),
        .addend (addend),
        .augend (augend),
        .result (result_b),
        .cout   (cout_b)
    );

    // 100 MHz clock
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // run_test: perform one bit-serial addition with a+b+c and check both
    // models against the golden reference and against each other.
    //   Prints a PASS line per vector while the module-level `verbose`
    //   flag is set; failures are always printed.
    task run_test;
        input [N-1:0] a;
        input [N-1:0] b;
        input         c;
        reg   [N:0]   expected;
        reg           ok_s, ok_b;
        begin
            expected = a + b + {{(N-1){1'b0}}, c};  // golden reference (N+1 bits;
                                                    // c zero-extended to N bits)

            // clear the carry register
            @(negedge clk);
            addend = a;
            augend = b;
            cin    = c;
            clear  = 1'b1;
            load   = 1'b0;

            // parallel-load the operand registers (carry <- cin)
            @(negedge clk);
            clear  = 1'b0;
            load   = 1'b1;

            // release load, then run the n shift/add cycles
            @(negedge clk);
            load   = 1'b0;
            repeat (N) @(negedge clk);

            // sample: structural result is complete; behavioral holds
            tests = tests + 1;
            ok_s  = ({cout_s, result_s} === expected);
            ok_b  = ({cout_b, result_b} === expected);

            if ({cout_s, result_s} !== {cout_b, result_b})
                mismatches = mismatches + 1;

            if (ok_s && ok_b) begin
                if (verbose)
                    $display("PASS: %0d + %0d + %0d = %0d (cout = %b)  structural and behavioral agree",
                            a, b, c, expected[N-1:0], expected[N]);
            end else begin
                errors = errors + 1;
                $display("FAIL: %0d + %0d + %0d  expected sum = %0d cout = %b", a, b, c,
                         expected[N-1:0], expected[N]);
                $display("      structural: sum = %0d cout = %b", result_s, cout_s);
                $display("      behavioral: sum = %0d cout = %b", result_b, cout_b);
            end
        end
    endtask

    // Stimulus
    integer i, j, k;
    initial begin
        errors     = 0;
        mismatches = 0;
        tests      = 0;
        verbose    = 1'b1;      // print PASS reports
        clear      = 1'b0;
        load       = 1'b0;
        cin        = 1'b0;
        addend     = {N{1'b0}};
        augend     = {N{1'b0}};

        // explicit tests
        run_test(4'd5,  4'd1,  1'b0);
        run_test(4'd5,  4'd0,  1'b1);
        run_test(4'd0,  4'd0,  1'b0);
        run_test(4'd0,  4'd0,  1'b1);
        run_test(4'd15, 4'd15, 1'b0);
        run_test(4'd15, 4'd15, 1'b1);
        run_test(4'd10, 4'd7,  1'b1);

        // exhaustive sweep
        verbose = 1'b0;         // silence PASS reports
        for (i = 0; i < (1 << N); i = i + 1)
            for (j = 0; j < (1 << N); j = j + 1)
                for (k = 0; k < 2; k = k + 1)
                    run_test(i[N-1:0], j[N-1:0], k[0]);

        // summary
        $display("------------------------------------------------");
        $display("vectors tested : %0d", tests);
        if (errors == 0)
            $display("correctness    : PASS - both models match addend+augend+cin for every vector");
        else
            $display("correctness    : %0d FAILURE(S) vs golden reference", errors);
        if (mismatches == 0)
            $display("equivalence    : PASS - structural and behavioral outputs identical for all %0d vectors", tests);
        else
            $display("equivalence    : %0d MISMATCH(ES) between structural and behavioral", mismatches);
        if (errors == 0 && mismatches == 0)
            $display("ALL TESTS PASSED");
        else
            $display("TEST(S) FAILED");
        $display("------------------------------------------------");

        $finish;
    end

    // Waveform dump
    initial begin
        $dumpfile("sim/adder_tb.vcd");
        $dumpvars(0, adder_tb);
    end

endmodule
