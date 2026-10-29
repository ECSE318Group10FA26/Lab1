library ieee;
use ieee.std_logic_1164.all;

-- CAS: controlled adder/subtractor
--   b' = b ^ op ;  {cout, s} = a + b' + cin
-- op = '1' subtracts (two's complement: b inverted)
--
-- VHDL port of common/lib/structural/cas.v (same ports; the Verilog D
-- gate-delay parameter is named DELAY here - VHDL is case-insensitive, so
-- D would collide with any d port). Compiled into logical library "cells".
entity cas is
    generic (
        DELAY : time := 0 ns -- gate delay
    );
    port (
        a    : in  std_logic; -- partial-remainder bit from the row above
        b    : in  std_logic; -- divisor bit (tied to '0' in the sign-extension cell)
        cin  : in  std_logic; -- carry in, from the cell to the right
        op   : in  std_logic; -- row operation: '1' = subtract, '0' = add
        s    : out std_logic; -- sum bit, down to the next row
        cout : out std_logic  -- carry out, to the cell on the left
    );
end entity cas;

architecture structural of cas is
    signal bx : std_logic; -- b ^ op
begin
    bx <= b xor op after DELAY;

    fa : entity work.full_adder
        generic map (DELAY => DELAY)
        port map (
            a    => a,
            b    => bx,
            cin  => cin,
            sum  => s,
            cout => cout
        );
end architecture structural;
