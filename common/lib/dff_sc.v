// N-bit D flip-flop / register with synchronous clear
//
// N = 1 (the default) is a single flip-flop, N > 1 a parallel register.

module dff_sc #(
    // register width in bits
    parameter N = 1
) (
    input  wire         clk,
    // synchronous clear
    input  wire         clear,
    input  wire [N-1:0] d,
    output reg  [N-1:0] q
);
    always @(posedge clk) begin
        if (clear)
            q <= {N{1'b0}};
        else
            q <= d;
    end
endmodule
