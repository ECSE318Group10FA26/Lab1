// divider_tb.v
//
// Self-checking testbench for the non-restoring divider
//
// Instanciate a bunch of different N sizes to test the divider
//
// Timing is measured with a last-changed monitor

`timescale 1ns / 1ps

module divider_check #(
    parameter int N = 4,
    parameter int RAND = 300,  // random vectors on top of the explicit ones
    // DUT gate delays (divider defaults)
    parameter int DG = 2,
    parameter int DD = 1,
    parameter bit VERBOSE = 0  // print PASS by default
) (
    input  wire clk,
    output reg  fin
);
  reg             rst;
  reg             start;
  reg     [N-1:0] dividend;
  reg     [N-1:0] divisor;
  wire    [N-1:0] quotient;
  wire    [  N:0] remainder;
  wire            done;

  integer         errors;
  integer         tests;
  reg             verbose;

  // per-cycle delay is measured from the clock edge
  // to the end of movement on output
  time t_edge;
  time last_change;
  time dly;
  time dly_min, dly_max, dly_sum;
  int unsigned measured;

  always @(quotient or remainder or done or dut.R or dut.D or dut.hot or dut.R_next or dut.M_next or dut.D_in)
    last_change = $time;

  always @(posedge clk) t_edge = $time;

  always @(negedge clk) begin
    if (t_edge != 0 && last_change > t_edge) begin
      dly = last_change - t_edge;
      if (measured == 0 || dly < dly_min) dly_min = dly;
      if (measured == 0 || dly > dly_max) dly_max = dly;
      dly_sum  += dly;
      measured++;
    end
  end

  // DUT
  divider #(
      .N (N),
      .DG(DG),
      .DD(DD)
  ) dut (
      .clk      (clk),
      .clear    (rst),
      .start    (start),
      .dividend (dividend),
      .divisor  (divisor),
      .quotient (quotient),
      .remainder(remainder),
      .done     (done)
  );

  // run_test: apply one division, wait for done, check against the
  // reference.  Prints a PASS line while VERBOSE is set; failures are
  // always printed.
  task automatic run_test;
    input [N-1:0] dvd;
    input [N-1:0] dvr;
    reg [N-1:0] exp_q;
    reg [N:0] exp_r;
    integer timeout;
    begin
      exp_q = dvd / dvr;  // reference (dvr >= 1 by construction)
      exp_r = dvd % dvr;

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

      tests = tests + 1;
      if (done !== 1'b1) begin
        $display("FAIL N=%0d: %0d/%0d  TIMEOUT waiting for done", N, dvd, dvr);
        errors = errors + 1;
      end else if (quotient === exp_q && remainder === exp_r) begin
        if (verbose)
          $display("PASS N=%0d: %0d/%0d  quotient = %0d  remainder = %0d", N, dvd, dvr, quotient,
                   remainder);
      end else begin
        $display({"FAIL N=%0d: %0d/%0d  got quotient = %0d remainder = %0d, ",
                  "expected quotient = %0d remainder = %0d"}, N, dvd, dvr, quotient, remainder,
                 exp_q, exp_r);
        errors = errors + 1;
      end
    end
  endtask

  // Stimulus
  integer a, b, t;
  reg [N-1:0] D_arg, M_arg;
  initial begin
    fin         = 1'b0;
    errors      = 0;
    tests       = 0;
    verbose     = VERBOSE;
    t_edge      = 0;
    last_change = 0;
    dly_sum     = 0;
    measured    = 0;
    rst         = 1'b1;
    start    = 1'b0;
    dividend = {N{1'b0}};
    divisor  = {N{1'b0}};

    repeat (3) @(negedge clk);
    rst = 1'b0;

    if (N >= 4) begin
      run_test(4'd7, 4'd2);  // 7/2
      run_test(4'd6, 4'd2);  // 6/2
      run_test(4'd9, 4'd4);  // 9/4
    end
    // edge cases
    run_test({N{1'b0}}, {{N-1{1'b0}}, 1'b1});  // 0/1
    run_test({N{1'b1}}, {N{1'b1}});  // max/max
    run_test({N{1'b1}}, {N{1'b1}} - 2);
    run_test({N{1'b1}}, {{N-1{1'b0}}, 1'b1});  // max quotient

    verbose = 1'b0;  // quiet for the sweep / random vectors

    // exhaustive sweep (divisor >= 1) where small enough to be cheap
    if (N <= 5) begin
      for (a = 0; a < (1 << N); a = a + 1) begin
        for (b = 1; b < (1 << N); b = b + 1) begin
          run_test(a[N-1:0], b[N-1:0]);
        end
      end
    end

    // random vectors (one fresh random bit per input bit; divisor != 0)
    for (t = 0; t < RAND; t = t + 1) begin
      for (int k = 0; k < N; k++) D_arg[k] = bit'($urandom);
      do begin
        for (int k = 0; k < N; k++) M_arg[k] = bit'($urandom);
      end while (M_arg == 0);
      run_test(D_arg, M_arg);
    end

    if (errors == 0) $display("PASS N=%0d (%0d vectors)", N, tests);
    else $display("FAIL N=%0d: %0d/%0d errors", N, errors, tests);

    // per-cycle propagation-delay report, in `timescale units
    // max should match DG*depth+DD, depth from ./gates.sh
    if (DG > 0 || DD > 0) begin
      if (measured > 0)
        $display("DELAY N=%0d: min=%0d avg=%0d max=%0d spread=%0d (%0d active cycles)", N, dly_min,
                 dly_sum / time'(measured), dly_max, dly_max - dly_min, measured);
      else $display("DELAY N=%0d: no DUT activity measured", N);
    end

    fin = 1'b1;
  end

endmodule

module divider_tb;
  localparam int CLK_HALF = 90;

  reg         clk;
  wire  [5:0] fin;

  // Maybe we should tune the clock so its not the same for each bench
  initial clk = 1'b0;
  always #(CLK_HALF) clk = ~clk;

  // Test a bunch of N
  // TODO: update problem.env with new stuff
  divider_check #(.N(2)) c_2 (.clk(clk), .fin(fin[0]));
  divider_check #(.N(3)) c_3 (.clk(clk), .fin(fin[1]));
  divider_check #(
      .N(4),
      .VERBOSE(1)
  ) c_4 (
      .clk(clk),
      .fin(fin[2])
  );
  divider_check #(.N(5)) c_5 (.clk(clk), .fin(fin[3]));
  divider_check #(.N(8)) c_8 (.clk(clk), .fin(fin[4]));
  divider_check #(.N(16)) c_16 (.clk(clk), .fin(fin[5]));

  // Waveform dump; finish once every instance has reported
  initial begin
    $dumpfile("sim/divider_tb.vcd");
    $dumpvars(0);
    wait (&fin);
    $display("------------------------------------------------");
    $display("all instances finished");
    $finish;
  end
endmodule
