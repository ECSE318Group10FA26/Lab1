# common/run.do - generic ModelSim batch script
#
# Driven by environment variables exported by sim.sh (which loads them from
# the problem's problem.env):
#
#   SOURCES   : space-separated design source files, compiled in order
#   TB_SOURCE : testbench source file
#   TB_TOP    : testbench top-level module (passed to vsim)
#
# All paths are relative to the problem directory, which is the working
# directory when this script runs inside the container.

if {![info exists env(SOURCES)] || ![info exists env(TB_SOURCE)] || ![info exists env(TB_TOP)]} {
    puts "error: SOURCES, TB_SOURCE and TB_TOP must be set - run via ./sim.sh, not directly"
    quit -code 1
}

transcript file transcript.log

# fresh work library
if [file exists work] {
    vdel -lib work -all
}
vlib work
vmap work work

# compile design sources in order, then the testbench
foreach f $env(SOURCES) {
    vlog -work work $f
}
vlog -work work $env(TB_SOURCE)

# simulate (no optimization, keep full visibility for waveforms)
vsim -voptargs=+acc work.$env(TB_TOP)

run -all
quit -f
