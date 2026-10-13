// traffic_controller - traffic light controller for the A/B street intersection
//
// States:
//   AG : Ga, Rb for at least 6 clocks, then on to AY once Sb = 1
//   AY : Ya, Rb for 2 clocks
//   BG : Ra, Gb for 5 clocks, extended by 5 more while Sb = 1 and Sa = 0
//   BY : Ra, Yb for 2 clocks
//   FL : fault, Ra and Rb flash with every G/Y off until reset
//
// FL is entered from an illegal state code or when a G/Y is lit on both
// streets at once.

module traffic_controller (
    input  wire clk,
    input  wire rst,  // synchronous reset, to AG
    input  wire Sa,   // car waiting on A street
    input  wire Sb,   // car waiting on B street
    output reg  Ga,
    output reg  Ya,
    output reg  Ra,
    output reg  Gb,
    output reg  Yb,
    output reg  Rb
);
    localparam [2:0] S_AG = 3'd0, S_AY = 3'd1, S_BG = 3'd2, S_BY = 3'd3, S_FL = 3'd4;

    // phase lengths, in clocks
    localparam [2:0] A_GREEN_MIN = 3'd6, YELLOW_LEN = 3'd2, B_GREEN_LEN = 3'd5;

    reg [2:0] state, next_state;
    reg [2:0] cnt, next_cnt;  // clocks spent in the current state
    reg       flash;          // red flash phase, 1 = on

    // lamps decoded from the state, before the guard
    reg rGa, rYa, rRa, rGb, rYb, rRb;

    // G/Y lit on both streets
    wire conflict = (rGa | rYa) & (rGb | rYb);
    wire fault = (state > S_BY) | conflict;

    always @(posedge clk) begin
        if (rst) begin
            state <= S_AG;
            cnt   <= 3'd0;
        end else begin
            state <= next_state;
            cnt   <= next_cnt;
        end
    end

    // reds start on, then toggle every clock in FL
    always @(posedge clk) begin
        if (rst) flash <= 1'b1;
        else if (state == S_FL) flash <= ~flash;
        else flash <= 1'b1;
    end

    always @(*) begin
        next_state = state;
        next_cnt   = cnt + 3'd1;

        case (state)
            S_AG: begin
                if (cnt >= A_GREEN_MIN - 1) begin
                    next_cnt = A_GREEN_MIN - 1;  // saturate
                    if (Sb) begin
                        next_state = S_AY;
                        next_cnt   = 3'd0;
                    end
                end
            end

            S_AY: begin
                if (cnt >= YELLOW_LEN - 1) begin
                    next_state = S_BG;
                    next_cnt   = 3'd0;
                end
            end

            // at the end of each 5-clock block
            S_BG: begin
                if (cnt >= B_GREEN_LEN - 1) begin
                    next_cnt = 3'd0;
                    if (!(Sb && !Sa)) next_state = S_BY;
                end
            end

            S_BY: begin
                if (cnt >= YELLOW_LEN - 1) begin
                    next_state = S_AG;
                    next_cnt   = 3'd0;
                end
            end

            S_FL: begin
                next_state = S_FL;
                next_cnt   = 3'd0;
            end

            // illegal codes 5-7
            default: begin
                next_state = S_FL;
                next_cnt   = 3'd0;
            end
        endcase

        if (conflict) begin
            next_state = S_FL;
            next_cnt   = 3'd0;
        end
    end

    always @(*) begin
        {rGa, rYa, rRa, rGb, rYb, rRb} = 6'b000_000;
        case (state)
            S_AG: begin
                rGa = 1'b1;
                rRb = 1'b1;
            end
            S_AY: begin
                rYa = 1'b1;
                rRb = 1'b1;
            end
            S_BG: begin
                rRa = 1'b1;
                rGb = 1'b1;
            end
            S_BY: begin
                rRa = 1'b1;
                rYb = 1'b1;
            end
            default: begin
                rRa = flash;
                rRb = flash;
            end
        endcase
    end

    // on any fault every G/Y is forced off and the reds flash
    always @(*) begin
        if (fault) {Ga, Ya, Ra, Gb, Yb, Rb} = {1'b0, 1'b0, flash, 1'b0, 1'b0, flash};
        else {Ga, Ya, Ra, Gb, Yb, Rb} = {rGa, rYa, rRa, rGb, rYb, rRb};
    end
endmodule
