library ieee;
use ieee.std_logic_1164.all;

-- N-bit conditional-sum block: computes a + b twice, once assuming a
-- block carry-in of 0 and once assuming 1.
--
-- N must be a power of two.
entity conditional_sum_block is
    generic (N : positive);
    port (
        a  : in  std_logic_vector(N - 1 downto 0);
        b  : in  std_logic_vector(N - 1 downto 0);
        s0 : out std_logic_vector(N - 1 downto 0); -- sum, carry-in = 0
        c0 : out std_logic;                        -- carry-out, carry-in = 0
        s1 : out std_logic_vector(N - 1 downto 0); -- sum, carry-in = 1
        c1 : out std_logic                         -- carry-out, carry-in = 1
    );
end entity conditional_sum_block;

architecture recursive of conditional_sum_block is
begin

    -- base case: N=1
    gen_bit : if N = 1 generate
        s0(0) <= a(0) xor b(0);
        c0    <= a(0) and b(0);
        s1(0) <= a(0) xnor b(0);
        c1    <= a(0) or b(0);
    end generate gen_bit;

    -- recursive case: two half-width blocks; the lower block's
    -- hypothetical carry-outs select between the upper block's hypotheses
    gen_split : if N > 1 generate
        signal lo_s0, lo_s1 : std_logic_vector(N / 2 - 1 downto 0);
        signal hi_s0, hi_s1 : std_logic_vector(N / 2 - 1 downto 0);
        signal lo_c0, lo_c1 : std_logic;
        signal hi_c0, hi_c1 : std_logic;
    begin
        lo : entity work.conditional_sum_block
            generic map (N => N / 2)
            port map (
                a  => a(N / 2 - 1 downto 0),
                b  => b(N / 2 - 1 downto 0),
                s0 => lo_s0,
                c0 => lo_c0,
                s1 => lo_s1,
                c1 => lo_c1
            );

        hi : entity work.conditional_sum_block
            generic map (N => N / 2)
            port map (
                a  => a(N - 1 downto N / 2),
                b  => b(N - 1 downto N / 2),
                s0 => hi_s0,
                c0 => hi_c0,
                s1 => hi_s1,
                c1 => hi_c1
            );

        s0(N - 1 downto N / 2) <= hi_s1 when lo_c0 = '1' else hi_s0;
        s0(N / 2 - 1 downto 0) <= lo_s0;
        c0                     <= hi_c1 when lo_c0 = '1' else hi_c0;
        s1(N - 1 downto N / 2) <= hi_s1 when lo_c1 = '1' else hi_s0;
        s1(N / 2 - 1 downto 0) <= lo_s1;
        c1                     <= hi_c1 when lo_c1 = '1' else hi_c0;
    end generate gen_split;

end architecture recursive;
