// Professor's game, a directed game and random games, all checked against a reference model

`timescale 1ns / 1ps

module fc_check #(
    parameter string ROWS[7] = '{
        "S4 S5 SJ H4 DQ D5 H5 CJ",
        "DJ S10 C7 SA HJ DK D3 D4",
        "D10 H8 C9 CQ SQ C3 HQ H10",
        "D6 C4 C6 C5 S6 D9 D7 C8",
        "S3 H6 C2 S7 D2 H3 CK H7",
        "DA HK SK H9 S9 S2 C10 D8",
        "HA H2 CA S8"
    }
) (
    input wire        clock,
    input wire [ 3:0] source,
    input wire [ 3:0] dest,
    input wire        win,
    input wire [ 2:0] ocnt [8],
    input wire [ 3:0] rlen [8],
    input wire [ 5:0] base [8],
    input wire [12:1] rsuit[8],
    input wire [ 5:0] fcell[4],
    input wire [ 3:0] home [4]
);
    logic [5:0] deal     [8][7];
    int         deal_h   [8];

    logic [5:0] col      [8][24];
    int         height   [8];
    logic [5:0] fc       [4];
    logic [3:0] hrank    [4];

    int         moves = 0;
    int         errors = 0;
    int         illegal    [$];
    int         first_win = 0;
    int         to_empty = 0;
    int         max_run = 0;

    function automatic logic [5:0] parse_card(string t);
        string v = t.substr(1, t.len() - 1);
        logic [1:0] s;
        int r;
        case (t[0])
            "H": s = 2'd0;
            "D": s = 2'd1;
            "S": s = 2'd2;
            default: s = 2'd3;
        endcase
        case (v)
            "A": r = 1;
            "J": r = 11;
            "Q": r = 12;
            "K": r = 13;
            default: r = v.atoi();
        endcase
        return {s, r[3:0]};
    endfunction

    function automatic string name(logic [5:0] c);
        string s = "HDSC";
        string r = "A23456789TJQK";
        if (c[3:0] == 0 || c[3:0] > 13) return "--";
        return $sformatf("%c%c", s[c[5:4]], r[c[3:0]-1]);
    endfunction

    task automatic fail(input string msg);
        errors++;
        if (errors <= 10) $display("FAIL %m @%0t move %0d: %s", $time, moves, msg);
    endtask

    function automatic logic [5:0] top(int c);
        return height[c] == 0 ? 6'd0 : col[c][height[c]-1];
    endfunction

    function automatic logic [5:0] src_card(logic [3:0] src);
        if (!src[3]) return top(src[2:0]);
        if (src[3:2] == 2'b10) return fc[src[1:0]];
        return 6'd0;
    endfunction

    function automatic bit legal(logic [3:0] src, logic [3:0] dst);
        logic [5:0] c = src_card(src);
        logic [5:0] t;
        if (c[3:0] == 0) return 0;
        if (!dst[3]) begin
            t = top(dst[2:0]);
            return t == 0 || (t[3:0] == c[3:0] + 1 && t[5] != c[5]);
        end
        if (dst[3:2] == 2'b10) return fc[dst[1:0]] == 0;
        return hrank[c[5:4]] == c[3:0] - 1;
    endfunction

    task automatic compare();
        logic [5:0] dcol[24];
        logic [5:0] anchor;
        int dh;
        for (int c = 0; c < 8; c++) begin
            dh = 0;
            for (int k = 0; k < ocnt[c]; k++) dcol[dh++] = deal[c][k];
            if (ocnt[c] == 0 && base[c] != 0) dcol[dh++] = base[c];
            anchor = (dh > 0) ? dcol[dh-1] : 6'd0;
            for (int k = 1; k <= rlen[c]; k++)
                dcol[dh++] = {anchor[5] ^ k[0], rsuit[c][k], anchor[3:0] - 4'(k)};
            if (rlen[c] > max_run) max_run = rlen[c];

            if (dh != height[c]) begin
                fail($sformatf("column %0d has %0d cards, expected %0d", c + 1, dh, height[c]));
            end else begin
                for (int k = 0; k < dh; k++)
                    if (dcol[k] !== col[c][k])
                        fail($sformatf("column %0d card %0d is %s, expected %s", c + 1, k,
                                       name(dcol[k]), name(col[c][k])));
            end
        end
        for (int i = 0; i < 4; i++) begin
            if (fcell[i] !== fc[i])
                fail($sformatf("free cell %0d is %s, expected %s", i, name(fcell[i]), name(fc[i])));
            if (home[i] !== hrank[i])
                fail($sformatf("home %0d is %0d, expected %0d", i, home[i], hrank[i]));
        end
        if (win !== (hrank[0] == 13 && hrank[1] == 13 && hrank[2] == 13 && hrank[3] == 13))
            fail($sformatf("win is %b", win));
    endtask

    initial begin
        logic [51:0] seen;
        int c, start;
        seen = '0;
        foreach (deal_h[i]) deal_h[i] = 0;
        foreach (ROWS[r]) begin
            c = 0;
            start = 0;
            for (int i = 0; i <= ROWS[r].len(); i++) begin
                if (i == ROWS[r].len() || ROWS[r][i] == " ") begin
                    if (i > start) begin
                        deal[c][deal_h[c]] = parse_card(ROWS[r].substr(start, i - 1));
                        seen[deal[c][deal_h[c]][5:4]*13+deal[c][deal_h[c]][3:0]-1] = 1'b1;
                        deal_h[c]++;
                        c++;
                    end
                    start = i + 1;
                end
            end
        end
        if (seen !== '1) fail("deal does not contain all 52 cards");

        foreach (height[i]) begin
            height[i] = deal_h[i];
            for (int k = 0; k < deal_h[i]; k++) col[i][k] = deal[i][k];
        end
        foreach (fc[i]) fc[i] = 6'd0;
        foreach (hrank[i]) hrank[i] = 4'd0;

        #0.01 compare();
    end

    always @(posedge clock) begin
        logic [5:0] c;
        moves++;
        if (legal(source, dest)) begin
            c = src_card(source);
            if (!source[3]) height[source[2:0]]--;
            else fc[source[1:0]] = 6'd0;

            if (!dest[3]) begin
                if (height[dest[2:0]] == 0) to_empty++;
                col[dest[2:0]][height[dest[2:0]]++] = c;
            end else if (dest[3:2] == 2'b10) begin
                fc[dest[1:0]] = c;
            end else begin
                hrank[c[5:4]] = c[3:0];
            end
        end else begin
            illegal.push_back(moves);
        end
        if (first_win == 0 && hrank[0] == 13 && hrank[1] == 13 && hrank[2] == 13 && hrank[3] == 13)
            first_win = moves;
    end

    always @(negedge clock) compare();

endmodule

// Random play; avoids filling the free cells so the game doesn't get stuck
module fc_random #(
    parameter int SEED = 1
) (
    input wire clock
);
    logic [3:0] source = 4'd15;
    logic [3:0] dest = 4'd15;
    wire        win;

    freecellPlayer dut (
        clock,
        source,
        dest,
        win
    );

    fc_check chk (
        .clock (clock),
        .source(source),
        .dest  (dest),
        .win   (win),
        .ocnt  (dut.ocnt),
        .rlen  (dut.rlen),
        .base  (dut.base),
        .rsuit (dut.rsuit),
        .fcell (dut.fcell),
        .home  (dut.home)
    );

    logic [7:0] cand  [$];
    logic [7:0] homes [$];
    logic [7:0] builds[$];
    logic [7:0] cells [$];
    int         seed = SEED;

    function automatic int rnd(int n);
        return $unsigned($random(seed)) % n;
    endfunction

    function automatic bit in_run(int s);
        logic [5:0] a, b;
        if (s >= 8 || chk.height[s] < 2) return 0;
        a = chk.col[s][chk.height[s]-1];
        b = chk.col[s][chk.height[s]-2];
        return b[3:0] == a[3:0] + 1 && b[5] != a[5];
    endfunction

    always @(negedge clock) begin
        int r, empty;
        cand.delete();
        homes.delete();
        builds.delete();
        cells.delete();
        empty = 0;
        foreach (chk.fc[i]) if (chk.fc[i] == 0) empty++;
        for (int s = 0; s < 12; s++) begin
            for (int d = 0; d < 13; d++) begin
                if (chk.legal(4'(s), 4'(d))) begin
                    if (d == 12) homes.push_back({4'(s), 4'(d)});
                    if (d < 8 && chk.top(d) != 0 && !in_run(s)) builds.push_back({4'(s), 4'(d)});
                    if (d >= 8 && d < 12) cells.push_back({4'(s), 4'(d)});
                    else cand.push_back({4'(s), 4'(d)});
                end
            end
        end
        if (empty > 2 || cand.size() == 0) foreach (cells[i]) cand.push_back(cells[i]);

        r = rnd(100);
        if (r < 5 || cand.size() == 0) {source, dest} = 8'(rnd(256));
        else if (r < 50 && homes.size() > 0) {source, dest} = homes[rnd(homes.size())];
        else if (r < 80 && builds.size() > 0) {source, dest} = builds[rnd(builds.size())];
        else {source, dest} = cand[rnd(cand.size())];
        if (dest[3:2] == 2'b11) dest[1:0] = 2'(rnd(4));
    end

endmodule

// Custom deal that builds a full K..A run on column 1
module fc_directed;
    localparam string ROWS[7] = '{
        "DA D7 DQ C4 C9 CK H7 S4",
        "D2 D8 DK C5 C10 HA H9 S6",
        "D3 D9 CA C6 CJ H3 HJ S8",
        "D4 D10 C2 C7 CQ H5 HK S10",
        "D5 DJ C3 C8 H2 SA S2 SQ",
        "D6 S5 H4 S3 S9 H8 S7 H6",
        "SK HQ SJ H10"
    };

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

    localparam string MOVES = "21 31 41 51 61 71 81 21 31 41 51 61 1h 1a 7h 1h 1b 1c 1d a1 1a 12";
    logic       clock = 1'b0;
    logic       done = 1'b0;
    logic [3:0] source = 4'd15;
    logic [3:0] dest = 4'd15;
    wire        win;

    function automatic logic [3:0] encode(byte c);
        if (c >= "1" && c <= "8") return 4'(c - "1");
        if (c >= "a" && c <= "d") return 4'(c - "a" + 8);
        return 4'd12;
    endfunction

    freecellPlayer #(
        .DEAL(DEAL)
    ) dut (
        clock,
        source,
        dest,
        win
    );

    fc_check #(
        .ROWS(ROWS)
    ) chk (
        .clock (clock),
        .source(source),
        .dest  (dest),
        .win   (win),
        .ocnt  (dut.ocnt),
        .rlen  (dut.rlen),
        .base  (dut.base),
        .rsuit (dut.rsuit),
        .fcell (dut.fcell),
        .home  (dut.home)
    );

    always #5 if (!done) clock = ~clock;

    initial begin
        for (int i = 0; i < MOVES.len(); i += 3) begin
            source = encode(MOVES[i]);
            dest   = encode(MOVES[i+1]);
            #10;
        end
        done = 1'b1;
    end

endmodule

module freecell_tb;

    localparam int NRAND = 16;
    localparam int EXP_ILLEGAL[6] = '{35, 46, 53, 59, 67, 115};
    localparam int DIR_ILLEGAL[3] = '{20, 21, 22};

    testFreeCell prof ();
    fc_directed dir ();

    fc_check chk_prof (
        .clock (prof.clock),
        .source(prof.source),
        .dest  (prof.dest),
        .win   (prof.win),
        .ocnt  (prof.fc.ocnt),
        .rlen  (prof.fc.rlen),
        .base  (prof.fc.base),
        .rsuit (prof.fc.rsuit),
        .fcell (prof.fc.fcell),
        .home  (prof.fc.home)
    );

    // fast clock so the random games finish before the professor's $finish
    logic rclk = 1'b0;
    always #0.05 rclk = ~rclk;

    int rnd_errors  [NRAND];
    int rnd_moves   [NRAND];
    int rnd_legal   [NRAND];
    int rnd_to_empty[NRAND];
    int rnd_max_run [NRAND];
    int rnd_home    [NRAND];

    for (genvar i = 0; i < NRAND; i++) begin : g_rnd
        fc_random #(.SEED(i + 1)) game (rclk);
        assign rnd_errors[i]   = game.chk.errors;
        assign rnd_moves[i]    = game.chk.moves;
        assign rnd_legal[i]    = game.chk.moves - game.chk.illegal.size();
        assign rnd_to_empty[i] = game.chk.to_empty;
        assign rnd_max_run[i]  = game.chk.max_run;
        assign rnd_home[i]     = game.chk.hrank[0] + game.chk.hrank[1] + game.chk.hrank[2] + game.chk.hrank[3];
    end

    initial begin
        $dumpfile("sim/freecell_tb.vcd");
        $dumpvars(0, prof);
    end

    final begin
        int errors, to_empty, max_run;
        errors   = chk_prof.errors + rnd_errors.sum();
        to_empty = rnd_to_empty.sum();
        max_run  = rnd_max_run.max()[0];

        $display("prof: %0d moves, illegal at %p, win at move %0d", chk_prof.moves,
                 chk_prof.illegal, chk_prof.first_win);
        $display("prof: %0d to an empty column, longest run %0d", chk_prof.to_empty,
                 chk_prof.max_run);
        $display("directed: illegal at %p, longest run %0d", dir.chk.illegal, dir.chk.max_run);
        $display("random: %0d moves (%0d legal), %0d to an empty column, longest run %0d",
                 rnd_moves.sum(), rnd_legal.sum(), to_empty, max_run);
        $display("random: legal moves per game %p, cards home %p", rnd_legal, rnd_home);

        if (chk_prof.illegal != EXP_ILLEGAL) begin
            errors++;
            $display("FAIL prof: illegal moves %p, expected %p", chk_prof.illegal, EXP_ILLEGAL);
        end
        if (chk_prof.moves != 121 || chk_prof.first_win != 121) begin
            errors++;
            $display("FAIL prof: game not won on the last move");
        end
        if (dir.chk.illegal != DIR_ILLEGAL || dir.chk.max_run != 12) begin
            errors++;
            $display("FAIL directed: illegal moves or run length not as expected");
        end
        if (to_empty == 0) begin
            errors++;
            $display("FAIL random: no move to an empty column");
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d checks FAILED", errors);
    end

endmodule
