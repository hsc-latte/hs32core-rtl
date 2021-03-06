set script_dir [file dirname [file normalize [info script]]]

set ::env(DESIGN_NAME) hs32_user_proj

set ::env(VERILOG_FILES) "\
	$script_dir/../../skywater/main.v"

set	::env(VERILOG_INCLUDE_DIRS) "\
	$script_dir/../../ \
	$script_dir/../../cpu"

set ::env(CLOCK_NET) "counter.clk"
set ::env(CLOCK_PERIOD) "10"

set ::env(FP_SIZING) absolute
set ::env(DIE_AREA) "0 0 600 600"
set ::env(DESIGN_IS_CORE) 0

set ::env(FP_PIN_ORDER_CFG) $script_dir/pin_order.cfg
# set ::env(FP_CONTEXT_DEF) $script_dir/../user_project_wrapper/runs/user_project_wrapper/tmp/floorplan/ioPlacer.def.macro_placement.def
# set ::env(FP_CONTEXT_LEF) $script_dir/../user_project_wrapper/runs/user_project_wrapper/tmp/merged_unpadded.lef

set ::env(PL_BASIC_PLACEMENT) 1
set ::env(PL_TARGET_DENSITY) 0.15
