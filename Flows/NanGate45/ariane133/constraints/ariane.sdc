#period set in nano-seconds - currently: 4ns = 250 MHz freq
create_clock [get_ports clk_i]  -name core_clock  -period 4
