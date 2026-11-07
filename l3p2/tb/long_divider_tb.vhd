library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;
use std.env.all;

-- Checks one long_divider instance against / and mod, and its N + 2 clock
-- latency. CASES is a list of (dividend, divisor) pairs.
entity long_divider_check is
    generic (
        N          : positive       := 4;
        CASES      : integer_vector := (0, 1);
        SHOW       : boolean        := false;
        EXHAUSTIVE : boolean        := false;
        N_RANDOM   : natural        := 0
    );
    port (
        clk      : in  std_logic;
        fin      : out std_logic := '0';
        n_errors : out natural   := 0
    );
end entity long_divider_check;

architecture tb of long_divider_check is
    constant LATENCY : positive := N + 2;

    signal clear     : std_logic := '1';
    signal start     : std_logic := '0';
    signal dividend  : std_logic_vector(N - 1 downto 0) := (others => '0');
    signal divisor   : std_logic_vector(N - 1 downto 0) := (others => '0');
    signal quotient  : std_logic_vector(N - 1 downto 0);
    signal remainder : std_logic_vector(N - 1 downto 0);
    signal done      : std_logic;
begin

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
        variable tests, errors : natural := 0;
        variable seed1         : positive := 318;
        variable seed2         : positive := N;
        variable rnd           : real;
        variable rdvd, rdvr    : natural;

        procedure run(dvd, dvr : natural; verbose : boolean) is
            variable exp_q, exp_r : natural;
            variable got_q, got_r : natural;
            variable clocks       : natural := 0;
        begin
            exp_q := dvd / dvr;
            exp_r := dvd mod dvr;

            -- drive inputs on the falling edge
            wait until falling_edge(clk);
            dividend <= std_logic_vector(to_unsigned(dvd, N));
            divisor  <= std_logic_vector(to_unsigned(dvr, N));
            start    <= '1';
            wait until falling_edge(clk);
            start    <= '0';
            clocks   := 1;
            while done /= '1' and clocks < 4 * LATENCY loop
                wait until falling_edge(clk);
                clocks := clocks + 1;
            end loop;

            tests := tests + 1;
            got_q := to_integer(unsigned(quotient));
            got_r := to_integer(unsigned(remainder));

            if done /= '1' then
                errors := errors + 1;
                report "FAIL N=" & integer'image(N) & ": " & integer'image(dvd)
                    & " / " & integer'image(dvr) & " never finished"
                    severity error;
            elsif got_q /= exp_q or got_r /= exp_r or clocks /= LATENCY then
                errors := errors + 1;
                report "FAIL N=" & integer'image(N) & ": " & integer'image(dvd)
                    & " / " & integer'image(dvr) & " = " & integer'image(got_q)
                    & " r " & integer'image(got_r) & " in " & integer'image(clocks)
                    & " clocks (expected " & integer'image(exp_q) & " r "
                    & integer'image(exp_r) & " in " & integer'image(LATENCY) & ")"
                    severity error;
            elsif verbose then
                report "PASS N=" & integer'image(N) & ": " & integer'image(dvd)
                    & " / " & integer'image(dvr) & " = " & integer'image(got_q)
                    & " remainder " & integer'image(got_r)
                    & "  (quotient " & to_string(quotient) & ", remainder "
                    & to_string(remainder) & ", " & integer'image(clocks) & " clocks)"
                    severity note;
            end if;
        end procedure run;

    begin
        wait until falling_edge(clk);
        wait until falling_edge(clk);
        clear <= '0';

        for i in 0 to CASES'length / 2 - 1 loop
            run(CASES(CASES'low + 2 * i), CASES(CASES'low + 2 * i + 1), SHOW);
        end loop;

        if EXHAUSTIVE then
            for dvr in 1 to 2**N - 1 loop
                for dvd in 0 to 2**N - 1 loop
                    run(dvd, dvr, false);
                end loop;
            end loop;
        end if;

        for i in 1 to N_RANDOM loop
            uniform(seed1, seed2, rnd);
            rdvd := integer(floor(rnd * real(2**N)));
            uniform(seed1, seed2, rnd);
            rdvr := 1 + integer(floor(rnd * real(2**N - 1)));
            run(rdvd, rdvr, false);
        end loop;

        if errors = 0 then
            report "N=" & integer'image(N) & ": all " & integer'image(tests)
                & " divisions passed" severity note;
        else
            report "N=" & integer'image(N) & ": " & integer'image(errors) & " of "
                & integer'image(tests) & " divisions FAILED" severity error;
        end if;

        n_errors <= errors;
        fin      <= '1';
        wait;
    end process stimulus;

end architecture tb;

-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use std.env.all;

-- 4-bit: lab cases, Fig 2.2 example, then every division.
-- 8-bit: edge cases and random divisions.
entity long_divider_tb is
end entity long_divider_tb;

architecture tb of long_divider_tb is
    signal clk        : std_logic := '0';
    signal fin4, fin8 : std_logic;
    signal err4, err8 : natural;
begin

    clk <= not clk after 5 ns;

    c_4 : entity work.long_divider_check
        generic map (
            N          => 4,
            CASES      => (7, 2, 6, 2, 9, 4, 12, 5),
            SHOW       => true,
            EXHAUSTIVE => true
        )
        port map (clk => clk, fin => fin4, n_errors => err4);

    c_8 : entity work.long_divider_check
        generic map (
            N        => 8,
            CASES    => (0, 7, 255, 1, 255, 255, 254, 255, 255, 128, 128, 3,
                         200, 7, 1, 200, 100, 10),
            N_RANDOM => 300
        )
        port map (clk => clk, fin => fin8, n_errors => err8);

    finish : process is
    begin
        wait until fin4 = '1' and fin8 = '1';
        if err4 + err8 = 0 then
            report "ALL TESTS PASSED" severity note;
        else
            report integer'image(err4 + err8) & " divisions FAILED" severity error;
        end if;
        stop;
        wait;
    end process finish;

end architecture tb;
