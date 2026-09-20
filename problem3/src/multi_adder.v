// multi_adder - sum M words of N bits into one W = N + clog2(M)-bit result.
//
//   packed inputs: word k = in_vecs[k*N +: N]  (all weight 1)
//   result       = in_vecs[0] + in_vecs[1] + ... + in_vecs[M-1]
//
// The final adder's carry-out is provably always 0 (the total sum is
// strictly less than 2^W), so the W-bit sum is the complete result.

module multi_adder #(
    parameter int N = 4,
    parameter int M = 3,
    // gate delay, in `timescale units
    parameter int D = 0,
    // derived - do not override
    parameter int W = N + $clog2(M)
) (
    input  wire [N*M-1:0] in_vecs,
    output wire [  W-1:0] result
);
  wire [2*W-1:0] reduced;
  wire [W-1:0] sum;
  wire cout;  // always 0; dropped

  csa_stack #(
      .N(N),
      .M(M),
      .D(D)
  ) stack (
      .in_vecs (in_vecs),
      .out_vecs(reduced)
  );

  lookahead_adder #(
      .N(W),
      .D(D)
  ) final_adder (
      .cin   (1'b0),
      .addend(reduced[0+:W]),
      .augend(reduced[W+:W]),
      .result(sum),
      .cout  (cout)
  );

  buf1 #(
      .N(W)
  ) gen_result (
      .a(sum),
      .y(result)
  );
endmodule
