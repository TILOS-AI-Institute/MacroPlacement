# NanGate45 (FreePDK45, 45nm Open Cell Library, bsg_fakeram memory generation)

The NanGate45 Open Cell Library is available under an Apache2.0 license from Silicon Integration Initiative (Si2). It is based on FreePDK45 from North Carolina State University. [\[Link\]](https://eda.ncsu.edu/downloads/)

As the FreePDK45/NanGate45 enablement does not have memory generators, we use the bsg_fakeram memory generator that is available on the [bsg_fakeram](https://github.com/jjcherry56/bsg_fakeram) GitHub repo.

With this combined enablement, testcases with SRAMs can be synthesized, placed and routed using both proprietary (commercial) tools such as Cadence Genus/Innovus, and open-source tools such as OpenROAD.

 The [*./lef*](./lef) directory contains the technology, standard cell and macro lef files and the [*./lib*](./lib/) directory contains the standard cell and macro liberty files.