// Lookahead Adder
//
// g = a & b
// p = a x b
// carry = carry_gen(p, g, cin)
// r = p x {carry, cin}
// cout = carry[N]
module lookahead_adder #(
    // Width of inputs in bits
    parameter int N = 4,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire         cin,     // initial carry, captured while operands load
    input  wire [N-1:0] addend,
    input  wire [N-1:0] augend,
    output wire [N-1:0] result,
    output wire         cout     // final carry = (N+1)-th bit of the sum
);
  wire [N-1:0] propagate;
  wire [N-1:0] gen;
  wire [N-1:0] carry;

  and2 #(
      .N(N),
      .D(D)
  ) and_gen (
      .a(addend),
      .b(augend),
      .y(gen)
  );

  xor2 #(
      .N(N),
      .D(D)
  ) xor_prop (
      .a(addend),
      .b(augend),
      .y(propagate)
  );

  carry_gen #(
      .N(N),
      .D(D)
  ) cg (
      .p    (propagate),
      .g    (gen),
      .cin  (cin),
      .carry(carry),
      .cout (cout)
  );

  // result[i] = p[i] ^ carry[i-1], with carry[-1] = cin
  if (N == 1) begin : g_res1
    xor2 #(
        .N(1),
        .D(D)
    ) xor_res (
        .a(propagate),
        .b(cin),
        .y(result)
    );
  end else begin : g_resn
    xor2 #(
        .N(N),
        .D(D)
    ) xor_res (
        .a(propagate),
        .b({carry[N-2:0], cin}),
        .y(result)
    );
  end

endmodule
