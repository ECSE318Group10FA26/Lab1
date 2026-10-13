// Testbench for the traffic light controller (traffic_controller)
//
// Every clock the lamps are checked against a reference model of the phase
// sequence, and a G/Y lit on both streets is flagged as a safety violation.
// Directed tests cover the A green minimum and the B green extension,
// followed by 4000 clocks of random Sa/Sb. Two fault tests (an illegal state
// code and a forced Ga with Gb) must end in flashing reds with every G/Y off.
// Inputs change 2 ns after the falling edge and are checked on the falling
// edge.

`timescale 1ns / 1ps

module tb_traffic_controller;

    reg clk = 0, rst = 1, Sa = 0, Sb = 0;
    wire Ga, Ya, Ra, Gb, Yb, Rb;

    traffic_controller dut (.clk(clk), .rst(rst), .Sa(Sa), .Sb(Sb),
                            .Ga(Ga), .Ya(Ya), .Ra(Ra),
                            .Gb(Gb), .Yb(Yb), .Rb(Rb));

    always #5 clk = ~clk;  // 10 ns period

    // phase shown by the lamps
    localparam AG = 0, AY = 1, BG = 2, BY = 3, FLON = 4, FLOFF = 5, BAD = 6;

    function integer phase_of;
        input ga, ya, ra, gb, yb, rb;
        case ({ga, ya, ra, gb, yb, rb})
            6'b100_001: phase_of = AG;
            6'b010_001: phase_of = AY;
            6'b001_100: phase_of = BG;
            6'b001_010: phase_of = BY;
            6'b001_001: phase_of = FLON;
            6'b000_000: phase_of = FLOFF;
            default:    phase_of = BAD;
        endcase
    endfunction

    function [8*5-1:0] pname;
        input integer p;
        case (p)
            AG: pname = "GaRb "; AY: pname = "YaRb "; BG: pname = "RaGb ";
            BY: pname = "RaYb "; FLON: pname = "RaRb*"; FLOFF: pname = "off  ";
            default: pname = "BAD  ";
        endcase
    endfunction

    integer errors = 0, cycles = 0;
    integer phase, prev_phase, len, prev_len, expected;
    reg     have_prev  = 0;
    reg     fault_mode = 0;  // set during the fault tests
    integer last_fl    = -1;  // Ra on the previous FL clock

    // statistics for the summary
    integer n_a_to_b = 0, n_b_ext = 0, n_a_hold_waits = 0;
    integer min_ag = 999, max_bg = 0;

    always @(negedge clk) begin
        cycles = cycles + 1;
        phase  = phase_of(Ga, Ya, Ra, Gb, Yb, Rb);

        // safety, every clock
        if (Ga && Gb) begin
            errors = errors + 1;
            $display("%0t  SAFETY VIOLATION: Ga and Gb both on", $time);
        end
        if ((Ga | Ya) && (Gb | Yb)) begin
            errors = errors + 1;
            $display("%0t  SAFETY VIOLATION: non-red on both streets", $time);
        end

        if (fault_mode) begin
            if (Ga | Ya | Gb | Yb) begin
                errors = errors + 1;
                $display("%0t  FAULT ERROR: G/Y lit during fault", $time);
            end
            if (Ra !== Rb) begin
                errors = errors + 1;
                $display("%0t  FAULT ERROR: Ra and Rb not flashing together", $time);
            end
            if (dut.state == 3'd4) begin
                if (last_fl != -1 && Ra == last_fl) begin
                    errors = errors + 1;
                    $display("%0t  FAULT ERROR: red not toggling", $time);
                end
                last_fl = Ra;
            end
            have_prev = 0;
        end
        else if (rst) begin
            if (phase != AG) begin
                errors = errors + 1;
                $display("%0t  ERROR: not GaRb during reset", $time);
            end
            prev_phase = AG; prev_len = 1; have_prev = 1;
        end
        else begin
            if (phase == BAD || phase == FLON || phase == FLOFF) begin
                errors = errors + 1;
                $display("%0t  ERROR: illegal light pattern %b%b%b %b%b%b",
                         $time, Ga, Ya, Ra, Gb, Yb, Rb);
            end
            if (have_prev) begin
                // reference model
                case (prev_phase)
                    AG: expected = (prev_len >= 6 && Sb) ? AY : AG;
                    AY: expected = (prev_len >= 2) ? BG : AY;
                    BG: expected = (prev_len % 5 == 0) ? ((Sb && !Sa) ? BG : BY) : BG;
                    BY: expected = (prev_len >= 2) ? AG : BY;
                    default: expected = BAD;
                endcase
                if (phase != expected) begin
                    errors = errors + 1;
                    $display("%0t  ERROR: after %s x%0d (Sa=%b Sb=%b) expected %s got %s",
                             $time, pname(prev_phase), prev_len, Sa, Sb,
                             pname(expected), pname(phase));
                end

                if (prev_phase == AG && prev_len < 6 && Sb) n_a_hold_waits = n_a_hold_waits + 1;
                if (prev_phase == BG && phase == BG && prev_len % 5 == 0) n_b_ext = n_b_ext + 1;
                if (prev_phase == AG && phase == AY) begin
                    n_a_to_b = n_a_to_b + 1;
                    if (prev_len < min_ag) min_ag = prev_len;
                end
                if (prev_phase == BG && phase == BY && prev_len > max_bg) max_bg = prev_len;

                len = (phase == prev_phase) ? prev_len + 1 : 1;
            end else
                len = 1;

            prev_phase = phase; prev_len = len; have_prev = 1;
        end
    end

    task drive(input a, input b, input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(negedge clk); #2;
                Sa = a; Sb = b;
            end
        end
    endtask

    task do_reset;
        begin
            @(negedge clk); #2 rst = 1; Sa = 0; Sb = 0;
            fault_mode = 0;
            @(negedge clk); #2 rst = 1;
            @(negedge clk); #2 rst = 0;
        end
    endtask

    integer i, k;

    initial begin
        $dumpfile("sim/tb_traffic_controller.vcd");
        $dumpvars(0);

        $display("--- T1: reset, cars only on A: A must stay green");
        do_reset;
        drive(1, 0, 20);

        $display("--- T2: car on B arrives early: A still green for >= 6 clocks");
        do_reset;
        drive(1, 1, 30);

        $display("--- T3: B busy, A empty: B green extended in 5-clock blocks");
        drive(0, 1, 18);
        drive(1, 1, 12);

        $display("--- T4: short Sb pulse while A green < 6 clocks, then gone");
        do_reset;
        drive(0, 0, 2);
        drive(0, 1, 1);
        drive(0, 0, 12);

        $display("--- T5: 4000 random cycles");
        do_reset;
        for (i = 0; i < 4000; i = i + 1) begin
            @(negedge clk); #2;
            if ($random % 8 == 0) Sa = ~Sa;
            if ($random % 6 == 0) Sb = ~Sb;
        end

        $display("--- T6: illegal state code -> flashing reds");
        drive(1, 1, 3);
        @(negedge clk); #2 force dut.state = 3'd6;
        fault_mode = 1; last_fl = -1;
        @(posedge clk); #1 release dut.state;
        drive(1, 1, 10);
        if (dut.state !== 3'd4) begin
            errors = errors + 1; $display("T6 ERROR: did not enter S_FL");
        end

        $display("--- T7: forced Ga&Gb conflict -> guard + flashing reds");
        do_reset;
        drive(1, 1, 1);
        k = 0;
        while (dut.state != 3'd2 && k < 50) begin drive(1, 1, 1); k = k + 1; end
        fault_mode = 1; last_fl = -1;
        #1 force dut.rGa = 1'b1;  // decode fault, Ga lit with Gb
        #1 if (Ga || Gb || !Ra || !Rb) begin
            errors = errors + 1; $display("T7 ERROR: guard did not act immediately");
        end
        @(posedge clk); #1 release dut.rGa;
        drive(1, 1, 10);
        if (dut.state !== 3'd4) begin
            errors = errors + 1; $display("T7 ERROR: did not enter S_FL");
        end

        $display("");
        $display("==================== SUMMARY ====================");
        $display(" cycles simulated            : %0d", cycles);
        $display(" A->B changes                : %0d", n_a_to_b);
        $display(" shortest A green seen       : %0d clocks", min_ag);
        $display(" Sb=1 ignored (A green < 6)  : %0d times", n_a_hold_waits);
        $display(" B green 5-clock extensions  : %0d", n_b_ext);
        $display(" longest B green seen        : %0d clocks", max_bg);
        if (errors == 0) $display(" RESULT: PASS - 0 errors, no safety violations");
        else             $display(" RESULT: FAIL - %0d errors", errors);
        $display("=================================================");
        $finish;
    end

    // trace of the first 120 clocks
    always @(negedge clk)
        if (cycles <= 120)
            $display("%5t  rst=%b Sa=%b Sb=%b | %s | Ga Ya Ra=%b%b%b  Gb Yb Rb=%b%b%b",
                     $time, rst, Sa, Sb, pname(phase_of(Ga,Ya,Ra,Gb,Yb,Rb)),
                     Ga, Ya, Ra, Gb, Yb, Rb);

endmodule
