// Checks the professor's game, plus a custom deal that builds a full K..A run

`timescale 1ns / 1ps

module fc_directed;
    localparam logic [1:0] H = 2'd0, D = 2'd1, S = 2'd2, C = 2'd3;
    localparam logic [5:0] DEAL[8][7] = '{
        '{{D, 4'd1}, {D, 4'd2}, {D, 4'd3}, {D, 4'd4}, {D, 4'd5}, {D, 4'd6}, {S, 4'd13}},
        '{{D, 4'd7}, {D, 4'd8}, {D, 4'd9}, {D, 4'd10}, {D, 4'd11}, {S, 4'd5}, {H, 4'd12}},
        '{{D, 4'd12}, {D, 4'd13}, {C, 4'd1}, {C, 4'd2}, {C, 4'd3}, {H, 4'd4}, {S, 4'd11}},
        '{{C, 4'd4}, {C, 4'd5}, {C, 4'd6}, {C, 4'd7}, {C, 4'd8}, {S, 4'd3}, {H, 4'd10}},
        '{{C, 4'd9}, {C, 4'd10}, {C, 4'd11}, {C, 4'd12}, {H, 4'd2}, {S, 4'd9}, 6'd0},
        '{{C, 4'd13}, {H, 4'd1}, {H, 4'd3}, {H, 4'd5}, {S, 4'd1}, {H, 4'd8}, 6'd0},
        '{{H, 4'd7}, {H, 4'd9}, {H, 4'd11}, {H, 4'd13}, {S, 4'd2}, {S, 4'd7}, 6'd0},
        '{{S, 4'd4}, {S, 4'd6}, {S, 4'd8}, {S, 4'd10}, {S, 4'd12}, {H, 4'd6}, 6'd0}
    };

    logic       clock = 1'b0;
    logic       done = 1'b0;
    logic [3:0] source = 4'd15;
    logic [3:0] dest = 4'd15;
    wire        win;

    int         moves = 0;
    int         illegal[$];
    int         errors = 0;

    freecellPlayer #(
        .DEAL(DEAL)
    ) dut (
        clock,
        source,
        dest,
        win
    );

    always #5 if (!done) clock = ~clock;

    always @(posedge clock) begin
        moves++;
        if (!dut.legal) illegal.push_back(moves);
    end

    function automatic logic [3:0] encode(byte c);
        if (c >= "1" && c <= "8") return 4'(c - "1");
        if (c >= "a" && c <= "d") return 4'(c - "a" + 8);
        return 4'd12;
    endfunction

    task automatic move(input [15:0] m);
        source = encode(m[15:8]);
        dest   = encode(m[7:0]);
        #10;
    endtask

    task automatic expect_eq(input int got, input int exp, input string what);
        if (got != exp) begin
            errors++;
            $display("FAIL directed: %s is %0d, expected %0d", what, got, exp);
        end
    endtask

    initial begin
        // stack QH, JS, ... down to AS on the KS in column 1
        move("21"); move("31"); move("41"); move("51"); move("61"); move("71");
        move("81"); move("21"); move("31"); move("41"); move("51"); move("61");
        #1;
        expect_eq(dut.rlen[0], 12, "run length");
        expect_eq(dut.head[0], {S, 4'd1}, "top of column 1");

        // take part of the run apart again
        move("1h"); move("1a"); move("7h"); move("1h"); move("1b"); move("1c"); move("1d");
        // 20: H2 can't go on 7S, 21: cell a is full, 22: 7S can't go on JD
        move("a1"); move("1a"); move("12");
        #1;
        expect_eq(dut.rlen[0], 6, "run length");
        expect_eq(dut.home[S], 3, "spades home");
        done = 1'b1;
    end

endmodule

module freecell_tb;

    localparam int EXP_ILLEGAL[6] = '{35, 46, 53, 59, 67, 115};

    testFreeCell prof ();
    fc_directed dir ();

    int moves = 0;
    int illegal[$];
    int to_empty = 0;
    int win_at = 0;

    always @(posedge prof.clock) begin
        moves++;
        if (!prof.fc.legal) illegal.push_back(moves);
        else if (prof.fc.to_col && prof.fc.dtop == 0) to_empty++;
    end

    always @(posedge prof.win) win_at = moves;

    initial begin
        $dumpfile("sim/freecell_tb.vcd");
        $dumpvars(0, prof);
    end

    final begin
        int errors;
        errors = dir.errors;

        $display("prof: %0d moves, illegal at %p, win on move %0d, %0d moves to an empty column",
                 moves, illegal, win_at, to_empty);
        $display("directed: illegal at %p", dir.illegal);

        if (illegal != EXP_ILLEGAL) begin
            errors++;
            $display("FAIL prof: illegal moves %p, expected %p", illegal, EXP_ILLEGAL);
        end
        if (win_at != 121 || moves != 121) begin
            errors++;
            $display("FAIL prof: game not won on the last move");
        end
        if (dir.illegal != '{20, 21, 22}) begin
            errors++;
            $display("FAIL directed: illegal moves %p, expected '{20, 21, 22}", dir.illegal);
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d checks FAILED", errors);
    end

endmodule
