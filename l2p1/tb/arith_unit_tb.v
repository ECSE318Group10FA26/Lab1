// Testbench for the structural ALU arithmetic core (arith_unit)
//
// Checks all 8 ops against an independent reference computed from the true
// (unbounded) signed/unsigned arithmetic. Each DUT sweep is a task driving
// its DUT and calling the shared check task (settle, reference, compare,
// report). Widths: N=8 exhaustive over a, b, cin and op (the b and cin
// sweeps double as ignored-input checks for INC/DEC); N=1 covers the
// narrow-width generate paths (lookahead_adder has a dedicated N==1 case).

`timescale 1ns / 1ps

module arith_unit_tb;

    localparam int N = 8;  // main DUT width
    localparam int D = 0;  // gate delay, in `timescale units

    integer errors;
    integer tests;
    integer ia, ib, ic, io;

    // independent reference, from true signed/unsigned math;
    // returns {cout, v, result} (n-bit result in the low bits)
    function automatic [9:0] arith_ref;
        input integer n;
        input integer a_i;
        input integer b_i;
        input integer cin_i;
        input integer op_i;
        integer ua;  // raw (unsigned) value of a
        integer ub;  // raw (unsigned) value of b
        integer uc;  // raw value of cin
        integer ta;  // true signed value of a
        integer tb;  // true signed value of b
        integer tt;  // true signed result
        integer tu;  // true unsigned result
        reg [7:0] r;  // result bits
        reg c, vf;  // cout, v
        begin
            ua = a_i;
            ub = b_i;
            uc = cin_i;
            ta = ua;
            if (ta >= (1 << (n - 1))) ta = ta - (1 << n);
            tb = ub;
            if (tb >= (1 << (n - 1))) tb = tb - (1 << n);
            case (op_i)
                0, 1: begin  // ADD, ADDU
                    tu = ua + ub + uc;
                    tt = ta + tb + uc;
                    r  = tu[7:0];
                    c  = tu[n];
                    vf = (op_i == 1) ? tu[n] : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end
                2, 3: begin  // SUB, SUBU
                    tu = ua - ub;
                    tt = ta - tb;
                    r = tu[7:0];
                    c = (ua >= ub);
                    vf = (op_i == 3) ? (ua < ub)
                                     : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end
                4, 5: begin  // INC, INCU (b and cin ignored)
                    tu = ua + 1;
                    tt = ta + 1;
                    r  = tu[7:0];
                    c  = tu[n];
                    vf = (op_i == 5) ? tu[n] : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end
                default: begin  // DEC, DECU (b and cin ignored)
                    tu = ua - 1;
                    tt = ta - 1;
                    r = tu[7:0];
                    c = (ua >= 1);
                    vf = (op_i == 7) ? (ua < 1)
                                     : (tt < -(1 << (n - 1))) || (tt > (1 << (n - 1)) - 1);
                end
            endcase
            r = r & ((1 << n) - 1);
            arith_ref = {c, vf, r};
        end
    endfunction

    // reference, compare, report for one vector on one DUT (call after
    // the DUT inputs have settled; task inputs sample at call time)
    task automatic check(input integer n, input integer a_i, input integer b_i, input integer c_i,
                         input integer op_i, input logic cout_i, input logic v_i,
                         input integer o_i);
        reg [9:0] e;
        integer e_o;
        begin
            e = arith_ref(n, a_i, b_i, c_i, op_i);
            e_o = int'(e[7:0]);
            tests = tests + 1;
            if (cout_i !== e[9] || v_i !== e[8] || o_i !== e_o) begin
                errors = errors + 1;
                if (errors <= 10)
                    $display(
                        "FAIL (N=%0d): op=%0d a=%0d b=%0d cin=%0d",
                        n,
                        op_i,
                        a_i,
                        b_i,
                        c_i,
                        "  o=%0d (exp %0d) cout=%b (exp %b) v=%b (exp %b)",
                        o_i,
                        e_o,
                        cout_i,
                        e[9],
                        v_i,
                        e[8]
                    );
            end
        end
    endtask

    // N=8 DUT
    reg  [N-1:0] a;
    reg  [N-1:0] b;
    reg          cin;
    reg  [  2:0] op;

    wire [N-1:0] o;
    wire         cout;
    wire         v;

    arith_unit #(
        .N(N),
        .D(D)
    ) dut (
        .a   (a),
        .b   (b),
        .cin (cin),
        .op  (op),
        .o   (o),
        .cout(cout),
        .v   (v)
    );

    task automatic test_dut;
        begin
            for (ia = 0; ia < (1 << N); ia = ia + 1) begin
                for (ib = 0; ib < (1 << N); ib = ib + 1) begin
                    for (ic = 0; ic < 2; ic = ic + 1) begin
                        for (io = 0; io < 8; io = io + 1) begin
                            a   = ia[N-1:0];
                            b   = ib[N-1:0];
                            cin = ic[0];
                            op  = io[2:0];
                            #1;  // settle
                            check(N, ia, ib, ic, io, cout, v, int'(o));
                        end
                    end
                end
            end
        end
    endtask

    // N=1 DUT: narrow-width generate paths
    reg        a1;
    reg        b1;
    reg        cin1;
    reg  [2:0] op1;

    wire       o1;
    wire       cout1;
    wire       v1;

    arith_unit #(
        .N(1),
        .D(D)
    ) dut_n1 (
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
                        for (io = 0; io < 8; io = io + 1) begin
                            a1   = ia[0];
                            b1   = ib[0];
                            cin1 = ic[0];
                            op1  = io[2:0];
                            #1;  // settle
                            check(1, ia, ib, ic, io, cout1, v1, int'(o1));
                        end
                    end
                end
            end
        end
    endtask

    initial begin
        errors = 0;
        tests  = 0;

        test_dut();
        test_dut1();

        if (errors == 0) $display("ALL TESTS PASSED (%0d vectors)", tests);
        else $display("%0d of %0d TESTS FAILED", errors, tests);
        $finish;
    end

endmodule
