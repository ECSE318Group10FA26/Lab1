// wide (N-bit) gate library cells
//
//   buf1 #(N)    : y = a
//   not1 #(N)    : y = ~a
//   and2 #(N)    : y = a & b
//   or2  #(N)    : y = a | b
//   and_n #(N,I) : y = AND of the I packed input words (word k = d[k*N +: N])
//   or_n  #(N,I) : y = OR  of the I packed input words
//   and_2n #(N,I): y = AND of I packed words (minimal recursive binary tree)
//   or_2n  #(N,I): y = OR  of 2**I packed words (recursive binary tree)

// Wide N-sized buffer
module buf1 #(
    // data width of input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      buf (y[i], a[i]);
    end
  endgenerate
endmodule


// Wide N-sized NOT gate
module not1 #(
    // data width of input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      not (y[i], a[i]);
    end
  endgenerate
endmodule


// Wide N-sized AND gate
module and2 #(
    // data width of each input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      and (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized OR gate
module or2 #(
    // data width of each input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      or (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized XOR gate
module xor2 #(
    // data width of each input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      xor (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized NAND gate
module nand2 #(
    // data width of each input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      nand (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized NOR gate
module nor2 #(
    // data width of each input, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      nor (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// I-input, N-bit-wide AND
//   y = d[0] & d[1] & ... & d[I-1]      (bitwise across each word)
//
// The I input words are packed into d: word k = d[k*N +: N].
// and_n #(N, 2) is equivalent to and2 #(N).
module and_n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  // chain[k] = d[0] & ... & d[k-1]
  wire [(I+1)*N-1:0] chain;

  buf1 #(N) seed (
      .a({N{1'b1}}),
      .y(chain[N-1:0])
  );

  genvar k;
  generate
    for (k = 0; k < I; k = k + 1) begin : g_and
      and2 #(N) a (
          .a(chain[k*N+:N]),
          .b(d[k*N+:N]),
          .y(chain[(k+1)*N+:N])
      );
    end
  endgenerate

  buf1 #(N) out_buf (
      .a(chain[I*N+:N]),
      .y(y)
  );
endmodule


// I-input, N-bit-wide OR
//   y = d[0] | d[1] | ... | d[I-1]      (bitwise across word)
//
// The I input words are packed into d: word k = d[k*N +: N].
// or_n #(N, 2) is equivalent to or2 #(N).
module or_n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  // chain[k] = d[0] | ... | d[k-1]
  wire [(I+1)*N-1:0] chain;

  buf1 #(N) seed (
      .a({N{1'b0}}),
      .y(chain[N-1:0])
  );

  genvar k;
  generate
    for (k = 0; k < I; k = k + 1) begin : g_or
      or2 #(N) o (
          .a(chain[k*N+:N]),
          .b(d[k*N+:N]),
          .y(chain[(k+1)*N+:N])
      );
    end
  endgenerate

  buf1 #(N) out_buf (
      .a(chain[I*N+:N]),
      .y(y)
  );
endmodule


// I-input, N-bit-wide XOR
//   y = d[0] x d[1] x ... x d[I-1]      (bitwise across word)
//
// The I input words are packed into d: word k = d[k*N +: N].
// xor_n #(N, 2) is equivalent to xor2 #(N).
module xor_n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  // chain[k] = d[0] | ... | d[k-1]
  wire [(I+1)*N-1:0] chain;

  buf1 #(N) seed (
      .a({N{1'b0}}),
      .y(chain[N-1:0])
  );

  genvar k;
  generate
    for (k = 0; k < I; k = k + 1) begin : g_xor
      xor2 #(N) o (
          .a(chain[k*N+:N]),
          .b(d[k*N+:N]),
          .y(chain[(k+1)*N+:N])
      );
    end
  endgenerate

  buf1 #(N) out_buf (
      .a(chain[I*N+:N]),
      .y(y)
  );
endmodule


// I-input, N-bit-wide AND, minimal-depth recursive binary tree
//   y = d[0] & d[1] & ... & d[I-1]   (bitwise across each word)
//
// The I input words are packed into d: word k = d[k*N +: N].
// Tree depth is ceil(log2(I))
//
// NOTE: relies on recursive module instantiation
module and_2n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  generate
    if (I == 1) begin : g_base1
      buf1 #(N) g_buf (
          .a(d),
          .y(y)
      );
    end else if (I == 2) begin : g_base2
      and2 #(N) g_and (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      and_2n #(
          .N(N),
          .I(L)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      and_2n #(
          .N(N),
          .I(I - L)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      and2 #(
          .N(N)
      ) g_and (
          .a(lo),
          .b(hi),
          .y(y)
      );
    end
  endgenerate
endmodule


// 2**I-input, N-bit-wide OR, recursive binary tree
//   y = d[0] | d[1] | ... | d[(2**I)-1]   (bitwise across each word)
//
// The 2**I input words are packed into d: word k = d[k*N +: N].
// Tree depth is ceil(log2(I))
//
// NOTE: relies on recursive module instantiation
module or_2n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  generate
    if (I == 1) begin : g_base1
      buf1 #(N) g_buf (
          .a(d),
          .y(y)
      );
    end else if (I == 2) begin : g_base2
      or2 #(N) g_or (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      or_2n #(
          .N(N),
          .I(L)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      or_2n #(
          .N(N),
          .I(I - L)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      or2 #(
          .N(N)
      ) g_or (
          .a(lo),
          .b(hi),
          .y(y)
      );
    end
  endgenerate
endmodule


// 2**I-input, N-bit-wide XOR, recursive binary tree
//   y = d[0] x d[1] x ... x d[(2**I)-1]   (bitwise across each word)
//
// The 2**I input words are packed into d: word k = d[k*N +: N].
// Tree depth is ceil(log2(I))
//
// NOTE: relies on recursive module instantiation
module xor_2n #(
    // bits per input word
    parameter int N = 1,
    // number of input words
    parameter int I = 2
) (
    // packed inputs: word k = d[k*N +: N]
    input  wire [I*N-1:0] d,
    output wire [  N-1:0] y
);
  generate
    if (I == 1) begin : g_base1
      buf1 #(N) g_buf (
          .a(d),
          .y(y)
      );
    end else if (I == 2) begin : g_base2
      xor2 #(N) g_xor (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      xor_2n #(
          .N(N),
          .I(L)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      xor_2n #(
          .N(N),
          .I(I - L)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      xor2 #(
          .N(N)
      ) g_xor (
          .a(lo),
          .b(hi),
          .y(y)
      );
    end
  endgenerate
endmodule

module gates ();
endmodule
