// divider_array.v - non-restoring array divider
//
//   quotient = dividend / divisor,  remainder = dividend % divisor
//
// Does not function properly for dividing by 0
//
// Depends: common/lib

module divider_array #(
    // operand width in bits
    parameter int N = 4,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] dividend,
    input  wire [N-1:0] divisor,
    output wire [N-1:0] quotient,
    output wire [N-1:0] remainder
);
  // pr[k*(N+1) +: N+1] : partial remainder entering row k (bit N = sign).
  wire [N*(N+1)-1:0] pr;
  // rs[k*N +: N]       : sum bits of row k
  wire [N*N-1:0] rs;

  // first row: partial remainder = dividend's MSB
  buf1 #(.N(N+1)) buf_init ({{N{1'b0}}, dividend[N-1]}, pr[(N-1)*(N+1)+:N+1]);

  genvar k;
  generate
    for (k = N - 1; k >= 0; k = k - 1) begin : g_row
      // subtract on the first row, thereafter follow the previous quotient bit
      wire op;

      if (k == N - 1) begin : g_first
        buf (op, 1'b1);
      end else begin : g_rest
        buf (op, quotient[k+1]);
      end

      cas_row #(
          .N(N),
          .D(D)
      ) u_row (
          .pr     (pr[k*(N+1)+:N+1]),
          .divisor(divisor),
          .op     (op),
          .sum    (rs[k*N+:N]),
          .q      (quotient[k])
      );

      // shift the partial remainder left, bring down the next dividend bit
      if (k > 0) begin : g_shift
        buf1 #(.N(N+1)) buf_next ({rs[k*N+:N], dividend[k-1]}, pr[(k-1)*(N+1)+:N+1]);
      end
    end
  endgenerate

  // remainder correction: q[0] = 0 means the last result went negative,
  // add the divisor back
  wire q0n;
  wire [N-1:0] cor;  // divisor corrector, gated by ~q[0]
  wire [N:0] cc;  // correction carry chain (final carry-out unused)

  not #(D) (q0n, quotient[0]);
  buf (cc[0], 1'b0);

  genvar j;
  generate
    for (j = 0; j < N; j = j + 1) begin : g_fix
      and #(D) (cor[j], divisor[j], q0n);
      full_adder #(D) fa (
          .a   (rs[j]),
          .b   (cor[j]),
          .cin (cc[j]),
          .sum (remainder[j]),
          .cout(cc[j+1])
      );
    end
  endgenerate
endmodule
