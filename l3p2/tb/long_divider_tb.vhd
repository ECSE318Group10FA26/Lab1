library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

-- Runs the lab cases, then every 4-bit division
entity long_divider_tb is
end entity long_divider_tb;

architecture tb of long_divider_tb is
    constant N : positive := 4;

    signal clk       : std_logic := '0';
    signal clear     : std_logic := '1';
    signal start     : std_logic := '0';
    signal dividend  : std_logic_vector(N - 1 downto 0) := (others => '0');
    signal divisor   : std_logic_vector(N - 1 downto 0) := (others => '0');
    signal quotient  : std_logic_vector(N - 1 downto 0);
    signal remainder : std_logic_vector(N - 1 downto 0);
    signal done      : std_logic;
begin

    clk <= not clk after 5 ns;

    dut : entity work.long_divider
        generic map (N => N)
        port map (
            clk       => clk,
            clear     => clear,
            start     => start,
            dividend  => dividend,
            divisor   => divisor,
            quotient  => quotient,
            remainder => remainder,
            done      => done
        );

    stimulus : process is
        variable errors : natural := 0;

        procedure run(dvd, dvr : natural; show : boolean) is
            variable q, r   : natural;
            variable clocks : natural := 1;
        begin
            wait until falling_edge(clk);
            dividend <= std_logic_vector(to_unsigned(dvd, N));
            divisor  <= std_logic_vector(to_unsigned(dvr, N));
            start    <= '1';
            wait until falling_edge(clk);
            start <= '0';
            while done /= '1' and clocks < 20 loop
                wait until falling_edge(clk);
                clocks := clocks + 1;
            end loop;

            q := to_integer(unsigned(quotient));
            r := to_integer(unsigned(remainder));
            if q /= dvd / dvr or r /= dvd mod dvr or clocks /= N + 2 then
                errors := errors + 1;
                report "FAIL: " & integer'image(dvd) & " / " & integer'image(dvr)
                    & " gave " & integer'image(q) & " r " & integer'image(r)
                    & " in " & integer'image(clocks) & " clocks" severity error;
            elsif show then
                report integer'image(dvd) & " / " & integer'image(dvr) & " = "
                    & integer'image(q) & " r " & integer'image(r)
                    & " (" & integer'image(clocks) & " clocks)";
            end if;
        end procedure run;

    begin
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        clear <= '0';

        run(7, 2, true);
        run(6, 2, true);
        run(9, 4, true);
        run(12, 5, true);

        for dvr in 1 to 2**N - 1 loop
            for dvd in 0 to 2**N - 1 loop
                run(dvd, dvr, false);
            end loop;
        end loop;

        if errors = 0 then
            report "ALL TESTS PASSED";
        else
            report integer'image(errors) & " divisions FAILED" severity error;
        end if;
        stop;
        wait;
    end process stimulus;

end architecture tb;
