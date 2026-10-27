library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library util;
use util.util_pkg.all;
library util_tb;
use util_tb.tb_pkg.all;

-- Self-checking testbench: exhaustively adds every (a, b, cin) combination
-- and compares {cout, sum} against numeric_std.
entity conditional_sum_adder_tb is
end entity conditional_sum_adder_tb;

architecture tb of conditional_sum_adder_tb is
    constant N : positive := 8;

    signal a, b : std_logic_vector(N - 1 downto 0) := (others => '0');
    signal cin  : std_logic := '0';
    signal sum  : std_logic_vector(N - 1 downto 0);
    signal cout : std_logic;
begin

    dut : entity work.conditional_sum_adder
        generic map (N => N)
        port map (
            a    => a,
            b    => b,
            cin  => cin,
            sum  => sum,
            cout => cout
        );

    stimulus : process is
        variable expected : unsigned(N downto 0);
        variable n_errors : natural := 0;
    begin
        -- directed smoke checks via util_tb helpers
        a   <= x"ff";
        b   <= x"01";
        cin <= '1';
        wait for 1 ns;
        check_eq(cout & sum, std_logic_vector(to_unsigned(2**N + 1, N + 1)), "255 + 1 + 1 wraps");

        -- exhaustive check of every (a, b, cin) combination
        for ci in 0 to 1 loop
            cin <= to_sl(ci = 1);

            for ai in 0 to 2**N - 1 loop
                a <= std_logic_vector(to_unsigned(ai, N));
                for bi in 0 to 2**N - 1 loop
                    b <= std_logic_vector(to_unsigned(bi, N));
                    wait for 1 ns; -- let the combinational logic settle

                    expected := to_unsigned(ai, N + 1) + to_unsigned(bi, N + 1) + ci;
                    if unsigned(cout & sum) /= expected then
                        n_errors := n_errors + 1;
                        report "FAIL: " & integer'image(ai) & " + " & integer'image(bi)
                            & " + " & integer'image(ci) & " = "
                            & integer'image(to_nat(cout & sum))
                            & " (expected " & integer'image(to_integer(expected)) & ")"
                            severity error;
                    end if;
                end loop;
            end loop;
        end loop;

        report "vectors tested: " & integer'image(2 * 2**(2 * N)) severity note;
        if n_errors = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report integer'image(n_errors) & " vectors FAILED" severity error;
        end if;

        stop;
        wait;
    end process stimulus;

end architecture tb;
