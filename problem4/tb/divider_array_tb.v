// Testbench for the CAS array divider (problem4, Fig 4.3)
//
// every vector is checked against the reference
//
// Delay report: between vectors both inputs are driven to x
// each vector's measured delay is the time its result
// takes to settle from a clean slate
// Prints min/avg/max/spread when D > 0.

`timescale 1ns / 1ps

module divider_array_tb;

  localparam int N = 4;

  // gate delay of the DUT, in `timescale units
  localparam int D = 1;
  localparam int SETTLE = 100;

  reg  [N-1:0] dividend;
  reg  [N-1:0] divisor;
  wire [N-1:0] quotient;
  wire [N-1:0] remainder;

  integer        errors;
  integer        tests;
  reg            verbose;

  time t_drive;
  // Check last time output vec has changed
  time last_change = 0;
  int unsigned measured = 0;  // vectors that produced output activity
  int unsigned no_change = 0;  // vectors with no output transition
  time dly_min, dly_max;  // ns (the `timescale unit)
  time dly_sum = 0;  // running total, for the average

  divider_array #(
      .N(N),
      .D(D)
  ) dut (
      .dividend (dividend),
      .divisor  (divisor),
      .quotient (quotient),
      .remainder(remainder)
  );

  always @(quotient or remainder) last_change = $time;

  // run_test: divide dvd by dvr, check against the reference
  // Prints a PASS line per vector while `verbose` is set; failures are
  // always printed.
  task automatic run_test;
    input [N-1:0] dvd;
    input [N-1:0] dvr;
    reg [N-1:0] exp_q;
    reg [N-1:0] exp_r;
    time dly;
    begin
      exp_q = dvd / dvr;  // reference (dvr >= 1 by construction)
      exp_r = dvd % dvr;

      // Set all inputs to x before measuring propagation
      dividend = 'x;
      divisor  = 'x;
      #(SETTLE);

      dividend = dvd;
      divisor  = dvr;
      t_drive  = $time;
      #(SETTLE);

      tests = tests + 1;
      if (last_change > t_drive) begin
        dly = last_change - t_drive;
        if (measured == 0 || dly < dly_min) dly_min = dly;
        if (measured == 0 || dly > dly_max) dly_max = dly;
        dly_sum  += dly;
        measured++;
      end else begin
        no_change++;
      end

      if (quotient === exp_q && remainder === exp_r) begin
        if (verbose)
          $display("PASS: %0d / %0d = %0d remainder %0d", dvd, dvr, quotient, remainder);
      end else begin
        errors = errors + 1;
        $display("FAIL: %0d / %0d  got q = %0d r = %0d, expected q = %0d r = %0d", dvd, dvr,
                 quotient, remainder, exp_q, exp_r);
      end
    end
  endtask

  integer a, b;
  initial begin
    errors   = 0;
    tests    = 0;
    verbose  = 1'b1;  // print PASS reports for the vectors
    dividend = {N{1'b0}};
    divisor  = {N{1'b0}};

    run_test(4'd7, 4'd2);  // 7/2
    run_test(4'd6, 4'd2);  // 6/2
    run_test(4'd9, 4'd4);  // 9/4
    // edge cases
    run_test(4'd0, 4'd1);  // 0/1
    run_test(4'd15, 4'd15);  // x/x
    run_test(4'd15, 4'd13);  // lots of carries
    run_test(4'd15, 4'd1);  // max quotient

    // exhaustive sweep (divisor >= 1)
    verbose = 1'b0;
    for (a = 0; a < (1 << N); a = a + 1) begin
      for (b = 1; b < (1 << N); b = b + 1) begin
        run_test(a[N-1:0], b[N-1:0]);
      end
    end

    // summary
    $display("------------------------------------------------");
    $display("vectors tested : %0d", tests);
    if (errors == 0) $display("correctness    : PASS - q and r match divmod for every vector");
    else $display("correctness    : %0d FAILURE(S) vs reference", errors);
    if (errors == 0) $display("ALL TESTS PASSED");
    else $display("TEST(S) FAILED");
    $display("------------------------------------------------");

    // propagation-delay report, delays in ns
    if (D > 0) begin
      if (measured > 0)
        $display("DELAY N=%0d: min=%0d avg=%0d max=%0d spread=%0d (%0d changed, %0d no-change)",
                 N, dly_min, dly_sum / time'(measured), dly_max, dly_max - dly_min, measured,
                 no_change);
      else $display("DELAY N=%0d: no output transitions measured", N);
    end

    $finish;
  end

  // Waveform dump
  initial begin
    $dumpfile("sim/divider_array_tb.vcd");
    $dumpvars(0);
  end

endmodule
