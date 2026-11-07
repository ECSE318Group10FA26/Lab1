// Synchronous FIFO; writes while full and reads while empty are ignored

module ssp_fifo #(
    parameter int W     = 8,
    parameter int DEPTH = 4
) (
    input  wire         clk,
    input  wire         clear_b,
    input  wire         wr,
    input  wire [W-1:0] din,
    input  wire         rd,
    output wire [W-1:0] dout,
    output wire         full,
    output wire         empty
);
    localparam int AW = $clog2(DEPTH);

    reg [W-1:0] mem[DEPTH];
    reg [AW-1:0] rd_ptr, wr_ptr;
    reg [AW:0] count;

    wire do_wr = wr & ~full;
    wire do_rd = rd & ~empty;

    assign full  = count[AW];  // count == DEPTH (DEPTH is a power of two)
    assign empty = (count == '0);
    assign dout  = mem[rd_ptr];

    always @(posedge clk) begin
        if (do_wr) mem[wr_ptr] <= din;
    end

    always @(posedge clk or negedge clear_b) begin
        if (!clear_b) begin
            rd_ptr <= '0;
            wr_ptr <= '0;
            count  <= '0;
        end else begin
            if (do_wr) wr_ptr <= wr_ptr + 1'b1;
            if (do_rd) rd_ptr <= rd_ptr + 1'b1;
            case ({
                do_wr, do_rd
            })
                2'b10:   count <= count + 1'b1;
                2'b01:   count <= count - 1'b1;
                default: count <= count;
            endcase
        end
    end

endmodule
