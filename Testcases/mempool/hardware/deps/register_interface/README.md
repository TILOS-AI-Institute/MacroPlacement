# Generic Register Interface

This repository contains a simple register interface definition as well as protocol adapters from APB, AXI-Lite, and AXI to said interface. Furthermore, it allows to generate a uniform register interface.

## Read Timing

![Read Timing](docs/timing_read.png)

## Write Timing

![Write Timing](docs/timing_write.png)

## Register File Generator

We re-use lowrisc's register file generator to generate arbitrary configuration registers from an `hjson` description. See the the [tool's description](https://docs.opentitan.org/doc/rm/register_tool/) for further usage details.

We use the [vendor tool](https://docs.opentitan.org/doc/rm/vendor_in_tool/) `util/vendor.py` to get the sources and apply our custom patches on top.

    ./util/vendor.py vendor/lowrisc_opentitan.vendor.hjson --update

to re-vendor.