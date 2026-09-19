
// Carry-generate
//
// carry[i] = g[i]
//          | p[i]&g[i-1]
//          | p[i]&p[i-1]&g[i-2]
//          | ...
//          | p[i]&p[i-1]&...&p[0]&cin
// cout = carry[N-1]
module carry_gen #(
    // operand width (number of carries generated)
    parameter int N = 4
) (
    input  wire [N-1:0] p,      // bitwise propagate (a ^ b)
    input  wire [N-1:0] g,      // bitwise generate  (a & b)
    input  wire         cin,    // carry into bit 0
    output wire [N-1:0] carry,  // carry
    output wire         cout    // carry[N-1]
);
  genvar i, k;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      // OR terms for carry[i]: i+1 generate terms + 1 cin term
      wire [i+1:0] term;

      // term k (k = 0..i): g[k] & p[k+1] & ... & p[i]
      for (k = 0; k <= i; k = k + 1) begin : g_term
        if (k == i) begin : g_nog
          // no propagate factors: term = g[i]
          buf1 #(1) b (
              .a(g[k]),
              .y(term[k])
          );
        end else begin : g_pg
          and_2n #(
              .N(1),
              .I(i - k + 1)
          ) a (
              .d({p[i:k+1], g[k]}),
              .y(term[k])
          );
        end
      end

      // term i+1: cin & p[0] & ... & p[i]
      and_2n #(
          .N(1),
          .I(i + 2)
      ) a_cin (
          .d({p[i:0], cin}),
          .y(term[i+1])
      );

      // carry[i] = OR of all i+2 terms
      or_2n #(
          .N(1),
          .I(i + 2)
      ) o (
          .d(term),
          .y(carry[i])
      );
    end
  endgenerate

  buf1 #(1) cbuf (
      .a(carry[N-1]),
      .y(cout)
  );
endmodule
