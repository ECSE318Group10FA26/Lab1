# common/run.do - generic ModelSim batch script
#
# Driven by environment variables exported by sim.sh (which loads them from
# the problem's problem.env):
#
#   SOURCES   : space-separated design source files, compiled in order
#   TB_SOURCE : testbench source file
#   TB_TOP    : testbench top-level module/entity (passed to vsim)
#   HDL       : "verilog" (default) compiles with vlog, "vhdl" with vcom
#   VCD_FILE  : vhdl mode only - path the VCD is dumped to (VHDL
#               testbenches have no $dumpfile, so it is dumped from here)
#
# vhdl mode only, set by sim.sh (parallel lists, in compile order):
#   VHDL_LIB_ROOT  : common/lib/vhdl as seen by vsim
#   VHDL_LIB_NAMES : logical library names (util, util_tb, ...)
#   VHDL_LIB_RELS  : their directories relative to VHDL_LIB_ROOT
#
# All paths are relative to the problem directory, which is the working
# directory when this script runs inside the container.

if {![info exists env(SOURCES)] || ![info exists env(TB_SOURCE)] || ![info exists env(TB_TOP)]} {
    puts "error: SOURCES, TB_SOURCE and TB_TOP must be set - run via ./sim.sh, not directly"
    quit -code 1
}

set hdl [expr {[info exists env(HDL)] ? $env(HDL) : "verilog"}]
if {$hdl eq "vhdl" && ![info exists env(VCD_FILE)]} {
    puts "error: VCD_FILE must be set in vhdl mode - run via ./sim.sh, not directly"
    quit -code 1
}

transcript file transcript.log

# fresh work library
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# vhdl mode: compile the logical libraries (common/lib/vhdl) first so the
# problem sources can use them; compiled units land in sim/vhdl_libs/
#
# A library directory may carry a files.order (one filename per line, '#'
# comments allowed) pinning the compile order when alphabetical order
# wouldn't respect dependencies; it must list every *.vhd in the
# directory.
if {$hdl eq "vhdl" && [info exists env(VHDL_LIB_NAMES)] && $env(VHDL_LIB_NAMES) ne ""} {
    file mkdir sim/vhdl_libs
    foreach name $env(VHDL_LIB_NAMES) rel $env(VHDL_LIB_RELS) {
        set libpath "sim/vhdl_libs/$name"
        if [file exists $libpath] {
            file delete -force $libpath
        }
        vlib $libpath
        vmap $name $libpath

        set libdir "$env(VHDL_LIB_ROOT)/$rel"
        set srcs [lsort [glob -nocomplain "$libdir/*.vhd"]]
        if [file exists "$libdir/files.order"] {
            set ordered {}
            set fh [open "$libdir/files.order" r]
            while {[gets $fh line] >= 0} {
                set line [string trim $line]
                if {$line eq "" || [string index $line 0] eq "#"} continue
                lappend ordered $line
            }
            close $fh
            # guard against a stale/typo'd order file silently dropping a source
            set ondisk {}
            foreach p $srcs { lappend ondisk [file tail $p] }
            if {[lsort $ordered] ne $ondisk} {
                puts "error: $libdir/files.order does not match the .vhd files on disk"
                puts "  listed:  [lsort $ordered]"
                puts "  on disk: $ondisk"
                quit -code 1
            }
            set srcs {}
            foreach f $ordered { lappend srcs "$libdir/$f" }
        }
        foreach f $srcs {
            vcom -2008 -lint -work $name $f
        }
    }
}

# compile design sources in order, then the testbench
# (verilog: -timescale gives the library modules a timeunit now that they
# carry gate delays; testbenches declare their own `timescale, which takes
# precedence)
foreach f [concat $env(SOURCES) $env(TB_SOURCE)] {
    if {$hdl eq "vhdl"} {
        vcom -2008 -lint -work work $f
    } else {
        vlog -sv -lint -warning error -timescale 1ns/1ps -work work $f
    }
}

# simulate (no optimization, keep full visibility for waveforms)
vsim -voptargs=+acc work.$env(TB_TOP)

if {$hdl eq "vhdl"} {
    vcd file $env(VCD_FILE)
    vcd add -r /$env(TB_TOP)/*
}

run -all
quit -f
