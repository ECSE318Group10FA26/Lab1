// Lookahead Adder
//
// g = a & b
// p = a x b
// carry = carry_gen(p, g, cin)
// r = p x {carry, cin}
// cout = carry[N]
module lookahead_adder #(
    // Width of inputs in bits
    parameter int N = 4
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
      .N(N)
  ) and_gen (
      .a(addend),
      .b(augend),
      .y(gen)
  );

  xor2 #(
      .N(N)
  ) xor_prop (
      .a(addend),
      .b(augend),
      .y(propagate)
  );

  carry_gen #(
      .N(N)
  ) cg (
      .p    (propagate),
      .g    (gen),
      .cin  (cin),
      .carry(carry),
      .cout (cout)
  );

  xor2 #(
      .N(N)
  ) xor_res (
      .a(propagate),
      .b({carry[N-2:0], cin}),
      .y(result)
  );

endmodule
