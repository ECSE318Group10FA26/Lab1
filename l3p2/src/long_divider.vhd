library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library util;
use util.util_pkg.all;
library cells;
library arith;

-- Non-restoring unsigned divider (Fig 2.3). Takes N + 2 clocks:
--   1 load, N add/sub steps, 1 correction step.
-- N must be a power of two.
entity long_divider is
    generic (N : positive := 4);
    port (
        clk       : in  std_logic;
        clear     : in  std_logic;
        start     : in  std_logic;
        dividend  : in  std_logic_vector(N - 1 downto 0);
        divisor   : in  std_logic_vector(N - 1 downto 0);
        quotient  : out std_logic_vector(N - 1 downto 0);
        remainder : out std_logic_vector(N - 1 downto 0);
        done      : out std_logic
    );
end entity long_divider;

architecture structural of long_divider is

    constant CW : positive := maximum(1, clog2(N));

    type state_t is (S_IDLE, S_ITER, S_CORR);
    signal state  : state_t;
    signal cnt    : unsigned(CW - 1 downto 0);
    signal done_q : std_logic;

    signal load, iter, corr : std_logic;

    signal M, M_next : std_logic_vector(N - 1 downto 0);
    signal D, D_next : std_logic_vector(N - 1 downto 0);
    signal R, R_next : std_logic_vector(N downto 0); -- extra sign bit
    signal r_clear   : std_logic;

    signal r_pos : std_logic;
    signal pr    : std_logic_vector(N downto 0);
    signal y     : std_logic_vector(N downto 0);
    signal r_en  : std_logic;

begin

    assert is_pow2(N)
        report "long_divider: N must be a power of two"
        severity failure;

    -- Control
    load <= '1' when state = S_IDLE and start = '1' else '0';
    iter <= '1' when state = S_ITER else '0';
    corr <= '1' when state = S_CORR else '0';

    control : process (clk) is
    begin
        if rising_edge(clk) then
            if clear = '1' then
                state  <= S_IDLE;
                cnt    <= (others => '0');
                done_q <= '0';
            else
                case state is
                    when S_IDLE =>
                        if start = '1' then
                            state  <= S_ITER;
                            cnt    <= to_unsigned(N - 1, CW);
                            done_q <= '0';
                        end if;

                    when S_ITER =>
                        if cnt = 0 then
                            state <= S_CORR;
                        else
                            cnt <= cnt - 1;
                        end if;

                    when S_CORR =>
                        state  <= S_IDLE;
                        done_q <= '1';
                end case;
            end if;
        end if;
    end process control;

    done <= done_q;

    -- Add/Sub: subtract when R >= 0, add when R < 0.
    -- The shift of {R, D} is done by wiring the shifted value into the adder.
    r_pos <= not R(N);

    pr <= R when corr = '1' else R(N - 1 downto 0) & D(N - 1);

    alu : entity arith.add_sub
        generic map (N => N)
        port map (
            a   => pr,
            b   => M,
            sub => r_pos,
            y   => y
        );

    -- M register
    M_next <= divisor when load = '1' else M;

    reg_m : entity cells.dff_sc
        generic map (N => N)
        port map (clk => clk, clear => clear, d => M_next, q => M);

    -- R register: the correction step only keeps R + M when R < 0
    r_clear <= clear or load;
    r_en    <= iter or (corr and R(N));
    R_next  <= y when r_en = '1' else R;

    reg_r : entity cells.dff_sc
        generic map (N => N + 1)
        port map (clk => clk, clear => r_clear, d => R_next, q => R);

    -- D register: shifts in the previous step's quotient bit.
    -- The first bit shifted in is a placeholder, pushed out by the correction step.
    D_next <= dividend                  when load = '1' else
              D(N - 2 downto 0) & r_pos when (iter or corr) = '1' else
              D;

    reg_d : entity cells.dff_sc
        generic map (N => N)
        port map (clk => clk, clear => clear, d => D_next, q => D);

    quotient  <= D;
    remainder <= R(N - 1 downto 0);

end architecture structural;
