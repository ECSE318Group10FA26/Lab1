// Testbench for the structural comparison unit (comp_unit)
//
// comp_unit has no adder of its own: it shares the arithmetic core's
// subtractor. Each DUT is therefore an arith_unit driven as a subtractor
// (op = SUB, so o = a - b, v = signed overflow, cout = NOT borrow) feeding
// a comp_unit -- the same wiring the top-level ALU uses for compare ops.
//
// Checks all 16 op encodings -- the six signed predicates (SLT/SEQ/SLE/
// SGT/SNE/SGE), FALSE/TRUE, and the unsigned variants selected by op[3] --
// against an independent integer-math reference. Each DUT sweep is a task
// driving its DUT and calling the shared check task (settle, reference,
// compare, report). Widths: N=8 exhaustive over a x b x op, N=6
// (non-power-of-2 reduction tree), N=1 (minimal).

`timescale 1ns / 1ps

module comp_unit_tb;

    localparam int D = 0;  // gate delay, in `timescale units

    integer errors;
    integer tests;
    integer ia, ib, io;

    // independent reference: integer math, width-parameterized;
    // returns the predicate bit, zero-extended to 8 bits
    function automatic [7:0] cmp_ref;
        input integer n;
        input integer a_i;
        input integer b_i;
        input integer op_i;
        integer ta;  // true signed value of a
        integer tb;  // true signed value of b
        reg lt, eq, gt;
        begin
            ta = (a_i >= (1 << (n - 1))) ? a_i - (1 << n) : a_i;
            tb = (b_i >= (1 << (n - 1))) ? b_i - (1 << n) : b_i;
            if (op_i[3]) lt = (a_i < b_i);  // unsigned
            else lt = (ta < tb);  // signed
            eq = (a_i == b_i);
            gt = !(lt || eq);
            cmp_ref = {7'b0000000, (op_i[0] & lt) | (op_i[1] & eq) | (op_i[2] & gt)};
        end
    endfunction

    // reference, compare, report for one vector on one DUT (call after
    // the DUT inputs have settled; task inputs sample at call time)
    task automatic check(input integer n, input integer a_i, input integer b_i, input integer op_i,
                         input integer o_i);
        reg [7:0] e;
        begin
            e     = cmp_ref(n, a_i, b_i, op_i);
            tests = tests + 1;
            if (o_i[7:0] !== e) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display(
                        "FAIL (N=%0d): op=%0d a=%0d b=%0d",
                        n,
                        op_i,
                        a_i,
                        b_i,
                        "  o=%0d (exp %0d)",
                        o_i,
                        e
                    );
            end
        end
    endtask

    // N=8 DUT pair (shared subtractor + flag logic)
    reg  [7:0] a8;
    reg  [7:0] b8;
    reg  [3:0] op8;
    wire [7:0] o8;

    wire [7:0] diff8;
    wire       cout8;
    wire       ovf8;

    arith_unit #(
        .N(8),
        .D(D)
    ) arith8 (
        .a   (a8),
        .b   (b8),
        .cin (1'b0),
        .op  (3'd2),  // SUB: cin is ignored (carry-in forced by sub)
        .o   (diff8),
        .cout(cout8),
        .v   (ovf8)
    );

    comp_unit #(
        .N(8),
        .D(D)
    ) dut8 (
        .diff(diff8),
        .cout(cout8),
        .ovf (ovf8),
        .op  (op8),
        .o   (o8)
    );

    task automatic test_dut8;
        begin
            for (ia = 0; ia < 256; ia = ia + 1) begin
                for (ib = 0; ib < 256; ib = ib + 1) begin
                    for (io = 0; io < 16; io = io + 1) begin
                        a8  = ia[7:0];
                        b8  = ib[7:0];
                        op8 = io[3:0];
                        #1;  // settle
                        check(8, ia, ib, io, int'(o8));
                    end
                end
            end
        end
    endtask

    // N=6 DUT pair: non-power-of-2 reduction tree
    reg  [5:0] a6;
    reg  [5:0] b6;
    reg  [3:0] op6;
    wire [5:0] o6;

    wire [5:0] diff6;
    wire       cout6;
    wire       ovf6;

    arith_unit #(
        .N(6),
        .D(D)
    ) arith6 (
        .a   (a6),
        .b   (b6),
        .cin (1'b0),
        .op  (3'd2),
        .o   (diff6),
        .cout(cout6),
        .v   (ovf6)
    );

    comp_unit #(
        .N(6),
        .D(D)
    ) dut6 (
        .diff(diff6),
        .cout(cout6),
        .ovf (ovf6),
        .op  (op6),
        .o   (o6)
    );

    task automatic test_dut6;
        begin
            for (ia = 0; ia < 64; ia = ia + 1) begin
                for (ib = 0; ib < 64; ib = ib + 1) begin
                    for (io = 0; io < 16; io = io + 1) begin
                        a6  = ia[5:0];
                        b6  = ib[5:0];
                        op6 = io[3:0];
                        #1;  // settle
                        check(6, ia, ib, io, int'(o6));
                    end
                end
            end
        end
    endtask

    // N=1 DUT pair: minimal width
    reg        a1;
    reg        b1;
    reg  [3:0] op1;
    wire       o1;

    wire       diff1;
    wire       cout1;
    wire       ovf1;

    arith_unit #(
        .N(1),
        .D(D)
    ) arith1 (
        .a   (a1),
        .b   (b1),
        .cin (1'b0),
        .op  (3'd2),
        .o   (diff1),
        .cout(cout1),
        .v   (ovf1)
    );

    comp_unit #(
        .N(1),
        .D(D)
    ) dut1 (
        .diff(diff1),
        .cout(cout1),
        .ovf (ovf1),
        .op  (op1),
        .o   (o1)
    );

    task automatic test_dut1;
        begin
            for (ia = 0; ia < 2; ia = ia + 1) begin
                for (ib = 0; ib < 2; ib = ib + 1) begin
                    for (io = 0; io < 16; io = io + 1) begin
                        a1  = ia[0];
                        b1  = ib[0];
                        op1 = io[3:0];
                        #1;  // settle
                        check(1, ia, ib, io, int'(o1));
                    end
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        tests  = 0;

        test_dut8();
        test_dut6();
        test_dut1();

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
