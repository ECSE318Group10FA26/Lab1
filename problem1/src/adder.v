// Bit-serial adder
//
// A single full adder computes the SUM one bit at a time, least significant
// bit first. At time t the CARRY is stored in a 1-bit register; at time t+1
// the adder uses CARRY[t] to form the next SUM bit. An n-bit add takes
// n clock cycles.
//
//   - addend / augend : n-bit piso registers (LSB first)
//   - result          : n-bit sipo (SUM bit enters at the MSB)
//   - carry register  : 1-bit register; initialized with cin when the
//                       operands load then stores the CARRY between bit cycles
//
//   serial_adder_structural : structural model, depends: common/lib
//                             (mux, dff_sc, full_adder, piso_reg, sipo_reg)
//   serial_adder_behavioral : behavioral model


// Serial Adder - structural implementation
module serial_adder_structural #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,  // clears the carry register (starts an add)
    input  wire         load,   // parallel-loads the operand registers
    input  wire         cin,    // initial carry, captured while operands load
    input  wire [N-1:0] addend,
    input  wire [N-1:0] augend,
    output wire [N-1:0] result,
    output wire         cout    // final carry = (N+1)-th bit of the sum
);
    wire [N-1:0] a_q;       // addend register contents (a_q[0] = serial out)
    wire [N-1:0] b_q;       // augend register contents
    wire         sum_bit;   // SUM output of the full adder
    wire         carry_d;   // COUT of the full adder
    wire         carry_q;   // carry register output   -> full adder CIN
    wire         carry_next;// carry register D input (load ? cin : carry_d)

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

    // carry register (1-bit, CLEAR). While the operands load it captures
    // cin (the role of the SET/CLEAR pins in Fig 4(a)); during the n shift
    // cycles it stores the CARRY from one bit position to the next.
    mux #(.N(1), .S(1)) carry_sel (
        .d   ({cin, carry_d}),   // input 0 = carry from adder, input 1 = cin
        .sel (load),
        .y   (carry_next)
    );

    dff_sc carry_reg (
        .clk   (clk),
        .clear (clear),
        .d     (carry_next),
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


// Serial Adder - behavioral implementation
module serial_adder_behavioral #(
    parameter N = 4
) (
    input  wire         clk,
    input  wire         clear,
    input  wire         load,
    input  wire         cin,
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
            {cout, result} <= addend + augend + {{(N-1){1'b0}}, cin};
        end
        // otherwise hold: the result stays valid while the structural
        // model finishes its n shift/add cycles
    end
endmodule
