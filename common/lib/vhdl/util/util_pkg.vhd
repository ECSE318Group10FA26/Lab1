library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- General-purpose helpers shared by the VHDL problems.
package util_pkg is

    -- ceil(log2(n)): number of bits needed to represent n distinct values
    -- (clog2(1) = 0)
    function clog2(n : natural) return natural;

    -- true when n is a power of two
    function is_pow2(n : positive) return boolean;

    -- boolean to std_logic; handy for testbench stimulus:
    --   cin <= to_sl(ci = 1);
    function to_sl(b : boolean) return std_logic;

    -- to_integer(unsigned(s)) shorthand
    function to_nat(s : std_logic_vector) return natural;

end package util_pkg;

package body util_pkg is

    function clog2(n : natural) return natural is
        variable r : natural := 0;
    begin
        while 2**r < n loop
            r := r + 1;
        end loop;
        return r;
    end function clog2;

    function is_pow2(n : positive) return boolean is
        variable m : natural := n;
    begin
        while m > 1 loop
            if m mod 2 = 1 then
                return false;
            end if;
            m := m / 2;
        end loop;
        return true;
    end function is_pow2;

    function to_sl(b : boolean) return std_logic is
    begin
        if b then
            return '1';
        else
            return '0';
        end if;
    end function to_sl;

    function to_nat(s : std_logic_vector) return natural is
    begin
        return to_integer(unsigned(s));
    end function to_nat;

end package body util_pkg;
