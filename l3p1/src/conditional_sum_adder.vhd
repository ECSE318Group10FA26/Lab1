library ieee;
use ieee.std_logic_1164.all;

library util;
use util.util_pkg.all;

-- N-bit conditional sum adder. N must be a power of two.
entity conditional_sum_adder is
    generic (N : positive := 8);
    port (
        a    : in  std_logic_vector(N - 1 downto 0);
        b    : in  std_logic_vector(N - 1 downto 0);
        cin  : in  std_logic;
        sum  : out std_logic_vector(N - 1 downto 0);
        cout : out std_logic
    );
end entity conditional_sum_adder;

architecture structural of conditional_sum_adder is

    signal s0, s1 : std_logic_vector(N - 1 downto 0);
    signal c0, c1 : std_logic;

begin

    assert is_pow2(N)
        report "conditional_sum_adder: N must be a power of two"
        severity failure;

    core : entity work.conditional_sum_block
        generic map (N => N)
        port map (
            a  => a,
            b  => b,
            s0 => s0,
            c0 => c0,
            s1 => s1,
            c1 => c1
        );

    -- select the hypothesis matching the actual carry-in
    sum  <= s1 when cin = '1' else s0;
    cout <= c1 when cin = '1' else c0;

end architecture structural;
