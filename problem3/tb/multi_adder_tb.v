// Self-checking testbench for multi_adder (M words of N bits -> W-bit sum).
//
// Each multi_adder_check instance runs the dut and compares against a 64-bit sum.

`timescale 1ns / 1ps

module multi_adder_check #(
    parameter int N = 4,
    parameter int M = 9,
    parameter int RAND = 300,
    // gate delay of the DUT, in `timescale units
    parameter int D = 1,
    // settle delay between driving inputs and sampling the result; must
    // exceed the DUT's worst-case propagation delay (grows with D and M)
    parameter int SETTLE = 100
);
  localparam int W = N + $clog2(M);

  logic [N*M-1:0] in_vecs;
  wire  [  W-1:0] result;

  multi_adder #(
      .N(N),
      .M(M),
      .D(D)
  ) dut (
      .in_vecs(in_vecs),
      .result (result)
  );

  int unsigned errors = 0;
  int unsigned tests = 0;

  // check() drives all inputs to x and lets outputs go unknown before
  // applying each real vector
  time t_drive;
  // Check last time output vec has changed
  time last_change = 0;
  int unsigned measured = 0;  // vectors that produced output activity
  int unsigned no_change = 0;  // vectors with no output transition
  time dly_min, dly_max;  // ns (the `timescale unit)
  time dly_sum = 0;  // running total, for the average

  always @(result) last_change = $time;

  task automatic check();
    longint unsigned total;
    time dly;
    logic [N*M-1:0] vec;
    total = 0;
    for (int k = 0; k < M; k++) total += 64'(in_vecs[k*N+:N]);
    vec = in_vecs;
    // Reset the whole structure to x so we can accurately measure timing information
    in_vecs = 'x;
    #(SETTLE);
    in_vecs = vec;
    t_drive = $time;
    #(SETTLE);
    tests++;
    if (last_change > t_drive) begin
      dly = last_change - t_drive;
      if (measured == 0 || dly < dly_min) dly_min = dly;
      if (measured == 0 || dly > dly_max) dly_max = dly;
      dly_sum += dly;
      measured++;
    end else begin
      no_change++;
    end
    if (total >= (64'd1 << W)) begin
      errors++;
      $display("FAIL N=%0d M=%0d: sum %0d does not fit W=%0d bits", N, M, total, W);
    end
    if (result !== total[W-1:0]) begin
      errors++;
      $display("FAIL N=%0d M=%0d: result=%0d expected=%0d", N, M, result, total[W-1:0]);
    end
  endtask

  initial begin
    // all zeros
    in_vecs = '0;
    check();
    // all ones (maximum sum -> width stress)
    in_vecs = '1;
    check();
    // walking single full word
    for (int k = 0; k < M; k++) begin
      in_vecs = '0;
      in_vecs[k*N+:N] = '1;
      check();
    end
    // random vectors (one fresh random bit per input bit)
    for (int t = 0; t < RAND; t++) begin
      for (int k = 0; k < M * N; k++) in_vecs[k] = bit'($urandom);
      check();
    end
    if (errors == 0) $display("PASS N=%0d M=%0d (%0d vectors, W=%0d)", N, M, tests, W);
    else $display("FAIL N=%0d M=%0d: %0d/%0d errors", N, M, errors, tests);

    // propagation-delay report, delays in ns (only meaningful with D > 0)
    if (D > 0) begin
      if (measured > 0)
        $display("DELAY N=%0d M=%0d: min=%0d avg=%0d max=%0d spread=%0d (%0d changed, %0d no-change)",
                 N, M, dly_min, dly_sum / time'(measured), dly_max, dly_max - dly_min,
                 measured, no_change);
      else $display("DELAY N=%0d M=%0d: no output transitions measured", N, M);
    end
  end
endmodule

module multi_adder_tb;
  // small / edge cases
  multi_adder_check #(
      .N(1),
      .M(1)
  ) c_1_1 ();
  multi_adder_check #(
      .N(1),
      .M(2)
  ) c_1_2 ();
  multi_adder_check #(
      .N(1),
      .M(3)
  ) c_1_3 ();
  multi_adder_check #(
      .N(2),
      .M(7)
  ) c_2_7 ();
  multi_adder_check #(
      .N(3),
      .M(5)
  ) c_3_5 ();
  // hand-traced references
  multi_adder_check #(
      .N(4),
      .M(3)
  ) c_4_3 ();
  multi_adder_check #(
      .N(4),
      .M(4)
  ) c_4_4 ();
  multi_adder_check #(
      .N(4),
      .M(9)
  ) c_4_9 ();
  multi_adder_check #(
      .N(8),
      .M(9)
  ) c_8_9 ();
  // sweep M at N = 8
  multi_adder_check #(
      .N(8),
      .M(1)
  ) c_8_1 ();
  multi_adder_check #(
      .N(8),
      .M(2)
  ) c_8_2 ();
  multi_adder_check #(
      .N(8),
      .M(3)
  ) c_8_3 ();
  multi_adder_check #(
      .N(8),
      .M(4)
  ) c_8_4 ();
  multi_adder_check #(
      .N(8),
      .M(5)
  ) c_8_5 ();
  multi_adder_check #(
      .N(8),
      .M(6)
  ) c_8_6 ();
  multi_adder_check #(
      .N(8),
      .M(7)
  ) c_8_7 ();
  multi_adder_check #(
      .N(8),
      .M(8)
  ) c_8_8 ();
  multi_adder_check #(
      .N(8),
      .M(15)
  ) c_8_15 ();
  multi_adder_check #(
      .N(8),
      .M(16)
  ) c_8_16 ();
  // larger
  multi_adder_check #(
      .N(8),
      .M(32)
  ) c_8_32 ();
  multi_adder_check #(
      .N(16),
      .M(32)
  ) c_16_32 ();
  multi_adder_check #(
      .N(8),
      .M(60)
  ) c_8_60 ();
  // humungous test benches
  multi_adder_check #(
      .N(4),
      .M(64)
  ) c_4_64 ();
  multi_adder_check #(
      .N(8),
      .M(100)
  ) c_8_100 ();
  multi_adder_check #(
      .N(32),
      .M(4)
  ) c_32_4 ();

  // Waveform dump
  initial begin
    $dumpfile("sim/multi_adder_tb.vcd");
    $dumpvars(0);
  end
endmodule
