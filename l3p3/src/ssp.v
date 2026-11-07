// Synchronous serial port

module ssp (
    input  wire       PCLK,
    input  wire       CLEAR_B,
    input  wire       PSEL,
    input  wire       PWRITE,
    input  wire [7:0] PWDATA,
    input  wire       SSPCLKIN,
    input  wire       SSPFSSIN,
    input  wire       SSPRXD,
    output reg  [7:0] PRDATA,
    output wire       SSPOE_B,
    output wire       SSPTXD,
    output wire       SSPCLKOUT,
    output wire       SSPFSSOUT,
    output wire       SSPTXINTR,
    output wire       SSPRXINTR
);
    wire       tx_wr = PSEL & PWRITE;
    wire       rx_rd = PSEL & ~PWRITE;

    wire [7:0] tx_data;
    wire       tx_empty;
    wire       tx_rd;

    wire [7:0] rx_data;
    wire       rx_valid;
    wire [7:0] rx_head;
    wire       rx_empty;

    ssp_fifo tx_fifo (
        .clk    (PCLK),
        .clear_b(CLEAR_B),
        .wr     (tx_wr),
        .din    (PWDATA),
        .rd     (tx_rd),
        .dout   (tx_data),
        .full   (SSPTXINTR),
        .empty  (tx_empty)
    );

    ssp_tx tx (
        .pclk      (PCLK),
        .clear_b   (CLEAR_B),
        .fifo_data (tx_data),
        .fifo_empty(tx_empty),
        .fifo_rd   (tx_rd),
        .sspclkout (SSPCLKOUT),
        .sspfssout (SSPFSSOUT),
        .ssptxd    (SSPTXD),
        .sspoe_b   (SSPOE_B)
    );

    ssp_rx rx (
        .pclk    (PCLK),
        .clear_b (CLEAR_B),
        .sspclkin(SSPCLKIN),
        .sspfssin(SSPFSSIN),
        .ssprxd  (SSPRXD),
        .rx_data (rx_data),
        .rx_valid(rx_valid)
    );

    ssp_fifo rx_fifo (
        .clk    (PCLK),
        .clear_b(CLEAR_B),
        .wr     (rx_valid),
        .din    (rx_data),
        .rd     (rx_rd),
        .dout   (rx_head),
        .full   (SSPRXINTR),
        .empty  (rx_empty)
    );

    always @(posedge PCLK or negedge CLEAR_B) begin
        if (!CLEAR_B) PRDATA <= 8'd0;
        else if (rx_rd && !rx_empty) PRDATA <= rx_head;
    end

endmodule
