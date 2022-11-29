#period set in nano-seconds - currently: 4ns = 250 MHz freq
set clk_period 900
if { [info exists ::env(CLK_PERIOD)] } {
  set clk_period   $::env(CLK_PERIOD)
}
create_clock [get_ports clk_i]  -name core_clock  -period $clk_period 
