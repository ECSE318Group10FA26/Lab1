// Runs both tests from ssptest.v and checks what gets sent and read

`timescale 1ns / 1ps

// collects the words sent on the serial lines
module ssp_monitor (
    input wire sspclkout,
    input wire sspfssout,
    input wire ssptxd,
    input wire sspoe_b
);
    logic [7:0] sent[$];
    logic [7:0] word;
    int         nbits = -1;  // -1 = idle
    int         errors = 0;

    always @(posedge sspclkout) begin
        #1;
        if (nbits >= 0) begin
            if (sspoe_b !== 1'b0) begin
                errors++;
                $display("FAIL %m @%0t: SSPOE_B high during data", $time);
            end
            word = {word[6:0], ssptxd};
            nbits++;
            if (nbits == 8) begin
                sent.push_back(word);
                nbits = sspfssout ? 0 : -1;
            end
        end else if (sspfssout === 1'b1) begin
            nbits = 0;
        end
    end

endmodule

module ssp_tb;

    ssp_test1 test1 ();
    ssp_test2 test2 ();

    ssp_monitor mon1 (
        .sspclkout(test1.sspclkout),
        .sspfssout(test1.sspfssout),
        .ssptxd   (test1.ssptxd),
        .sspoe_b  (test1.sspoe_b)
    );

    ssp_monitor mon2 (
        .sspclkout(test2.clk_wire),
        .sspfssout(test2.fss_wire),
        .ssptxd   (test2.tx_to_rx),
        .sspoe_b  (test2.oe_b)
    );

    // F3 and B6 are written while the TxFIFO is full, so they're dropped
    // read at 1300 finds the RxFIFO empty, so PRDATA holds 94
    localparam logic [7:0] EXP_SENT[6] = '{8'h94, 8'h0F, 8'h51, 8'h24, 8'h67, 8'h84};
    localparam logic [7:0] EXP_READ[3] = '{8'h94, 8'h94, 8'h0F};

    logic [7:0] reads[$];
    logic       tx_full_seen = 1'b0;
    logic       rx_full_seen = 1'b0;

    always @(posedge test2.clock) begin
        if (test2.clear_b === 1'b1 && test2.psel === 1'b1 && test2.pwrite === 1'b0)
            #1 reads.push_back(test2.data_out);
    end

    always @(posedge test2.ssptxintr) tx_full_seen = 1'b1;
    always @(posedge test2.ssprxintr) rx_full_seen = 1'b1;

    initial begin
        $dumpfile("sim/ssp_tb.vcd");
        $dumpvars;
    end

    final begin
        int errors;
        errors = mon1.errors + mon2.errors;

        $display("test1 sent: %p", mon1.sent);
        $display("test2 sent: %p", mon2.sent);
        $display("test2 read: %p", reads);

        if (mon2.sent != EXP_SENT) begin
            errors++;
            $display("FAIL test2: sent %p, expected %p", mon2.sent, EXP_SENT);
        end
        if (reads != EXP_READ) begin
            errors++;
            $display("FAIL test2: read %p, expected %p", reads, EXP_READ);
        end
        if (!tx_full_seen || !rx_full_seen) begin
            errors++;
            $display("FAIL test2: a FIFO full flag never went high");
        end
        if (mon1.sent.size() < 5) begin
            errors++;
            $display("FAIL test1: only %0d words sent", mon1.sent.size());
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d checks FAILED", errors);
    end

endmodule
