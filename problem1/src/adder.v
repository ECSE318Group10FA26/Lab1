// ==========================================================================
// adder.v
//
// Bit-serial adder (HW1, Problem 1, Fig 4(a))
//
// A single full adder computes the SUM one bit at a time, least significant
// bit first. At time t the CARRY is stored in a 1-bit register; at time t+1
// the adder uses CARRY[t] to form the next SUM bit. An n-bit add takes
// n clock cycles.
//
//   - addend / augend : n-bit parallel-in/shift-out registers (LSB first)
//   - result          : n-bit shift register (SUM bit enters at the MSB)
//   - carry register  : 1-bit register with CLEAR (SET is tied off; the
//                       handout protocol only ever clears the carry)
//
// Operation (driven by the testbench / control):
//   1. clear = 1 : carry register is cleared -> addition is commenced
//   2. load  = 1 : operands are parallel-loaded (carry is held at 0)
//   3. load  = 0 : n shift/add cycles; afterwards {cout, result} = a + b
//
// Two models of the same design are provided:
//   serial_adder_structural : part (a) - gates + flip-flops + wiring
//   serial_adder_behavioral : part (b) - behavioral (always-block) model
// ==========================================================================


// --------------------------------------------------------------------------
// full_adder : one-bit full adder built from gate primitives
//   sum  = a ^ b ^ cin
//   cout = (a & b) | (cin & (a ^ b))      (equal SUM and CARRY path lengths)
// --------------------------------------------------------------------------
module full_adder (
    input  wire a,
    input  wire b,
    input  wire cin,
    output wire sum,
    output wire cout
);
    wire axb;       // a ^ b
    wire c1;        // a & b
    wire c2;        // cin & (a ^ b)

    xor (axb, a, b);
    xor (sum, axb, cin);
    and (c1, a, b);
    and (c2, axb, cin);
    or  (cout, c1, c2);
endmodule


// --------------------------------------------------------------------------
// dff_sc : D flip-flop with synchronous clear (leaf register cell).
// The carry register of Fig 4(a) is one of these. (A flip-flop cannot be
// described purely by wiring, so this leaf cell uses an always block;
// everything above it in the structural model is pure structure.)
// --------------------------------------------------------------------------
module dff_sc (
    input  wire clk,
    input  wire clear,      // synchronous clear
    input  wire d,
    output reg  q
);
    always @(posedge clk) begin
        if (clear)
            q <= 1'b0;
        else
            q <= d;
    end
endmodule


// --------------------------------------------------------------------------
// mux2 : 2-to-1 multiplexer built from gate primitives
//   y = (s == 0) ? a : b
// --------------------------------------------------------------------------
module mux2 (
    input  wire a,
    input  wire b,
    input  wire s,
    output wire y
);
    wire ns, y0, y1;

    not (ns, s);
    and (y0, a, ns);
    and (y1, b, s);
    or  (y, y0, y1);
endmodule


// --------------------------------------------------------------------------
// piso_reg : n-bit operand register (addend / augend)
//   load = 1 : parallel load d_in
//   load = 0 : shift one position toward the LSB (a 0 enters the MSB),
//              so q[0] presents the operand serially, LSB first
// --------------------------------------------------------------------------
module piso_reg #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire [N-1:0] d_in,
    output wire [N-1:0] q
);
    wire [N-1:0] d;     // next state of each flip-flop

    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : bit
            if (i == N-1) begin : msb
                mux2 m (.a(1'b0),   .b(d_in[i]), .s(load), .y(d[i]));
            end else begin : sh
                mux2 m (.a(q[i+1]), .b(d_in[i]), .s(load), .y(d[i]));
            end
            dff_sc ff (.clk(clk), .clear(clear), .d(d[i]), .q(q[i]));
        end
    endgenerate
endmodule


// --------------------------------------------------------------------------
// sipo_reg : n-bit result register
//   serial input sin enters at the MSB and the word shifts toward the LSB
//   every clock; after n cycles the register holds the n SUM bits in order
// --------------------------------------------------------------------------
module sipo_reg #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         sin,
    output wire [N-1:0] q
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : bit
            if (i == N-1) begin : msb
                dff_sc ff (.clk(clk), .clear(clear), .d(sin),    .q(q[i]));
            end else begin : sh
                dff_sc ff (.clk(clk), .clear(clear), .d(q[i+1]), .q(q[i]));
            end
        end
    endgenerate
endmodule


// ==========================================================================
// Part (a): STRUCTURAL model of the bit-serial adder (Fig 4(a))
// ==========================================================================
module serial_adder_structural #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,  // clears the carry register (starts an add)
    input  wire         load,   // parallel-loads the operand registers
    input  wire [N-1:0] addend,
    input  wire [N-1:0] augend,
    output wire [N-1:0] result,
    output wire         cout    // final carry = (N+1)-th bit of the sum
);
    wire [N-1:0] a_q;       // addend register contents (a_q[0] = serial out)
    wire [N-1:0] b_q;       // augend register contents
    wire         sum_bit;   // SUM output of the full adder
    wire         carry_d;   // COUT of the full adder  -> carry register D
    wire         carry_q;   // carry register output   -> full adder CIN

    // operand registers (shift toward the LSB while adding)
    piso_reg #(.N(N)) reg_addend (
        .clk   (clk),
        .clear (clear),
        .load  (load),
        .d_in  (addend),
        .q     (a_q)
    );

    piso_reg #(.N(N)) reg_augend (
        .clk   (clk),
        .clear (clear),
        .load  (load),
        .d_in  (augend),
        .q     (b_q)
    );

    // the single adder shared by all bit positions
    full_adder fa (
        .a    (a_q[0]),
        .b    (b_q[0]),
        .cin  (carry_q),
        .sum  (sum_bit),
        .cout (carry_d)
    );

    // carry register (1-bit, CLEAR). Held clear while new operands load so
    // every addition starts with CIN = 0, per the handout protocol.
    dff_sc carry_reg (
        .clk   (clk),
        .clear (clear | load),
        .d     (carry_d),
        .q     (carry_q)
    );

    // result register (SUM bit enters at the MSB)
    sipo_reg #(.N(N)) reg_result (
        .clk   (clk),
        .clear (clear),
        .sin   (sum_bit),
        .q     (result)
    );

    assign cout = carry_q;
endmodule


// ==========================================================================
// Part (b): BEHAVIORAL model of the same design
//
// Describes only the observable function: when the operands are loaded the
// whole N-bit sum is computed in one cycle ({cout,result} = addend+augend)
// and held until the next clear/load. No gates, no per-bit sequencing -
// the bit-serial datapath is an implementation detail this model hides.
// ==========================================================================
module serial_adder_behavioral #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire [N-1:0] addend,
    input  wire [N-1:0] augend,
    output reg  [N-1:0] result,
    output reg          cout
);
    always @(posedge clk) begin
        if (clear) begin
            result <= {N{1'b0}};
            cout   <= 1'b0;
        end else if (load) begin
            {cout, result} <= addend + augend;
        end
        // otherwise hold: the result stays valid while the structural
        // model finishes its n shift/add cycles
    end
endmodule
