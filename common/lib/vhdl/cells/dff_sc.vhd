library ieee;
use ieee.std_logic_1164.all;

-- N-bit D flip-flop / register with synchronous clear
--
-- N = 1 (the default) is a single flip-flop, N > 1 a parallel register.
--
-- VHDL port of common/lib/structural/dff_sc.v (same ports; the Verilog D
-- clock-to-q parameter is named DELAY here - VHDL is case-insensitive, so
-- D would collide with the d port). Compiled into logical library "cells".
entity dff_sc is
    generic (
        N : positive := 1; -- register width in bits
        DELAY : time     := 0 ns -- clock-to-q delay
    );
    port (
        clk   : in  std_logic;
        clear : in  std_logic; -- synchronous clear
        d     : in  std_logic_vector(N - 1 downto 0);
        q     : out std_logic_vector(N - 1 downto 0)
    );
end entity dff_sc;

architecture rtl of dff_sc is
begin
    process (clk) is
    begin
        if rising_edge(clk) then
            if clear = '1' then
                q <= (others => '0') after DELAY;
            else
                q <= d after DELAY;
            end if;
        end if;
    end process;
end architecture rtl;
