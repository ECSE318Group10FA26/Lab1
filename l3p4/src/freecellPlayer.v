// FreeCell player, starts from deal 8321
// card = {suit, rank}, suit[1] = black, rank 0 = no card

module freecellPlayer (
    input  wire       clock,
    input  wire [3:0] source,
    input  wire [3:0] dest,
    output wire       win
);
    localparam logic [1:0] H = 2'd0, D = 2'd1, S = 2'd2, C = 2'd3;
    localparam logic [3:0] A = 4'd1, J = 4'd11, Q = 4'd12, K = 4'd13;

    // DEAL[col][row], row 0 = deepest card
    parameter logic [5:0] DEAL[8][7] = '{
        '{{S, 4'd4}, {D, J}, {D, 4'd10}, {D, 4'd6}, {S, 4'd3}, {D, A}, {H, A}},
        '{{S, 4'd5}, {S, 4'd10}, {H, 4'd8}, {C, 4'd4}, {H, 4'd6}, {H, K}, {H, 4'd2}},
        '{{S, J}, {C, 4'd7}, {C, 4'd9}, {C, 4'd6}, {C, 4'd2}, {S, K}, {C, A}},
        '{{H, 4'd4}, {S, A}, {C, Q}, {C, 4'd5}, {S, 4'd7}, {H, 4'd9}, {S, 4'd8}},
        '{{D, Q}, {H, J}, {S, Q}, {S, 4'd6}, {D, 4'd2}, {S, 4'd9}, 6'd0},
        '{{D, 4'd5}, {D, K}, {C, 4'd3}, {D, 4'd9}, {H, 4'd3}, {S, 4'd2}, 6'd0},
        '{{H, 4'd5}, {D, 4'd3}, {H, Q}, {D, 4'd7}, {C, K}, {C, 4'd10}, 6'd0},
        '{{C, J}, {D, 4'd4}, {H, 4'd10}, {C, 4'd8}, {H, 4'd7}, {D, 4'd8}, 6'd0}
    };

    // stacked cards alternate color and drop one rank, so only suit[0] is kept
    reg  [ 2:0] ocnt [8];  // dealt cards left
    reg  [ 3:0] rlen [8];  // stacked cards
    reg  [ 5:0] base [8];  // card moved into an empty column
    reg  [12:1] rsuit[8];
    reg  [ 5:0] fcell[4];
    reg  [ 3:0] home [4];  // top rank per suit

    initial begin
        for (int i = 0; i < 8; i++) begin
            ocnt[i]  = (i < 4) ? 3'd7 : 3'd6;
            rlen[i]  = 4'd0;
            base[i]  = 6'd0;
            rsuit[i] = 12'd0;
        end
        for (int i = 0; i < 4; i++) begin
            fcell[i] = 6'd0;
            home[i]  = 4'd0;
        end
    end

    // top card of each column
    wire [5:0] anchor[8];
    wire [5:0] head  [8];

    genvar i;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_col
            assign anchor[i] = (ocnt[i] != 3'd0) ? DEAL[i][ocnt[i]-3'd1] : base[i];
            assign head[i] = (rlen[i] == 4'd0) ? anchor[i] :
                {anchor[i][5] ^ rlen[i][0], rsuit[i][rlen[i]], anchor[i][3:0] - rlen[i]};
        end
    endgenerate

    wire [2:0] scol = source[2:0];
    wire [2:0] dcol = dest[2:0];

    wire from_col = ~source[3];
    wire from_cell = source[3:2] == 2'b10;
    wire to_col = ~dest[3];
    wire to_cell = dest[3:2] == 2'b10;

    wire [5:0] card = from_col ? head[scol] : from_cell ? fcell[source[1:0]] : 6'd0;
    wire [1:0] suit = card[5:4];
    wire [3:0] rank = card[3:0];
    wire [5:0] dtop = head[dcol];

    wire col_ok = (dtop == 6'd0) || (dtop[3:0] == rank + 4'd1 && dtop[5] != suit[1]);
    wire cell_ok = fcell[dest[1:0]] == 6'd0;
    wire home_ok = home[suit] == rank - 4'd1;

    wire legal = (rank != 4'd0) && (to_col ? col_ok : to_cell ? cell_ok : home_ok);

    always @(posedge clock) begin
        if (legal) begin
            if (from_col) begin
                if (rlen[scol] != 4'd0) rlen[scol] <= rlen[scol] - 4'd1;
                else if (ocnt[scol] != 3'd0) ocnt[scol] <= ocnt[scol] - 3'd1;
                else base[scol] <= 6'd0;
            end else begin
                fcell[source[1:0]] <= 6'd0;
            end

            if (to_col) begin
                if (dtop == 6'd0) begin
                    base[dcol] <= card;
                end else begin
                    rlen[dcol] <= rlen[dcol] + 4'd1;
                    rsuit[dcol][rlen[dcol]+4'd1] <= suit[0];
                end
            end else if (to_cell) begin
                fcell[dest[1:0]] <= card;
            end else begin
                home[suit] <= rank;
            end
        end
    end

    assign win = home[0] == K && home[1] == K && home[2] == K && home[3] == K;

endmodule
