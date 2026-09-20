// wide (N-bit) gate library cells
//
//   buf1 #(N)    : y = a
//   not1 #(N)    : y = ~a
//   shift_ext    : y = W'(w) << S  (place word at bit offset S, zero-filled)
//   and2 #(N)    : y = a & b
//   or2  #(N)    : y = a | b
//   and_n #(N,I) : y = AND of the I packed input words (word k = d[k*N +: N])
//   or_n  #(N,I) : y = OR  of the I packed input words
//   and_2n #(N,I): y = AND of I packed words (minimal recursive binary tree)
//   or_2n  #(N,I): y = OR  of 2**I packed words (recursive binary tree)
//
// Every logic cell takes an optional delay parameter D
// applied to its gate primitives and children
// buf1 and shift_ext are 0 delay

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


// Shift-and-extend wiring cell: y = W'(w) << S
//
// Places an N-bit word at bit offset S of a W-bit container
// all other bits are 0'd
module shift_ext #(
    // data width of the input word, in bits
    parameter int N = 1,
    // left shift (bit offset of the word inside the container)
    parameter int S = 0,
    // container width in bits
    parameter int W = N + S
) (
    input  wire [N-1:0] w,
    output wire [W-1:0] y
);
  // content bits that fit in the container
  localparam int NB = (N + S > W) ? W - S : N;

  if (S > 0) begin : g_lo
    buf1 #(
        .N(S)
    ) gen_z (
        .a({S{1'b0}}),
        .y(y[0+:S])
    );
  end

  buf1 #(
      .N(NB)
  ) gen_w (
      .a(w[0+:NB]),
      .y(y[S+:NB])
  );

  if (W > S + NB) begin : g_hi
    buf1 #(
        .N(W - S - NB)
    ) gen_z (
        .a({(W - S - NB) {1'b0}}),
        .y(y[S+NB+:(W-S-NB)])
    );
  end
endmodule


// Wide N-sized NOT gate
module not1 #(
    // data width of input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      not #(D) (y[i], a[i]);
    end
  endgenerate
endmodule


// Wide N-sized AND gate
module and2 #(
    // data width of each input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      and #(D) (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized OR gate
module or2 #(
    // data width of each input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      or #(D) (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized XOR gate
module xor2 #(
    // data width of each input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      xor #(D) (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized NAND gate
module nand2 #(
    // data width of each input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      nand #(D) (y[i], a[i], b[i]);
    end
  endgenerate
endmodule


// Wide N-sized NOR gate
module nor2 #(
    // data width of each input, in bits
    parameter int N = 1,
    // gate delay, in `timescale units
    parameter int D = 0
) (
    input  wire [N-1:0] a,
    input  wire [N-1:0] b,
    output wire [N-1:0] y
);
  genvar i;
  generate
    for (i = 0; i < N; i = i + 1) begin : g_bit
      nor #(D) (y[i], a[i], b[i]);
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      and2 #(N, D) a (
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      or2 #(N, D) o (
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      xor2 #(N, D) o (
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      and2 #(N, D) g_and (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      and_2n #(
          .N(N),
          .I(L),
          .D(D)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      and_2n #(
          .N(N),
          .I(I - L),
          .D(D)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      and2 #(
          .N(N),
          .D(D)
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      or2 #(N, D) g_or (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      or_2n #(
          .N(N),
          .I(L),
          .D(D)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      or_2n #(
          .N(N),
          .I(I - L),
          .D(D)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      or2 #(
          .N(N),
          .D(D)
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
    parameter int I = 2,
    // gate delay, in `timescale units
    parameter int D = 0
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
      xor2 #(N, D) g_xor (
          .a(d[N-1:0]),
          .b(d[2*N-1:N]),
          .y(y)
      );
    end else begin : g_rec
      localparam int L = 1 << $clog2(I) - 1;
      wire [N-1:0] lo, hi;
      xor_2n #(
          .N(N),
          .I(L),
          .D(D)
      ) m_lo (
          .d(d[0+:L*N]),
          .y(lo)
      );
      xor_2n #(
          .N(N),
          .I(I - L),
          .D(D)
      ) m_hi (
          .d(d[L*N+:(I-L)*N]),
          .y(hi)
      );
      xor2 #(
          .N(N),
          .D(D)
      ) g_xor (
          .a(lo),
          .b(hi),
          .y(y)
      );
    end
  endgenerate
endmodule

module gates;
endmodule
