// clk_gen.v - simple reusable clock generator
//
//   clk starts at 0 and toggles every T/2 `timescale units (period T).
//   Use an even T for a 50% duty cycle (T/2 is an integer division).

module clk_gen #(
    // clock period, in `timescale units
    parameter int T = 10
) (
    output reg clk
);
    initial clk = 1'b0;

    always #(T / 2) clk = ~clk;
endmodule
