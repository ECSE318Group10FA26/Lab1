// SSP transmit logic, SSPCLKOUT = PCLK / 2

module ssp_tx (
    input  wire       pclk,
    input  wire       clear_b,
    input  wire [7:0] fifo_data,
    input  wire       fifo_empty,
    output wire       fifo_rd,
    output reg        sspclkout,
    output wire       sspfssout,
    output reg        ssptxd,
    output reg        sspoe_b
);
    reg [7:0] shreg;
    reg [2:0] bitcnt;  // 0 = MSB
    reg       loaded;  // frame pulse period
    reg       active;  // ssptxd carries a data bit

    // PCLK edges where SSPCLKOUT rises / falls
    wire rise = ~sspclkout;
    wire fall = sspclkout;

    wire shifting = loaded | (active & (bitcnt != 3'd7));
    wire can_load = ~loaded & (~active | (bitcnt >= 3'd6));

    assign fifo_rd   = rise & can_load & ~fifo_empty;
    assign sspfssout = loaded;

    always @(posedge pclk or negedge clear_b) begin
        if (!clear_b) sspclkout <= 1'b0;
        else sspclkout <= ~sspclkout;
    end

    always @(posedge pclk or negedge clear_b) begin
        if (!clear_b) begin
            shreg  <= 8'd0;
            bitcnt <= 3'd0;
            loaded <= 1'b0;
            active <= 1'b0;
            ssptxd <= 1'b0;
        end else if (rise) begin
            if (shifting) begin
                ssptxd <= shreg[7];
                shreg  <= {shreg[6:0], 1'b0};
                bitcnt <= loaded ? 3'd0 : bitcnt + 3'd1;
                active <= 1'b1;
            end else begin
                ssptxd <= 1'b0;
                active <= 1'b0;
            end

            loaded <= fifo_rd;
            if (fifo_rd) shreg <= fifo_data;
        end
    end

    always @(posedge pclk or negedge clear_b) begin
        if (!clear_b) sspoe_b <= 1'b1;
        else if (fall) sspoe_b <= ~(loaded | active);
    end

endmodule
