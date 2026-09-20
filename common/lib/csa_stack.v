// csa_stack - staged carry-save reduction tree
//
// Reduces M words of N bits (all weight 1) down to exactly 2 absolute-value
// container words of W = N + clog2(M) bits, ready for a final carry-propagate
// adder.
//
// Algorithm per stage (csa_stage):
//   1. Every weight class k with >= 3 words fires one csa_layer #(N, cnt):
//      sums stay in class k, carries become class k+1 words next stage.
//   2. The lowest nonempty class, if it holds <= 2 words, is *promoted*: its
//      words become passthrough remainders
//   3. The remainder pool (old remainders ++ newly promoted words) fires one
//      csa_layer sized to its widest container whenever it holds >= 3 words.
// Terminal level: no active words and <= 2 remainder words -> drives out.
//
// M is unbounded: L and FW scale with clog2(M).

module csa_stage #(
    parameter int N = 4,  // active word width in bits
    parameter int W = 6,  // container width in bits
    parameter int L = 3,  // number of weight classes
    parameter int FW = 2,  // bits per packed class-count field
    // packed active class counts: class k holds CNTS[FW*(k-1) +: FW] words
    parameter bit [L*FW-1:0] CNTS = '0,
    parameter int RCNT = 0,  // remainder pool size
    parameter int WMAX = 0,  // widest remainder container in bits
    // total active words (must equal the sum of CNTS fields; supplied by the
    // parent since module-body functions are not visible in the header)
    parameter int TOT = 0,
    // gate delay, in `timescale units
    parameter int D = 0,
    // derived - do not override. Zero-width ports are illegal, so the bus
    // word counts clamp to 1 (the dummy word is never read).
    parameter int NA = (TOT > 0) ? TOT : 1,
    parameter int NR = (RCNT > 0) ? RCNT : 1
) (
    input  wire [NA*N-1:0] in_active,  // active words, classes 1..L in order
    input  wire [NR*W-1:0] in_rem,     // remainder pool (absolute containers)
    output wire [2*W-1:0] out
);

  // small constant helpers (elaboration-time count arithmetic over the
  // packed fields; the only iteration Verilog allows at elaboration)

  // class k's word count (0 when out of range)
  function automatic int field_at(input bit [L*FW-1:0] c, input int k);
    if (k < 1 || k > L) return 0;
    return int'(c[FW*(k-1)+:FW]);
  endfunction

  // lowest nonempty class (0 if none)
  function automatic int lowest(input bit [L*FW-1:0] c);
    for (int k = 1; k <= L; k++) begin
      if (field_at(c, k) > 0) return k;
    end
    return 0;
  endfunction

  // word offset of class k in the active region = words in classes 1..k-1
  // (off_at(c, L+1) = total active words)
  function automatic int off_at(input bit [L*FW-1:0] c, input int k);
    int t;
    t = 0;
    for (int j = 1; j < k; j++) t += field_at(c, j);
    return t;
  endfunction

  // one stage transition on the packed counts: fire classes with >= 3 words
  // (sums stay, carries move up a class), promote the lowest class at <= 2
  function automatic bit [L*FW-1:0] next_cnts(input bit [L*FW-1:0] c);
    int lo, a, own_v, arr_v;
    bit pr;
    lo = lowest(c);
    pr = (lo > 0) && (field_at(c, lo) <= 2);
    next_cnts = '0;
    for (int k = 1; k <= L; k++) begin
      a = field_at(c, k);
      own_v = (pr && (k == lo)) ? 0 : (a >= 3) ? (a / 3 + a % 3) : a;
      arr_v = (field_at(c, k - 1) >= 3) ? (field_at(c, k - 1) / 3) : 0;
      next_cnts[FW*(k-1)+:FW] = FW'(unsigned'(own_v + arr_v));
    end
  endfunction

  // this level's layout and its child's state, as locals

  localparam int LO = lowest(CNTS);  // lowest nonempty class (0 if none)
  localparam int ALO = field_at(CNTS, LO);  // its word count
  // promote the lowest class once it holds <= 2 words (bottom-up wave)
  localparam bit PROM = (LO > 0) && (ALO <= 2);

  // child's packed counts
  localparam bit [L*FW-1:0] NCNTS = next_cnts(CNTS);
  localparam int TOTN = off_at(NCNTS, L + 1);

  // remainder pool: promoted words join immediately (promotion is
  // zero-delay), then one csa_layer if the pool holds >= 3 words
  localparam int RBEFORE = RCNT + (PROM ? ALO : 0);
  localparam bit RFIRE = RBEFORE >= 3;
  localparam int WMAXIN = (PROM && (N + LO - 1 > WMAX)) ? (N + LO - 1) : WMAX;
  localparam int RCNTN = RFIRE ? (2 * (RBEFORE / 3) + RBEFORE % 3) : RBEFORE;
  localparam int WMAXN = RFIRE ? ((WMAXIN + 1 < W) ? WMAXIN + 1 : W) : WMAXIN;

  // terminal: no active words and <= 2 remainder words
  localparam bit TERMINAL = (TOT == 0) && (RCNT <= 2);

  genvar gk, gj;
  generate
    if (TERMINAL) begin : g_final
      // in_rem holds exactly the final 1..2 remainder words
      buf1 #(
          .N(W)
      ) gen_w0 (
          .a(in_rem[0+:W]),
          .y(out[0+:W])
      );
      if (RCNT == 2) begin : g_second
        buf1 #(
            .N(W)
        ) gen_w1 (
            .a(in_rem[W+:W]),
            .y(out[W+:W])
        );
      end else begin : g_zero
        buf1 #(
            .N(W)
        ) gen_z (
            .a({W{1'b0}}),
            .y(out[W+:W])
        );
      end
    end else begin : g_step
      // next stage's buses (exactly sized: word count never increases)
      localparam int NAN = (TOTN > 0) ? TOTN : 1;    // min 1: zero-width illegal
      localparam int NRN = (RCNTN > 0) ? RCNTN : 1;
      wire [NAN*N-1:0] next_active;
      wire [NRN*W-1:0] next_rem;

      // ---------------- active classes ----------------
      for (gk = 1; gk <= L; gk++) begin : g_class
        localparam int A = field_at(CNTS, gk);  // words of class gk
        localparam int Off = off_at(CNTS, gk);  // word offset of class gk
        localparam int Noff = off_at(NCNTS, gk);  // word offset next stage

        if (A >= 3) begin : g_fire
          localparam int Q = A / 3;
          localparam int P = A % 3;
          // class gk+1's own words next stage (its arrivals follow them)
          localparam int An = field_at(CNTS, gk + 1);
          localparam int OwnN = (PROM && (LO == gk + 1)) ? 0 : (An >= 3) ? (An / 3 + An % 3) : An;
          // arrival region of class gk+1 next stage (word offset)
          localparam int ArrOff = off_at(NCNTS, gk + 1) + OwnN;

          // class words are contiguous: ports connect to whole slices.
          // sums/leftovers stay in class gk; carries land in class gk+1.
          csa_layer #(
              .N(N),
              .M(A),
              .D(D)
          ) layer (
              .in_vecs(in_active[Off*N+:A*N]),
              .out_vecs(next_active[Noff*N+:(Q+P)*N]),
              .carry_outs(next_active[ArrOff*N+:Q*N])
          );
        end else if (PROM && (gk == LO)) begin : g_promote
          // promotion is the only place a shift materializes
          if (!RFIRE) begin : g_copy
            for (gj = 0; gj < A; gj++) begin : g_w
              shift_ext #(
                  .N(N),
                  .S(LO - 1),
                  .W(W)
              ) gen_w (
                  .w(in_active[(Off+gj)*N+:N]),
                  .y(next_rem[(RCNT+gj)*W+:W])
              );
            end
          end
        end else if (A > 0) begin : g_pass
          // 1..2 words in a non-lowest class: pass through unchanged
          buf1 #(
              .N(A * N)
          ) gen_w (
              .a(in_active[Off*N+:A*N]),
              .y(next_active[Noff*N+:A*N])
          );
        end
      end

      // ---------------- remainder pool ----------------
      if (RFIRE) begin : g_remainder
        localparam int Q2 = RBEFORE / 3;
        localparam int P2 = RBEFORE % 3;
        localparam int PromOff = off_at(CNTS, LO);  // promoted words offset

        wire [WMAXIN*RBEFORE-1:0] rem_in;
        wire [WMAXIN*(Q2+P2)-1:0] rem_out;
        wire [WMAXIN*Q2-1:0] rem_c;

        // pool = old remainders (self-zero-extend) ++ promoted words
        for (gj = 0; gj < RCNT; gj++) begin : g_in_old
          buf1 #(
              .N(WMAXIN)
          ) gen_w (
              .a(in_rem[gj*W+:WMAXIN]),
              .y(rem_in[gj*WMAXIN+:WMAXIN])
          );
        end
        if (PROM) begin : g_in_new
          for (gj = 0; gj < ALO; gj++) begin : g_w
            shift_ext #(
                .N(N),
                .S(LO - 1),
                .W(WMAXIN)
            ) gen_w (
                .w(in_active[(PromOff+gj)*N+:N]),
                .y(rem_in[(RCNT+gj)*WMAXIN+:WMAXIN])
            );
          end
        end

        csa_layer #(
            .N(WMAXIN),
            .M(RBEFORE),
            .D(D)
        ) layer (
            .in_vecs(rem_in),
            .out_vecs(rem_out),
            .carry_outs(rem_c)
        );

        // sums/leftovers: width-WMAXIN containers zero-extended to W
        for (gj = 0; gj < Q2 + P2; gj++) begin : g_sum
          shift_ext #(
              .N(WMAXIN),
              .S(0),
              .W(W)
          ) gen_w (
              .w(rem_out[gj*WMAXIN+:WMAXIN]),
              .y(next_rem[gj*W+:W])
          );
        end

        // carries: containers shifted left by 1 (value 2*c)
        for (gj = 0; gj < Q2; gj++) begin : g_car
          shift_ext #(
              .N(WMAXIN),
              .S(1),
              .W(W)
          ) gen_w (
              .w(rem_c[gj*WMAXIN+:WMAXIN]),
              .y(next_rem[(Q2+P2+gj)*W+:W])
          );
        end
      end else begin : g_rem_pass
        // no firing: remainder words pass through unchanged
        if (RCNT > 0) begin : g_copy
          buf1 #(
              .N(RCNT * W)
          ) gen_w (
              .a(in_rem[0+:RCNT*W]),
              .y(next_rem[0+:RCNT*W])
          );
        end
      end

      // ---- keep the dummy regions driven when a bus is empty next stage ----
      if (TOTN == 0) begin : g_active_zero
        buf1 #(
            .N(N)
        ) gen_z (
            .a({N{1'b0}}),
            .y(next_active[0+:N])
        );
      end
      if (RCNTN == 0) begin : g_rem_zero
        buf1 #(
            .N(W)
        ) gen_z (
            .a({W{1'b0}}),
            .y(next_rem[0+:W])
        );
      end

      // ---------------- recurse ----------------
      csa_stage #(
          .N(N),
          .W(W),
          .L(L),
          .FW(FW),
          .CNTS(NCNTS),
          .RCNT(RCNTN),
          .WMAX(WMAXN),
          .TOT(TOTN),
          .D(D)
      ) child (
          .in_active(next_active),
          .in_rem(next_rem),
          .out(out)
      );
    end
  endgenerate
endmodule


// csa_stack - top level: the M input words are already the stage-0 active
// region (all weight 1, N bits each, class 1), so no packing is needed.
module csa_stack #(
    parameter int N  = 4,
    parameter int M  = 3,
    // gate delay, in `timescale units
    parameter int D  = 0,
    // derived - do not override
    parameter int W  = N + $clog2(M),
    parameter int L  = $clog2(M) + 2,  // top two classes never fire
    parameter int FW = $clog2(M + 1)   // fields must hold counts up to M
) (
    // packed inputs: word k = in_vecs[k*N +: N] (all weight 1)
    input  wire [N*M-1:0] in_vecs,
    // final reduced words: out_vecs[0 +: W] and out_vecs[W +: W]; their sum
    // equals the sum of the input words. The second word is 0 if the pool
    // reduced to a single word (M = 1).
    output wire [2*W-1:0] out_vecs
);
  // class 1 = M words, rest empty
  localparam bit [L*FW-1:0] CNTS0 = {{(L * FW - FW) {1'b0}}, M[FW-1:0]};

  csa_stage #(
      .N(N),
      .W(W),
      .L(L),
      .FW(FW),
      .CNTS(CNTS0),
      .RCNT(0),
      .WMAX(0),
      .TOT(M),
      .D(D)
  ) root (
      .in_active(in_vecs),
      .in_rem({W{1'b0}}),  // empty pool (dummy word; never read)
      .out(out_vecs)
  );
endmodule
