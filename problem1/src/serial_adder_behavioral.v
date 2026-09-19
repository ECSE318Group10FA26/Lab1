// Serial Adder - behavioral implementation
module serial_adder_behavioral #(
    parameter int N = 4
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire         cin,
    input  wire [N-1:0] addend,
    input  wire [N-1:0] augend,
    output reg  [N-1:0] result,
    output reg          cout
);
  always @(posedge clk) begin
    if (clear) begin
      result <= {N{1'b0}};
      cout   <= 1'b0;
    end else if (load) begin
      {cout, result} <= addend + augend + {{(N - 1) {1'b0}}, cin};
    end
    // otherwise hold: the result stays valid while the structural
    // model finishes its n shift/add cycles
  end
endmodule
