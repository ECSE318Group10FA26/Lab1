// SSP receive logic, sampled on the falling edge of SSPCLKIN

module ssp_rx (
    input  wire       pclk,
    input  wire       clear_b,
    input  wire       sspclkin,
    input  wire       sspfssin,
    input  wire       ssprxd,
    output reg  [7:0] rx_data,
    output wire       rx_valid
);
    reg [6:0] shreg;
    reg [2:0] bitcnt;
    reg       receiving;
    reg       word_tgl;
    reg [2:0] tgl_sync;

    always @(negedge sspclkin or negedge clear_b) begin
        if (!clear_b) begin
            shreg     <= 7'd0;
            bitcnt    <= 3'd0;
            receiving <= 1'b0;
            word_tgl  <= 1'b0;
            rx_data   <= 8'd0;
        end else if (receiving) begin
            shreg  <= {shreg[5:0], ssprxd};
            bitcnt <= bitcnt + 3'd1;
            if (bitcnt == 3'd7) begin
                rx_data   <= {shreg, ssprxd};
                word_tgl  <= ~word_tgl;
                receiving <= sspfssin;
            end
        end else if (sspfssin) begin
            receiving <= 1'b1;
            bitcnt    <= 3'd0;
        end
    end

    // word_tgl -> PCLK domain
    always @(posedge pclk or negedge clear_b) begin
        if (!clear_b) tgl_sync <= 3'd0;
        else tgl_sync <= {tgl_sync[1:0], word_tgl};
    end

    assign rx_valid = tgl_sync[2] ^ tgl_sync[1];

endmodule
