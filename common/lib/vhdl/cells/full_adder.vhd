library ieee;
use ieee.std_logic_1164.all;

-- one-bit full adder
--
--   sum  = a ^ b ^ cin
--   cout = (a & b) | (cin & (a ^ b))
--
-- VHDL port of common/lib/structural/full_adder.v (same ports; the
-- Verilog D gate-delay parameter is named DELAY here - VHDL is
-- case-insensitive, so D would collide with any d port).
-- Compiled into logical library "cells".
entity full_adder is
    generic (
        DELAY : time := 0 ns -- gate delay
    );
    port (
        a    : in  std_logic;
        b    : in  std_logic;
        cin  : in  std_logic;
        sum  : out std_logic;
        cout : out std_logic
    );
end entity full_adder;

architecture gates of full_adder is
    signal axb : std_logic; -- a ^ b
    signal c1  : std_logic; -- a & b
    signal c2  : std_logic; -- cin & (a ^ b)
begin
    axb  <= a xor b after DELAY;
    sum  <= axb xor cin after DELAY;
    c1   <= a and b after DELAY;
    c2   <= axb and cin after DELAY;
    cout <= c1 or c2 after DELAY;
end architecture gates;
