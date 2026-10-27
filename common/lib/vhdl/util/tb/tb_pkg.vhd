library ieee;
use ieee.std_logic_1164.all;

-- Self-checking testbench helpers. Failures are reported with severity
-- error so vsim counts them in the transcript summary (Errors: N).
package tb_pkg is

    -- report msg with severity error when cond is false
    procedure check(cond : boolean; msg : string := "check failed");

    -- report a got vs exp mismatch, printing both values
    procedure check_eq(got, exp : std_logic_vector; msg : string := "mismatch");
    procedure check_eq(got, exp : std_logic; msg : string := "mismatch");

end package tb_pkg;

package body tb_pkg is

    procedure check(cond : boolean; msg : string := "check failed") is
    begin
        assert cond
            report "FAIL: " & msg
            severity error;
    end procedure check;

    procedure check_eq(got, exp : std_logic_vector; msg : string := "mismatch") is
    begin
        check(got = exp,
              msg & ": got " & to_string(got) & ", expected " & to_string(exp));
    end procedure check_eq;

    procedure check_eq(got, exp : std_logic; msg : string := "mismatch") is
    begin
        check(got = exp,
              msg & ": got " & to_string(got) & ", expected " & to_string(exp));
    end procedure check_eq;

end package body tb_pkg;
