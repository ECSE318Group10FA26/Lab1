// Testbench for the structural ALU (alu_core)
//
// Checks all 64 op encodings against an independent integer-math
// reference. Each DUT sweep is a task driving its DUT and calling the
// shared check task (settle, reference, compare, report).
// Widths: N=8 exhaustive over a x b x cin x op, N=6 (non-power-of-2),
// N=1 (minimal), N=16 (corner-case operand set; exhaustive is infeasible).

`timescale 1ns / 1ps

module alu_core_tb;

    localparam int D = 0;  // gate delay, in `timescale units

    integer errors;
    integer tests;
    integer ia, ib, ic, io;

    // independent reference: integer math, width-parameterized;
    // returns {cout, v, result} (n-bit result in the low bits)
    function automatic [17:0] alu_ref;
        input integer n;
        input integer a_i;
        input integer b_i;
        input integer cin_i;
        input integer op_i;
        integer ta, tb;  // true signed operands
        integer tt;  // true signed result
        integer tu;  // true unsigned result
        integer lgm;  // shift-amount width = clog2(n)
        integer sh;  // shift amount = b's low lgm bits
        integer sm;  // sh mod n (rotates)
        reg lt, eq, gt;
        reg [15:0] r;  // result bits
        reg c, vf;  // cout, v
        begin
            ta = (a_i >= (1 << (n - 1))) ? a_i - (1 << n) : a_i;
            tb = (b_i >= (1 << (n - 1))) ? b_i - (1 << n) : b_i;
            r  = 0;
            c  = 0;
            vf = 0;
            if (op_i < 8) begin  // arith
                if (op_i[2]) begin  // INC, INCU / DEC, DECU (b and cin ignored)
                    if (op_i[1]) begin  // DEC, DECU
                        tu = a_i - 1;
                        tt = ta - 1;
                        c = (a_i >= 1);
                        vf = (op_i[0]) ? (a_i < 1)
                                       : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                    end else begin  // INC, INCU
                        tu = a_i + 1;
                        tt = ta + 1;
                        c = (tu >= (1 << n));
                        vf = (op_i[0]) ? (tu >= (1 << n))
                                       : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                    end
                end else if (op_i[1]) begin  // SUB, SUBU
                    tu = a_i - b_i;
                    tt = ta - tb;
                    c = (a_i >= b_i);
                    vf = (op_i[0]) ? (a_i < b_i)
                                   : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end else begin  // ADD, ADDU
                    tu = a_i + b_i + cin_i;
                    tt = ta + tb + cin_i;
                    c = (tu >= (1 << n));
                    vf = (op_i[0]) ? (tu >= (1 << n))
                                   : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end
                r = tu[15:0];
            end else if (op_i < 16) begin  // logic
                case (op_i[1:0])
                    0: r = a_i[15:0] & b_i[15:0];
                    1: r = a_i[15:0] | b_i[15:0];
                    2: r = a_i[15:0] ^ b_i[15:0];
                    default: r = a_i[15:0];
                endcase
                if (op_i[2]) r = ~r;  // NAND, NOR, XNOR, NOT
            end else if (op_i < 32) begin  // shift
                lgm = 1;
                while ((1 << lgm) < n) lgm = lgm + 1;
                sh = b_i & ((1 << lgm) - 1);
                sm = sh % n;
                case (op_i[2:0])
                    0: r = a_i[15:0] >> sh;  // SRL
                    1: r = 16'($unsigned(ta >>> sh));  // SRA
                    2, 3: r = (a_i[15:0] >> sm) | (a_i[15:0] << (n - sm));  // ROR
                    4, 5: r = a_i[15:0] << sh;  // SLL
                    default: r = (a_i[15:0] << sm) | (a_i[15:0] >> (n - sm));  // ROL
                endcase
            end else begin  // comp
                if (op_i[3]) lt = (a_i < b_i);
                else lt = (ta < tb);
                eq = (a_i == b_i);
                gt = !(lt || eq);
                r  = (op_i[0] & lt) | (op_i[1] & eq) | (op_i[2] & gt);
            end
            r = r & ((1 << n) - 1);
            alu_ref = {c, vf, r};
        end
    endfunction

    // settle, reference, compare, report for one vector on one DUT
    // reference, compare, report for one vector on one DUT (call after
    // the DUT inputs have settled; task inputs sample at call time)
    task automatic check(input integer n, input integer a_i, input integer b_i, input integer c_i,
                         input integer op_i, input logic cout_i, input logic v_i,
                         input integer o_i);
        reg [17:0] e;
        integer    e_o;
        begin
            e = alu_ref(n, a_i, b_i, c_i, op_i);
            e_o = int'(e[15:0]);
            tests = tests + 1;
            if (cout_i !== e[17] || v_i !== e[16] || o_i !== e_o) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display(
                        "FAIL (N=%0d): op=%0d a=%0d b=%0d cin=%0d",
                        n,
                        op_i,
                        a_i,
                        b_i,
                        c_i,
                        "  o=%0d cout=%b v=%b (exp o=%0d cout=%b v=%b)",
                        o_i,
                        cout_i,
                        v_i,
                        e_o,
                        e[17],
                        e[16]
                    );
            end
        end
    endtask

    // N=8 DUT
    reg  [7:0] a8;
    reg  [7:0] b8;
    reg        cin8;
    reg  [5:0] op8;
    wire [7:0] o8;
    wire       cout8;
    wire       v8;

    alu_core #(
        .N(8),
        .D(D)
    ) dut8 (
        .a   (a8),
        .b   (b8),
        .cin (cin8),
        .op  (op8),
        .o   (o8),
        .cout(cout8),
        .v   (v8)
    );

    // N=8: exhaustive over a x b x cin x op
    task automatic test_dut8;
        begin
            for (ia = 0; ia < 256; ia = ia + 1) begin
                for (ib = 0; ib < 256; ib = ib + 1) begin
                    for (ic = 0; ic < 2; ic = ic + 1) begin
                        for (io = 0; io < 64; io = io + 1) begin
                            a8   = ia[7:0];
                            b8   = ib[7:0];
                            cin8 = ic[0];
                            op8  = io[5:0];
                            #1;  // settle
                            check(8, ia, ib, ic, io, cout8, v8, int'(o8));
                        end
                    end
                end
            end
        end
    endtask

    // N=6 DUT: non-power-of-2 width
    reg  [5:0] a6;
    reg  [5:0] b6;
    reg        cin6;
    reg  [5:0] op6;
    wire [5:0] o6;
    wire       cout6;
    wire       v6;

    alu_core #(
        .N(6),
        .D(D)
    ) dut6 (
        .a   (a6),
        .b   (b6),
        .cin (cin6),
        .op  (op6),
        .o   (o6),
        .cout(cout6),
        .v   (v6)
    );

    task automatic test_dut6;
        begin
            for (ia = 0; ia < 64; ia = ia + 1) begin
                for (ib = 0; ib < 64; ib = ib + 1) begin
                    for (ic = 0; ic < 2; ic = ic + 1) begin
                        for (io = 0; io < 64; io = io + 1) begin
                            a6   = ia[5:0];
                            b6   = ib[5:0];
                            cin6 = ic[0];
                            op6  = io[5:0];
                            #1;  // settle
                            check(6, ia, ib, ic, io, cout6, v6, int'(o6));
                        end
                    end
                end
            end
        end
    endtask

    // N=1 DUT: minimal width
    reg        a1;
    reg        b1;
    reg        cin1;
    reg  [5:0] op1;
    wire       o1;
    wire       cout1;
    wire       v1;

    alu_core #(
        .N(1),
        .D(D)
    ) dut1 (
        .a   (a1),
        .b   (b1),
        .cin (cin1),
        .op  (op1),
        .o   (o1),
        .cout(cout1),
        .v   (v1)
    );

    task automatic test_dut1;
        begin
            for (ia = 0; ia < 2; ia = ia + 1) begin
                for (ib = 0; ib < 2; ib = ib + 1) begin
                    for (ic = 0; ic < 2; ic = ic + 1) begin
                        for (io = 0; io < 64; io = io + 1) begin
                            a1   = ia[0];
                            b1   = ib[0];
                            cin1 = ic[0];
                            op1  = io[5:0];
                            #1;  // settle
                            check(1, ia, ib, ic, io, cout1, v1, int'(o1));
                        end
                    end
                end
            end
        end
    endtask

    // N=16 DUT: corner-case operand set
    reg  [15:0] a16;
    reg  [15:0] b16;
    reg         cin16;
    reg  [ 5:0] op16;
    wire [15:0] o16;
    wire        cout16;
    wire        v16;

    alu_core #(
        .N(16),
        .D(D)
    ) dut16 (
        .a   (a16),
        .b   (b16),
        .cin (cin16),
        .op  (op16),
        .o   (o16),
        .cout(cout16),
        .v   (v16)
    );

    // operand corners: zero, one, small, byte/half boundaries, maxpos,
    // minneg, -1, alternating patterns
    reg [15:0] vals[16];

    task automatic test_dut16;
        begin
            for (ia = 0; ia < 16; ia = ia + 1) begin
                for (ib = 0; ib < 16; ib = ib + 1) begin
                    for (ic = 0; ic < 2; ic = ic + 1) begin
                        for (io = 0; io < 64; io = io + 1) begin
                            a16   = vals[ia];
                            b16   = vals[ib];
                            cin16 = ic[0];
                            op16  = io[5:0];
                            #1;  // settle
                            check(16, int'(vals[ia]), int'(vals[ib]), ic, io, cout16, v16,
                                  int'(o16));
                        end
                    end
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        tests = 0;

        vals[0] = 16'h0000;
        vals[1] = 16'h0001;
        vals[2] = 16'h0002;
        vals[3] = 16'h002A;  // 42
        vals[4] = 16'h00FF;
        vals[5] = 16'h0100;
        vals[6] = 16'h5555;
        vals[7] = 16'h7FFF;  // most positive
        vals[8] = 16'h8000;  // most negative
        vals[9] = 16'h8001;
        vals[10] = 16'hAAAA;
        vals[11] = 16'hFF00;
        vals[12] = 16'hFFFE;  // -2
        vals[13] = 16'hFFFF;  // -1 / max unsigned
        vals[14] = 16'h1234;
        vals[15] = 16'hBEEF;

        test_dut8();
        test_dut6();
        test_dut1();
        test_dut16();

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
