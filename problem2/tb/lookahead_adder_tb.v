`timescale 1ns / 1ps

module lookahead_adder_tb;

  localparam int N = 4;

  // gate delay of the DUT, in `timescale units; when D > 0 the carry-lookahead
  // logic (~3 gate levels) must settle within one clock period (2*CLK_HALF)
  localparam int D = 0;
  // clock half-period, in `timescale units (5 -> 100 MHz)
  localparam int CLK_HALF = 5;

  reg             clk;
  reg             cin;
  reg     [N-1:0] addend;
  reg     [N-1:0] augend;

  wire    [N-1:0] result;
  wire            cout;

  integer         errors;  // failures vs. the golden reference
  integer         tests;
  reg             verbose;  // module-level flag read by run_test
                            // (Verilog-2001 has no bool type: use a reg)

  lookahead_adder #(
      .N(N),
      .D(D)
  ) dut (
      .cin   (cin),
      .addend(addend),
      .augend(augend),
      .result(result),
      .cout  (cout)
  );

  // clock (CLK_HALF ns half-period; 100 MHz at the default 5)
  initial clk = 1'b0;
  always #(CLK_HALF) clk = ~clk;

  // run_test: perform one bit-serial addition with a+b+c and check both
  // models against the golden reference and against each other.
  //   Prints a PASS line per vector while the module-level `verbose`
  //   flag is set; failures are always printed.
  task automatic run_test;
    input [N-1:0] a;
    input [N-1:0] b;
    input c;
    reg [N:0] expected;
    reg ok;
    begin
      expected = a + b + {{(N - 1) {1'b0}}, c};  // golden reference (N+1 bits;
                                                 // c zero-extended to N bits)

      // clear the carry register
      @(negedge clk);
      addend = a;
      augend = b;
      cin    = c;

      // measure
      @(negedge clk);

      // sample
      tests = tests + 1;
      ok  = ({cout, result} === expected);

      if (ok) begin
        if (verbose)
          $display(
              "PASS: %0d + %0d + %0d = %0d (cout = %b)",
              a,
              b,
              c,
              expected[N-1:0],
              expected[N]
          );
      end else begin
        errors = errors + 1;
        $display("FAIL: %0d + %0d + %0d  expected sum = %0d cout = %b", a, b, c, expected[N-1:0],
                 expected[N]);
        $display("      structural: sum = %0d cout = %b", result, cout);
      end
    end
  endtask

  // Stimulus
  integer i, j, k;
  initial begin
    errors     = 0;
    tests      = 0;
    verbose    = 1'b1;  // print PASS reports
    cin        = 1'b0;
    addend     = {N{1'b0}};
    augend     = {N{1'b0}};

    // explicit tests
    run_test(4'd5, 4'd1, 1'b0);
    run_test(4'd5, 4'd0, 1'b1);
    run_test(4'd0, 4'd0, 1'b0);
    run_test(4'd0, 4'd0, 1'b1);
    run_test(4'd15, 4'd15, 1'b0);
    run_test(4'd15, 4'd15, 1'b1);
    run_test(4'd10, 4'd7, 1'b1);

    // exhaustive sweep
    verbose = 1'b0;  // silence PASS reports
    for (i = 0; i < (1 << N); i = i + 1) begin
      for (j = 0; j < (1 << N); j = j + 1) begin
        for (k = 0; k < 2; k = k + 1) begin
          run_test(i[N-1:0], j[N-1:0], k[0]);
        end
      end
    end

    // summary
    $display("------------------------------------------------");
    $display("vectors tested : %0d", tests);
    if (errors == 0)
      $display("correctness    : PASS - both models match addend+augend+cin for every vector");
    else $display("correctness    : %0d FAILURE(S) vs reference", errors);
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("TEST(S) FAILED");
    $display("------------------------------------------------");

    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("sim/lookahead_adder_tb.vcd");
    $dumpvars(0);
  end

endmodule
