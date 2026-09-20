// n-bit serial-in/parallel-out shift register
//
// serial input sin enters at the MSB and the word shifts toward the LSB
// every clock; after n clocks the register holds the last n input bits
// in arrival order (first bit received ends up at q[0])
//
// Depends: dff_sc

module sipo_reg #(
    // data width of register, in bits
    parameter int N = 2,
    parameter int DD = 0
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         sin,
    output wire [N-1:0] q
);
  // next state: sin enters at the MSB, the rest shifts toward the LSB
  dff_sc #(
      .N(N),
      .D(DD)
  ) ff (
      .clk  (clk),
      .clear(clear),
      .d    ({sin, q[N-1:1]}),
      .q    (q)
  );
endmodule
