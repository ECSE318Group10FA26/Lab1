// Wide N-sized Carry Save Adder
module csa #(
    // data width of input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] x,
    input  wire [N-1:0] y,
    input  wire [N-1:0] z,
    output wire [N-1:0] s,
    output wire [N-1:0] c
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      full_adder #(D) fa (x[i], y[i], z[i], s[i], c[i]);
    end
  endgenerate
endmodule
