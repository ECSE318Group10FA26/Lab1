// n-bit operand register with parallel load
//
// load = 1 : parallel load d_in
// load = 0 : shift one position toward the LSB (a 0 enters the MSB),
//            so q[0] presents the stored word serially, LSB first
//
// Depends: mux, dff_sc

module piso_reg #(
    // data width of register, in bits
    parameter int N = 2,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire [N-1:0] d_in,
    output wire [N-1:0] q
);
  wire [N-1:0] d_next;  // next state of the register

  // d_next = load ? d_in : q shifted toward the LSB (0 enters the MSB).
  // Mux input packing: input 0 in the low N bits, input 1 above it.
  mux #(
      .N(N),
      .S(1),
      .D(D)
  ) m (
      .d  ({d_in, {1'b0, q[N-1:1]}}),
      .sel(load),
      .y  (d_next)
  );

  dff_sc #(
      .N(N)
  ) ff (
      .clk  (clk),
      .clear(clear),
      .d    (d_next),
      .q    (q)
  );
endmodule
