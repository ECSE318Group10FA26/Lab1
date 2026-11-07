// testbench for the freecell player.
// This simple testbench presents one move to the freecell player at each
// clock cycle. The task "doMove" allows the user to specify the moves in
// standard notation.
//
// Each move consists of two characters: the first designates the source;
// the second designates the destination.
//

module testFreeCell;
    reg [3:0] source;
    reg [3:0] dest;
    reg	      clock;
    wire      win;

    // Convert the character notation into bit-level codes.
    function [3:0] encode;
	input [7:0] selector;
    begin: dec
	case (selector)
	  "1": encode = 4'd0;	// column 1 of the tableau
	  "2": encode = 4'd1;	// column 2 of the tableau
	  "3": encode = 4'd2;	// column 3 of the tableau
	  "4": encode = 4'd3;	// column 4 of the tableau
	  "5": encode = 4'd4;	// column 5 of the tableau
	  "6": encode = 4'd5;	// column 6 of the tableau
	  "7": encode = 4'd6;	// column 7 of the tableau
	  "8": encode = 4'd7;	// column 8 of the tableau
	  "a": encode = 4'd8;	// free cell a
	  "b": encode = 4'd9;	// free cell b
	  "c": encode = 4'd10;	// free cell c
	  "d": encode = 4'd11;	// free cell d
	  "h": encode = 4'd12;	// home cells: the two LSBs are arbitrary
	  default: encode = 4'bx;
	endcase // case (selector)
    end // block: dec
    endfunction // encode

    // Present one move to the circuit and wait one clock cycle.
    task doMove;
	input [15:0] move;
    begin: doTheMove
	source = encode(move[15:8]);
	dest   = encode(move[7:0]);
	#10;
    end // block: doTheMove
    endtask // doMove

    // Play the game. Several illegal moves are interspersed with the
    // legal ones.
    initial begin
	$monitor("%d  %b %b %b",$time, source, dest, win);
	clock = 0;
	doMove("1h");	// 1
	doMove("1h");	// 2
	doMove("2h");	// 3
	doMove("3h");	// 4
	doMove("4a");	// 5
	doMove("47");	// 6
	doMove("a7");	// 7
	doMove("85");	// 8
	doMove("45");	// 9
	doMove("4a");	// 10
	doMove("42");	// 11
	doMove("4h");	// 12
	doMove("6h");	// 13
	doMove("4b");	// 14
	doMove("2c");	// 15
	doMove("24");	// 16
	doMove("c4");	// 17
	doMove("a2");	// 18
	doMove("b2");	// 19
	doMove("6h");	// 20
	doMove("87");	// 21
	doMove("86");	// 22
	doMove("8a");	// 23
	doMove("2h");	// 24
	doMove("82");	// 25
	doMove("a8");	// 26
	doMove("5a");	// 27
	doMove("5b");	// 28
	doMove("58");	// 29
	doMove("1h");	// 30
	doMove("5h");	// 31
	doMove("b8");	// 32
	doMove("a8");	// 33
	doMove("18");	// 34
	doMove("12");	// illegal
	doMove("2a");	// 35
	doMove("28");	// 36
	doMove("a8");	// 37
	doMove("1a");	// 38
	doMove("14");	// 39
	doMove("1h");	// 40
	doMove("3b");	// 41
	doMove("3h");	// 42
	doMove("37");	// 43
	doMove("a1");	// 44
	doMove("h4");	// illegal
	doMove("31");	// 45
	doMove("3a");	// 46
	doMove("1c");	// 47
	doMove("13");	// 48
	doMove("c3");	// 49
	doMove("2c");	// 50
	doMove("8c");	// illegal
	doMove("2d");	// 51
	doMove("23");	// 52
	doMove("24");	// 53
	doMove("a3");	// 54
	doMove("c3");	// 55
	doMove("c2");	// illegal
	doMove("2h");	// 56
	doMove("6a");	// 57
	doMove("64");	// 58
	doMove("6h");	// 59
	doMove("a4");	// 60
	doMove("dh");	// 61
	doMove("5h");	// 62
	doMove("ah");	// illegal
	doMove("62");	// 63
	doMove("52");	// 64
	doMove("52");	// 65
	doMove("71");	// 66
	doMove("74");	// 67
	doMove("14");	// 68
	doMove("64");	// 69
	doMove("b6");	// 70
	doMove("56");	// 71
	doMove("7a");	// 72
	doMove("7b");	// 73
	doMove("72");	// 74
	doMove("b2");	// 75
	doMove("a2");	// 76
	doMove("75");	// 77
	doMove("72");	// 78
	doMove("75");	// 79
	doMove("7h");	// 80
	doMove("7h");	// 81
	doMove("8h");	// 82
	doMove("8h");	// 83
	doMove("4h");	// 84
	doMove("4h");	// 85
	doMove("3h");	// 86
	doMove("4h");	// 87
	doMove("8h");	// 88
	doMove("2h");	// 89
	doMove("3h");	// 90
	doMove("4h");	// 91
	doMove("3h");	// 92
	doMove("3h");	// 93
	doMove("8h");	// 94
	doMove("2h");	// 95
	doMove("8h");	// 96
	doMove("4h");	// 97
	doMove("2h");	// 98
	doMove("8h");	// 99
	doMove("2h");	// 100
	doMove("3h");	// 101
	doMove("4h");	// 102
	doMove("8h");	// 103
	doMove("2h");	// 104
	doMove("3h");	// 105
	doMove("4h");	// 106
	doMove("8h");	// 107
	doMove("2h");	// 108
	doMove("4h");	// 109
	doMove("8h");	// illegal
	doMove("5h");	// 110
	doMove("6h");	// 111
	doMove("2h");	// 112
	doMove("4h");	// 113
	doMove("5h");	// 114
	doMove("6h");	// 115
	$finish;
    end // initial begin

    // Clock generator.
    always
	#5 clock = ~clock;

    freecellPlayer fc(clock,source,dest,win);

endmodule // testFreeCell
