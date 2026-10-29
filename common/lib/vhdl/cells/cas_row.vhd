library ieee;
use ieee.std_logic_1164.all;

-- cas_row: one row of a divider array
--
-- an (N+1)-bit ripple-carry CAS with 1-bit op
--   {q, sum} = pr +/- divisor   (op = '1' subtracts, '0' adds)
--
-- The rightmost carry-in is the op itself (for two's complement).
-- The leftmost cell is a sign-extension cell (b = '0'); its carry-out is q,
-- the quotient bit ('1' = result non-negative).
--
-- VHDL port of common/lib/structural/cas_row.v (same ports; the Verilog D
-- gate-delay parameter is named DELAY here - VHDL is case-insensitive, so
-- D would collide with any d port). Compiled into logical library "cells".
entity cas_row is
    generic (
        N : positive := 4; -- operand width in bits (the row is N+1 cells wide)
        DELAY : time     := 0 ns -- gate delay
    );
    port (
        pr      : in  std_logic_vector(N downto 0);     -- partial remainder in (bit N = sign)
        divisor : in  std_logic_vector(N - 1 downto 0); -- divisor bits (sign cell gets b = '0')
        op      : in  std_logic;                        -- row operation: '1' = subtract, '0' = add
        sum     : out std_logic_vector(N - 1 downto 0); -- row result, low N bits
        q       : out std_logic                         -- quotient bit: carry-out of the sign cell
    );
end entity cas_row;

architecture structural of cas_row is
    signal c : std_logic_vector(N downto 0); -- carry chain, rippling right to left; c(0) = op
begin
    c(0) <= op;

    g_cas : for i in 0 to N - 1 generate
        u_cas : entity work.cas
            generic map (DELAY => DELAY)
            port map (
                a    => pr(i),
                b    => divisor(i),
                cin  => c(i),
                op   => op,
                s    => sum(i),
                cout => c(i + 1)
            );
    end generate g_cas;

    -- sign-extension cell (b = '0'); its carry-out is the row's quotient
    -- bit, its sum bit is intentionally left open
    u_sign : entity work.cas
        generic map (DELAY => DELAY)
        port map (
            a    => pr(N),
            b    => '0',
            cin  => c(N),
            op   => op,
            s    => open,
            cout => q
        );
end architecture structural;
