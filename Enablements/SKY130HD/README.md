# SKY130HD FakeStack (SKY130HD library, bsg_fakeram memory generation, 9M FakeStack)

The SKY130HD enablement available in the OpenROAD-flow-script [GitHub repo](https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts/tree/master/flow/platforms/sky130hd) is a five-metal stack enablement. However, memory macro has blockage till metal four, so a five-metal stack is not enough to route our macro dominant testcases.  

In this enablement, each of the five routing layers and four cut layers have different lef properties (.e.g, minimum spacing, width, enclosure, etc.). Consider the five layers of the metal stack are Ma, Mb, Mc, Md and Me, and the stack configuration is named as 1Ma_1Mb_1Mc_1Md_1Me. We replicate the first four metal layers to generate the nine-metal layer FakeStack where the configuration is 2Ma_2Mb_2Mc_2Md_1Me. We use this nine-metal layer FakeStack of SKY130HD as one of the enablements. The [getTechLef.tcl](./lef/genTechLef.tcl) can be used to generate a FakeStack of layer configuration x<sub>1</sub>Ma_x<sub>2</sub>Mb_x<sub>3</sub>Mc_x<sub>4</sub>Md_1Me, where x<sub>i</sub> is greater or equal to one.  

We use the bsg_fakeram memory generator available in the [bsg_fakeram](https://github.com/jjcherry56/bsg_fakeram) GitHub repo to generate the required SRAMs. The [sky130hd.cfg](./util/sky130hd.cfg) is the configuration file used to generate all the required memories.

With this combined enablement, testcases with SRAMs can be synthesized, placed and routed using both proprietary (commercial) tools such as Cadence Genus/Innovus, and open-source tools such as OpenROAD.

The [*./lef*](./lef) directory contains the technology, standard cell and macro lef files, the [*./lib*](./lib/) directory contains the standard cell and macro liberty files.
