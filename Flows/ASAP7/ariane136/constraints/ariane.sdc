#period set in nano-seconds - currently: 2ns = 500 MHz freq
create_clock [get_ports clk_i]  -name core_clock  -period 900
