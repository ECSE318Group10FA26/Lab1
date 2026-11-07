library ieee;
use ieee.std_logic_1164.all;

library util;
use util.util_pkg.all;

-- (N+1)-bit adder/subtractor: y = a + b (sub = '0') or a - b (sub = '1')
-- a is signed, b is unsigned. N must be a power of two.
entity add_sub is
    generic (N : positive := 4);
    port (
        a   : in  std_logic_vector(N downto 0);
        b   : in  std_logic_vector(N - 1 downto 0);
        sub : in  std_logic;
        y   : out std_logic_vector(N downto 0)
    );
end entity add_sub;

architecture structural of add_sub is
    signal bx   : std_logic_vector(N - 1 downto 0);
    signal cout : std_logic;
begin

    assert is_pow2(N)
        report "add_sub: N must be a power of two"
        severity failure;

    -- a - b = a + not b + 1
    bx <= b xor (N - 1 downto 0 => sub);

    low : entity work.conditional_sum_adder
        generic map (N => N)
        port map (
            a    => a(N - 1 downto 0),
            b    => bx,
            cin  => sub,
            sum  => y(N - 1 downto 0),
            cout => cout
        );

    -- sign bit: b is zero-extended, so its inverted top bit is sub
    y(N) <= a(N) xor sub xor cout;

end architecture structural;
