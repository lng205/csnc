# Simple Vivado Tcl wrapper to compile and run the FEC codec simulations.
#
# Usage (from Windows CMD or PowerShell):
#   vivado -mode batch -source fec_codec_sim.tcl
#
# Optional arguments:
#   -work <path>    : directory to use for generated artifacts (defaults to script folder)
#   -skip_stream_tb : skip the streaming wrapper testbench
#   -skip_core_tb   : skip the combinational core testbench

namespace eval fec_codec_sim {
  variable work_dir
  variable run_core_tb 1
  variable run_stream_tb 1
}

proc fec_codec_sim::parse_args {args} {
  variable work_dir
  variable run_core_tb
  variable run_stream_tb

  set work_dir [file dirname [info script]]

  for {set idx 0} {$idx < [llength $args]} {incr idx} {
    set flag [lindex $args $idx]
    switch -- $flag {
      -work {
        incr idx
        if {$idx >= [llength $args]} {
          error "-work requires a directory argument"
        }
        set work_dir [lindex $args $idx]
      }
      -skip_stream_tb {
        set run_stream_tb 0
      }
      -skip_core_tb {
        set run_core_tb 0
      }
      default {
        error "Unknown argument: $flag"
      }
    }
  }
}

proc fec_codec_sim::run {args} {
  variable work_dir
  variable run_core_tb
  variable run_stream_tb

  parse_args $args

  if {![file isdirectory $work_dir]} {
    file mkdir $work_dir
  }

  set script_dir [file dirname [info script]]
  set srcs [list \
    [file join $script_dir fec_matrix_apply.sv] \
    [file join $script_dir fec_codec.sv] \
    [file join $script_dir fec_codec_tb.sv] \
    [file join $script_dir fec_codec_stream.sv] \
    [file join $script_dir fec_codec_stream_tb.sv] \
  ]

  puts "==> Working directory: $work_dir"
  cd $work_dir

  # Clean previous runs
  foreach junk {xsim.dir xelab.pb xvlog.pb vivado.jou vivado.log xsim.jou xsim.log} {
    if {[file exists $junk]} {
      file delete -force $junk
    }
  }

  # Compile all sources once
  puts "==> xvlog"
  if {[catch {eval xvlog -sv $srcs} result]} {
    error "xvlog failed:\n$result"
  } else {
    puts $result
  }

  # Core combinational testbench
  if {$run_core_tb} {
    puts "==> xelab fec_codec_tb"
    if {[catch {xelab work.fec_codec_tb -s fec_codec_tb} result]} {
      error "xelab fec_codec_tb failed:\n$result"
    } else {
      puts $result
    }
    puts "==> xsim fec_codec_tb"
    if {[catch {xsim fec_codec_tb -runall} result]} {
      error "xsim fec_codec_tb failed:\n$result"
    } else {
      puts $result
    }
  } else {
    puts "==> Skipping fec_codec_tb"
  }

  # Streaming wrapper testbench
  if ($run_stream_tb) {
    puts "==> xelab fec_codec_stream_tb"
    if {[catch {xelab work.fec_codec_stream_tb -s fec_codec_stream_tb} result]} {
      error "xelab fec_codec_stream_tb failed:\n$result"
    } else {
      puts $result
    }
    puts "==> xsim fec_codec_stream_tb"
    if {[catch {xsim fec_codec_stream_tb -runall} result]} {
      error "xsim fec_codec_stream_tb failed:\n$result"
    } else {
      puts $result
    }
  } else {
    puts "==> Skipping fec_codec_stream_tb"
  }

  puts "==> Complete"
}

fec_codec_sim::run $argv
