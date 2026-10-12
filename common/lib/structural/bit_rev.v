// bit_rev.v - bit reversal wiring cell
//
//   y[i] = a[N-1-i]
//
// pure wiring (one buf1 per bit, 0 delay); shift_unit uses it to run
// left ops through the right barrel: sll = rev(srl(rev(a)))
//
// Depends: buf1

module bit_rev #(
    // width of the word, in bits
    parameter int N = 1
) (
    input  wire [N-1:0] a,
    output wire [N-1:0] y
);
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : g_rev
            buf1 #(1) r (
                .a(a[i]),
                .y(y[N-1-i])
            );
        end
    endgenerate
endmodule
