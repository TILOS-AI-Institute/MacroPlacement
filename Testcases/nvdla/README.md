# Netlist preparation of NVDLA
We generate the RTL of NVDLA testcase using the steps given in [NVDLA/hw](https://github.com/nvdla/hw/tree/nv_small) GitHub repo. First we clone the **nv_small** branch and then we follow the steps givne in the [Integrator's Manual](http://nvdla.org/hw/v1/integration_guide.html). The [nv_small.spec](https://github.com/nvdla/hw/blob/nv_small/spec/defs/nv_small.spec) is used as the configuration file to generate the testcase.  

All the generated verilogs are copied to the [*rtl*](./rtl/) directory. NVDLA design uses dual port 256x64 bit SRAM. All our enablements currently support only single port SRAMS so we use two single port 256x64 SRAMs (One for reading from the read address and another for writing to the write address. We understand this do not replicated the actual functionality). We added fakeram_256x64_dp wrapper module to replace the dual port SRAMS with two single port SRAM and instantiate this wrapper in the [nv_ram_rws_256x64.v](./rtl/nv_ram_rws_256x64.v) file in the placeof behavioral model of the dual port ram (*nv_ram_rws_256x64_logic*).

During synthesis stageg if one of the memory output is not connected to anything then during optimization it will be removed. So we add this below logic for reading from the memory:
```
genvar k;
generate
    for (k = 0; k < 64; k=k+1) begin
        assign QA[k] = (~CENB & QB[k]) | (CENB & QA1[k]);
    end
endgenerate
```


Problem faced:
- Clone the **nv_small** branch. For the default branch, generated RTL will have more than million instances.
- To fix the problem of missing perl package use the *cpan* command.