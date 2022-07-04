# Netlist preparation of NVDLA
We generate the RTL of the NVDLA testcase using the steps given in the [NVDLA/hw](https://github.com/nvdla/hw/tree/nv_small) GitHub repo. First, we clone the **nv_small** branch and then we follow the steps givne in the [Integrator's Manual](http://nvdla.org/hw/v1/integration_guide.html). The [nv_small.spec](https://github.com/nvdla/hw/blob/nv_small/spec/defs/nv_small.spec) is used as the configuration file to generate the testcase. As NVDLA partition *c* has macros, our testcase only includes the partition *c*.  

All the generated verilogs are copied to the [*rtl*](./rtl/) directory. NVDLA design uses dual-port 256x64 bit SRAM. All our enablements currently support only single-port SRAM. So we use two single-port 256x64 bit SRAMs (One for reading from the read address and another for writing to the write address. We understand this does not replicate the actual functionality). We added the *fakeram_256x64_dp* wrapper module to replace the dual-port SRAM with two single-port SRAMs and instantiate this wrapper in the [nv_ram_rws_256x64.v](./rtl/nv_ram_rws_256x64.v) file in place of the behavioral model of the dual-port SRAM (*nv_ram_rws_256x64_logic*). The *fakeram_256x64_dp* wrapper module is available in the *fakeram<7|45|130>_256x64_dp.v*.

During the synthesis stage if the memory outputs are not connected to anything then they will be removed during optimization. So we add the following logic for the reading operation.
```
genvar k;
generate
    for (k = 0; k < 64; k=k+1) begin
        assign QA[k] = (~CENB & QB[k]) | (CENB & QA1[k]);
    end
endgenerate
```


Note:
- Clone the **nv_small** branch. For the default branch, generated RTL will have more than million instances.
- To install the missing perl packages use the *cpan* command.