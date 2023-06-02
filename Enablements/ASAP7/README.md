# ASAP7 (7.5T cell library (RVT only), FakeRAM2.0 memory generation)

The Arizona State University's 7nm Predictive PDK (ASAP7) was developed at ASU in collaboration with ARM Research, and is available under the BSD 3-Clause license.  

As the ASAP7 enablement does not have memory generators, we use the FakeRAM2.0 memory generator available in the [FakeRAM2.0](https://github.com/ABKGroup/FakeRAM2.0/releases/tag/MacroPlacement.ISPD23) (**commit tag:** MacroPlacement.ISPD23) GitHub repo.

With this combined enablement, testcases with SRAMs can be synthesized, placed and routed using both proprietary (commercial) tools such as Cadence Genus/Innovus, and open-source tools such as OpenROAD.

The [*./lef*](./lef) directory contains the technology, standard cell and macro lef files, the [*./lib*](./lib/) directory contains the standard cell and macro liberty files and the [*./qrc*](./qrc/) directory contains the qrc technology file.
