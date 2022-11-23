# Reqrsp Interface

A simple interface with a single request channel and a single response channel,
for both read and write data. A more thorough documentation can be found in the
[docs](doc/index.md) folder.

## List of Modules

| Name             | Description                                                                  | Status     |
| ---------------- | ---------------------------------------------------------------------------- | ---------- |
| `axi_to_reqrsp`  | Protocol translator between `reqrsp` and AXI4+ATOP                           | active     |
| `reqrsp_cut`     | Insert registers (i.e., a pipeline stage) into request and/or response path. | active     |
| `reqrsp_demux`   | Demultiplex, based on a select signal.                                       | active     |
| `reqrsp_intf`    | Systemverilog interface definition of `reqrsp` interface.                    | active     |
| `reqrsp_iso`     | Isochronous clockdomain crossing.                                            | active     |
| `reqrsp_mux`     | Arbitrate multiple ports based on round-robin arbitration.                   | active     |
| `reqrsp_test`    | Common test infrastructure for the `reqrsp` protocol.                        | active     |
| `reqrsp_to_axi`  | Protocol translator between AXI4+ATOP and `reqrsp`.                          | active     |
| `reqrsp_to_tcdm` | Protocol translator between `reqrsp` and `tcdm` protocol.                    | _untested_ |
