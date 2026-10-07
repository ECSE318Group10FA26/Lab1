// Critical-path testbench for the 4-bit CLA (Problem 2b/2c)
//
// Gate delay D = 10
//
// Part 1: the worst-case input from C0. Hold A = 1111, B = 0000 so every
//         propagate bit p[i] = 1, then flip cin 0 -> 1. The carry must
//         travel from C0 all the way to the MSB.
// Part 2: sweep every (A, B) with cin flipping both ways and report the
//         slowest one - proves part 1 is worst case

`timescale 1ns / 1ps

module lookahead_adder_cp_tb;

  localparam N = 4;
  localparam D = 10;       // gate delay 10 units
  localparam SETTLE = 200; // time longer than any path

  reg  [N-1:0] addend, augend;
  reg          cin;
  wire [N-1:0] result;
  wire         cout;

  lookahead_adder #(.N(N), .D(D)) dut (
      .cin(cin), .addend(addend), .augend(augend),
      .result(result), .cout(cout)
  );

  // ---- timestamps of the last change on each MSB output ----
  time t0, t_msb, t_cout;
  reg  trace;  // print internal net changes during Part 1 only
  always @(result[N-1]) t_msb  = $time;
  always @(cout)        t_cout = $time;

  // Part 1 trace: every net on the C0 -> MSB route
  always @(dut.carry)  if (trace) $display("  t=%2d  carry  = %b", $time - t0, dut.carry);
  always @(result)     if (trace) $display("  t=%2d  result = %b", $time - t0, result);
  always @(cout)       if (trace) $display("  t=%2d  cout   = %b", $time - t0, cout);
  always @(dut.cg.g_bit[2].term)
    if (trace) $display("  t=%2d  carry[2] terms = %b", $time - t0, dut.cg.g_bit[2].term);
  always @(dut.cg.g_bit[2].a_cin.g_rec.lo)
    if (trace) $display("  t=%2d  carry[2] cin-AND first level (cin&p0) = %b",
                        $time - t0, dut.cg.g_bit[2].a_cin.g_rec.lo);
  always @(dut.cg.g_bit[2].o.g_rec.hi)
    if (trace) $display("  t=%2d  carry[2] OR first level (term2|term3) = %b",
                        $time - t0, dut.cg.g_bit[2].o.g_rec.hi);

  initial begin
      $dumpfile("sim/lookahead_adder_cp_tb.vcd");
      $dumpvars;
      #(2*SETTLE) $dumpoff;   // stop after part 1 for wave
  end

  integer a, b, c;
  time worst, d;
  reg [N-1:0] wa, wb;
  reg wc;

  initial begin
    // ---------------- Part 1 ----------------
    trace  = 0;
    addend = 4'b1111;
    augend = 4'b0000;
    cin    = 1'b0;
    #(SETTLE);
    $display("Part 1: A=1111 B=0000, cin 0 -> 1 (p = 1111, g = 0000)");
    trace = 1;
    t0    = $time;
    cin   = 1'b1;
    #(SETTLE);
    trace = 0;
    $display("  => result[3] settled at %0d, cout at %0d (after cin changed)",
             t_msb - t0, t_cout - t0);

    // ---------------- Part 2 ----------------
    worst = 0;
    for (a = 0; a < (1 << N); a = a + 1)
      for (b = 0; b < (1 << N); b = b + 1)
        for (c = 0; c < 2; c = c + 1) begin
          addend = a; augend = b; cin = c[0];
          #(SETTLE);
          t0 = $time; t_msb = 0;
          cin = ~c[0];  // only C0 changes
          #(SETTLE);
          d = (t_msb > t0) ? t_msb - t0 : 0;
          if (d > worst) begin
            worst = d; wa = a; wb = b; wc = c[0];
          end
        end
    $display("Part 2: slowest C0 -> result[3] over all inputs = %0d", worst);
    $display("        first found at A=%b B=%b, cin %b -> %b", wa, wb, wc, ~wc);
    $finish;

  end
endmodule
