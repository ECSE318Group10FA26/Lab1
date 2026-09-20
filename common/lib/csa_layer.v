module csa_layer #(
    // size of input in bits
    parameter int N = 1,
    // Number of input vectors to reduce
    parameter int M = 3,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    // packed inputs: input k = d[k*N +: N]
    input  wire [N*M-1:0] in_vecs,
    output wire [N*((M/3) + (M%3))-1:0] out_vecs,
    output wire [N*(M/3)-1:0] carry_outs  // Higher order number (N+1)
);
  localparam int Groups = M / 3;
  localparam int Passthrough = M % 3;

  genvar i;
  generate
    // Group inputs into sets of 3 and apply full adders in parallel
    for (i = 0; i < Groups; i++) begin : gen_csa_group
      csa #(
          .N(N),
          .D(D)
      ) gen_csa (
          .x(in_vecs[(3*i)*N+:N]),
          .y(in_vecs[(3*i+1)*N+:N]),
          .z(in_vecs[(3*i+2)*N+:N]),
          .s(out_vecs[i*N+:N]),
          .c(carry_outs[i*N+:N])
      );
    end

    // Pass through leftover vectors that couldn't form a group of 3
    for (i = 0; i < Passthrough; i++) begin : gen_passthrough
      buf1 #(
          .N(N)
      ) gen_buf (
          .a(in_vecs[(3*Groups+i)*N+:N]),
          .y(out_vecs[(Groups+i)*N+:N])
      );
    end
  endgenerate
endmodule
