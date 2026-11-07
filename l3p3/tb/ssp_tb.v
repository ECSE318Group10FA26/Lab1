// Runs both tests from ssptest.v with checkers

`timescale 1ns / 1ps

module ssp_check #(
    parameter string NAME = "ssp"
) (
    input wire       pclk,
    input wire       clear_b,
    input wire       psel,
    input wire       pwrite,
    input wire [7:0] pwdata,
    input wire       sspclkout,
    input wire       sspfssout,
    input wire       ssptxd,
    input wire       sspoe_b,
    input wire       ssptxintr
);
    logic [7:0] accepted[$];
    logic [7:0] sent    [$];
    int         errors = 0;

    logic       started = 1'b0;
    logic       clk_prev;
    logic       in_frame;
    logic       fss_prev;
    int         idle_run;
    int         nbits;
    logic [7:0] word;
    logic [7:0] expected;

    task automatic fail(input string msg);
        errors++;
        $display("FAIL %s @%0t: %s", NAME, $time, msg);
    endtask

    always @(posedge pclk) begin
        if (clear_b === 1'b1 && psel === 1'b1 && pwrite === 1'b1 && ssptxintr === 1'b0)
            accepted.push_back(pwdata);
    end

    always @(posedge pclk) begin
        if (clear_b !== 1'b1) begin
            started  = 1'b0;
            in_frame = 1'b0;
            fss_prev = 1'b0;
            idle_run = 0;
            nbits    = 0;
        end else begin
            if (started && sspclkout === clk_prev) fail("SSPCLKOUT is not PCLK / 2");
            started  = 1'b1;
            clk_prev = sspclkout;

            if (sspclkout === 1'b1) begin
                if (fss_prev && sspfssout === 1'b1) fail("SSPFSSOUT longer than one period");

                if (in_frame) begin
                    idle_run = 0;
                    if (sspoe_b !== 1'b0) fail("SSPOE_B high during data");
                    word = {word[6:0], ssptxd};
                    nbits++;
                    if (nbits == 8) begin
                        sent.push_back(word);
                        if (accepted.size() == 0) begin
                            fail($sformatf("sent %h, but no word was written", word));
                        end else begin
                            expected = accepted.pop_front();
                            if (word !== expected)
                                fail($sformatf("sent %h, expected %h", word, expected));
                        end
                        nbits    = 0;
                        in_frame = (sspfssout === 1'b1);
                    end
                end else if (sspfssout === 1'b1) begin
                    idle_run = 0;
                    in_frame = 1'b1;
                    nbits    = 0;
                end else begin
                    // SSPOE_B rises half a period after the LSB
                    idle_run++;
                    if (idle_run >= 2 && sspoe_b !== 1'b1) fail("SSPOE_B low while idle");
                end

                fss_prev = (sspfssout === 1'b1);
            end
        end
    end

endmodule

module ssp_tb;

    ssp_test1 test1 ();
    ssp_test2 test2 ();

    ssp_check #(
        .NAME("test1")
    ) chk1 (
        .pclk     (test1.clock),
        .clear_b  (test1.clear_b),
        .psel     (test1.psel),
        .pwrite   (test1.pwrite),
        .pwdata   (test1.data_in),
        .sspclkout(test1.sspclkout),
        .sspfssout(test1.sspfssout),
        .ssptxd   (test1.ssptxd),
        .sspoe_b  (test1.sspoe_b),
        .ssptxintr(test1.ssptxintr)
    );

    ssp_check #(
        .NAME("test2")
    ) chk2 (
        .pclk     (test2.clock),
        .clear_b  (test2.clear_b),
        .psel     (test2.psel),
        .pwrite   (test2.pwrite),
        .pwdata   (test2.data_in),
        .sspclkout(test2.clk_wire),
        .sspfssout(test2.fss_wire),
        .ssptxd   (test2.tx_to_rx),
        .sspoe_b  (test2.oe_b),
        .ssptxintr(test2.ssptxintr)
    );

    // read at 1300 finds the RxFIFO empty, so PRDATA holds 94
    localparam logic [7:0] EXP_SENT[6] = '{8'h94, 8'h0F, 8'h51, 8'h24, 8'h67, 8'h84};
    localparam logic [7:0] EXP_READ[3] = '{8'h94, 8'h94, 8'h0F};

    logic [7:0] reads[$];
    logic       tx_full_seen = 1'b0;
    logic       rx_full_seen = 1'b0;

    always @(posedge test2.clock) begin
        if (test2.clear_b === 1'b1 && test2.psel === 1'b1 && test2.pwrite === 1'b0) begin
            #1 reads.push_back(test2.data_out);
        end
    end

    always @(posedge test2.ssptxintr) tx_full_seen = 1'b1;
    always @(posedge test2.ssprxintr) rx_full_seen = 1'b1;

    initial begin
        $dumpfile("sim/ssp_tb.vcd");
        $dumpvars;
    end

    final begin
        int errors;
        errors = chk1.errors + chk2.errors;

        $display("test1 sent: %p", chk1.sent);
        $display("test2 sent: %p", chk2.sent);
        $display("test2 read: %p", reads);

        if (chk2.sent != EXP_SENT) begin
            errors++;
            $display("FAIL test2: sent %p, expected %p", chk2.sent, EXP_SENT);
        end
        if (reads != EXP_READ) begin
            errors++;
            $display("FAIL test2: read %p, expected %p", reads, EXP_READ);
        end
        if (!tx_full_seen) begin
            errors++;
            $display("FAIL test2: SSPTXINTR never went high");
        end
        if (!rx_full_seen) begin
            errors++;
            $display("FAIL test2: SSPRXINTR never went high");
        end
        if (chk1.sent.size() < 5) begin
            errors++;
            $display("FAIL test1: only %0d frames sent", chk1.sent.size());
        end

        if (errors == 0) $display("ALL TESTS PASSED");
        else $display("%0d checks FAILED", errors);
    end

endmodule
