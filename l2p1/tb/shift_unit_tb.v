// Testbench for the structural barrel shifter (shift_unit)
//
// Checks all 8 op encodings against an independent reference computed with
// integer math. Each DUT sweep is a task driving its DUT and calling the
// shared check task (settle, reference, compare, report). Three widths are
// exercised: N=8 exhaustively over a x shamt x op, N=6 (non-power-of-2:
// odd stage sizes and shamt >= N), and N=1 (the zero-stage generate path).

`timescale 1ns / 1ps

module shift_unit_tb;

    localparam int D = 0;  // gate delay, in `timescale units

    integer errors;
    integer tests;
    integer ia, is, io;

    // independent reference: integer math, parameterized by width
    // (result in the low n bits)
    function automatic [7:0] ref_shift;
        input integer n;
        input integer a_i;
        input integer sh_i;
        input integer op_i;
        integer ta;  // true signed value of a
        integer sm;  // shift amount modulo n (for rotates)
        begin
            sm = (n > 1) ? (sh_i % n) : 0;
            case (op_i)
                0: ref_shift = a_i[7:0] >> sh_i;  // SRL
                1: begin  // SRA
                    ta = (a_i >= (1 << (n - 1))) ? a_i - (1 << n) : a_i;
                    ref_shift = 8'($unsigned(ta >>> sh_i));
                end
                2, 3: ref_shift = (a_i[7:0] >> sm) | (a_i[7:0] << (n - sm));  // ROR (+alias)
                4, 5: ref_shift = a_i[7:0] << sh_i;  // SLL (+SLA alias)
                default: ref_shift = (a_i[7:0] << sm) | (a_i[7:0] >> (n - sm));  // ROL (+alias)
            endcase
            ref_shift = ref_shift & ((1 << n) - 1);
        end
    endfunction

    // reference, compare, report for one vector on one DUT (call after
    // the DUT inputs have settled; task inputs sample at call time)
    task automatic check(input integer n, input integer a_i, input integer sh_i, input integer op_i,
                         input integer o_i);
        reg [7:0] e;
        begin
            e     = ref_shift(n, a_i, sh_i, op_i);
            tests = tests + 1;
            if (o_i[7:0] !== e) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display(
                        "FAIL (N=%0d): op=%0d a=%0d shamt=%0d",
                        n,
                        op_i,
                        a_i,
                        sh_i,
                        "  o=%0d (exp %0d)",
                        o_i,
                        e
                    );
            end
        end
    endtask

    // N=8 DUT
    reg  [7:0] a8;
    reg  [2:0] s8;
    reg  [2:0] op8;
    wire [7:0] o8;

    shift_unit #(
        .N(8),
        .D(D)
    ) dut8 (
        .a    (a8),
        .shamt(s8),
        .op   (op8),
        .o    (o8)
    );

    // N=8: exhaustive over a x shamt x op
    task automatic test_dut8;
        begin
            for (ia = 0; ia < 256; ia = ia + 1) begin
                for (is = 0; is < 8; is = is + 1) begin
                    for (io = 0; io < 8; io = io + 1) begin
                        a8  = ia[7:0];
                        s8  = is[2:0];
                        op8 = io[2:0];
                        #1;  // settle
                        check(8, ia, is, io, int'(o8));
                    end
                end
            end
        end
    endtask

    // N=6 DUT: non-power-of-2 width
    reg  [5:0] a6;
    reg  [2:0] s6;
    reg  [2:0] op6;
    wire [5:0] o6;

    shift_unit #(
        .N(6),
        .D(D)
    ) dut6 (
        .a    (a6),
        .shamt(s6),
        .op   (op6),
        .o    (o6)
    );

    task automatic test_dut6;
        begin
            for (ia = 0; ia < 64; ia = ia + 1) begin
                for (is = 0; is < 8; is = is + 1) begin
                    for (io = 0; io < 8; io = io + 1) begin
                        a6  = ia[5:0];
                        s6  = is[2:0];
                        op6 = io[2:0];
                        #1;  // settle
                        check(6, ia, is, io, int'(o6));
                    end
                end
            end
        end
    endtask

    // N=1 DUT: zero barrel stages
    reg        a1;
    reg        s1;
    reg  [2:0] op1;
    wire       o1;

    shift_unit #(
        .N(1),
        .D(D)
    ) dut1 (
        .a    (a1),
        .shamt(s1),
        .op   (op1),
        .o    (o1)
    );

    task automatic test_dut1;
        begin
            for (ia = 0; ia < 2; ia = ia + 1) begin
                for (is = 0; is < 2; is = is + 1) begin
                    for (io = 0; io < 8; io = io + 1) begin
                        a1  = ia[0];
                        s1  = is[0];
                        op1 = io[2:0];
                        #1;  // settle
                        check(1, ia, is, io, int'(o1));
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
