// N-bit D flip-flop / register with synchronous clear
//
// N = 1 (the default) is a single flip-flop, N > 1 a parallel register.

module dff_sc #(
    // register width in bits
    parameter int N = 1,
    // Bug where slang will mark something as unused if only used in a delay
    `pragma diagnostic push
    `pragma diagnostic ignore="-Wunused-parameter"
    // dff delay, in `timescale units (clock-to-q)
    parameter int D = 0
    `pragma diagnostic pop
) (
    input  wire         clk,
    // synchronous clear
    input  wire         clear,
    input  wire [N-1:0] d,
    output reg  [N-1:0] q
);
  always @(posedge clk) begin
    if (clear) q <= #(D) {N{1'b0}};
    else q <= #(D) d;
  end
endmodule
