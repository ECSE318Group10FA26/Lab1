// ============================================================================
// ECSE 318 - HW #2, Problem 3
// Safe sequential traffic-light controller for the A-street / B-street
// intersection.
//
//   State  Lights    Duration
//   -----  --------  -----------------------------------------------------
//   S_AG   Ga  Rb    at least 6 clocks; leaves only when Sb = 1
//   S_AY   Ya  Rb    exactly 2 clocks
//   S_BG   Ra  Gb    5 clocks; at the end of every 5-clock block it is
//                    extended another 5 clocks if (Sb = 1 and Sa = 0)
//   S_BY   Ra  Yb    exactly 2 clocks
//   S_FL   Ra, Rb flash (1 clock on / 1 clock off), every G and Y off.
//          Fault state: entered on an illegal state code or on a detected
//          green/green (or green/yellow) conflict.  Leaves only on reset.
//
// Reset: synchronous, active high, puts the controller in S_AG.
// ============================================================================
`timescale 1ns/1ps

module traffic_controller (
    input  wire clk,
    input  wire rst,          // synchronous, active-high
    input  wire Sa,           // car on A street
    input  wire Sb,           // car on B street
    output reg  Ga, Ya, Ra,   // A-street lamps
    output reg  Gb, Yb, Rb    // B-street lamps
);

    // ---------------- state encoding ----------------
    // 3 bits: 5 legal codes, 3 illegal codes (5,6,7) that all go to S_FL.
    localparam [2:0] S_AG = 3'd0,
                     S_AY = 3'd1,
                     S_BG = 3'd2,
                     S_BY = 3'd3,
                     S_FL = 3'd4;

    // ---------------- timing parameters (in clock periods) ----------------
    localparam [2:0] A_GREEN_MIN = 3'd6,
                     YELLOW_LEN  = 3'd2,
                     B_GREEN_LEN = 3'd5;

    reg  [2:0] state, next_state;
    reg  [2:0] cnt,   next_cnt;     // clocks already spent in current state
    reg        flash;               // red-flash phase (1 = lamp on)

    // "raw" lamp values decoded from the state, before the safety guard
    reg rGa, rYa, rRa, rGb, rYb, rRb;

    // ---------------- safety monitor ----------------
    // Conflict = a non-red light shown on BOTH streets.  This includes the
    // Ga & Gb case required by the problem, plus Ga&Yb, Ya&Gb, Ya&Yb.
    wire conflict = (rGa | rYa) & (rGb | rYb);

    // ---------------- state register ----------------
    always @(posedge clk) begin
        if (rst) begin
            state <= S_AG;
            cnt   <= 3'd0;
        end else begin
            state <= next_state;
            cnt   <= next_cnt;
        end
    end

    // flash toggles every clock while in S_FL; it is 1 on the first
    // fault clock so the reds are ON immediately.
    always @(posedge clk) begin
        if (rst)                flash <= 1'b1;
        else if (state == S_FL) flash <= ~flash;
        else                    flash <= 1'b1;
    end

    // ---------------- next-state logic ----------------
    always @(*) begin
        next_state = state;
        next_cnt   = cnt + 3'd1;

        case (state)
            // A green: hold for at least 6 clocks, then change only on Sb
            S_AG: begin
                if (cnt >= A_GREEN_MIN - 1) begin
                    next_cnt = A_GREEN_MIN - 1;          // saturate
                    if (Sb) begin
                        next_state = S_AY;
                        next_cnt   = 3'd0;
                    end
                end
            end

            // A yellow: exactly 2 clocks, then B green
            S_AY: begin
                if (cnt >= YELLOW_LEN - 1) begin
                    next_state = S_BG;
                    next_cnt   = 3'd0;
                end
            end

            // B green: 5 clocks; extend by 5 if car on B and none on A
            S_BG: begin
                if (cnt >= B_GREEN_LEN - 1) begin
                    next_cnt = 3'd0;
                    if (!(Sb && !Sa))
                        next_state = S_BY;
                    // else: stay in S_BG, new 5-clock block
                end
            end

            // B yellow: exactly 2 clocks, then A green
            S_BY: begin
                if (cnt >= YELLOW_LEN - 1) begin
                    next_state = S_AG;
                    next_cnt   = 3'd0;
                end
            end

            // Fault: stay flashing until reset
            S_FL: begin
                next_state = S_FL;
                next_cnt   = 3'd0;
            end

            // Illegal code (5,6,7): fail safe
            default: begin
                next_state = S_FL;
                next_cnt   = 3'd0;
            end
        endcase

        // Any detected conflict also forces the fault state.
        if (conflict) begin
            next_state = S_FL;
            next_cnt   = 3'd0;
        end
    end

    // ---------------- output decode (Moore) ----------------
    always @(*) begin
        {rGa, rYa, rRa, rGb, rYb, rRb} = 6'b000_000;
        case (state)
            S_AG:    begin rGa = 1'b1; rRb = 1'b1; end
            S_AY:    begin rYa = 1'b1; rRb = 1'b1; end
            S_BG:    begin rRa = 1'b1; rGb = 1'b1; end
            S_BY:    begin rRa = 1'b1; rYb = 1'b1; end
            default: begin rRa = flash; rRb = flash; end   // S_FL + illegal
        endcase
    end

    // ---------------- safety guard on the outputs ----------------
    // If a conflict is ever present, every G/Y is forced off at once and the
    // reds flash; the FSM is sent to S_FL on the next clock.
    always @(*) begin
        if (conflict)
            {Ga, Ya, Ra, Gb, Yb, Rb} = {1'b0, 1'b0, flash, 1'b0, 1'b0, flash};
        else
            {Ga, Ya, Ra, Gb, Yb, Rb} = {rGa, rYa, rRa, rGb, rYb, rRb};
    end

endmodule
