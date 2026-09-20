
// cas_row: one row of the divider array
//
// an (N+1)-bit ripple-carry CAS with 1-bit op
//   {q, sum} = pr +/- divisor   (op = 1 subtracts, 0 = adds)
//
// The rightmost carry-in is the op itself (for 2s compliment)
// The leftmost cell is a sign-extension cell (b = 0); its carry-out is q,
// the quotient bit (1 = result non-negative)
module cas_row #(
    // operand width in bits (the row is N+1 cells wide)
    parameter int N = 4,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N:0]   pr,       // partial remainder in (bit N = sign)
    input  wire [N-1:0] divisor,  // divisor bits (sign cell gets b = 0)
    input  wire         op,       // row operation: 1 = subtract, 0 = add
    output wire [N-1:0] sum,      // row result, low N bits
    output wire         q         // quotient bit: carry-out of the sign cell
);
  wire [N:0] c;  // carry chain, rippling right to left; c[0] = op
  // Intentionally ignore and throw away the sgn bit
  `pragma diagnostic push
  `pragma diagnostic ignore="-Wunused-but-set-net"
  wire sgn;  // sign cell's sum bit
  `pragma diagnostic pop

  buf (c[0], op);

  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_cas
      cas #(
          .D(D)
      ) u_cas (
          .a   (pr[i]),
          .b   (divisor[i]),
          .cin (c[i]),
          .op  (op),
          .s   (sum[i]),
          .cout(c[i+1])
      );
    end
  endgenerate

  // sign-extension cell (b = 0); its carry-out is the row's quotient bit
  cas #(
      .D(D)
  ) u_sign (
      .a   (pr[N]),
      .b   (1'b0),
      .cin (c[N]),
      .op  (op),
      .s   (sgn),
      .cout(q)
  );
endmodule
