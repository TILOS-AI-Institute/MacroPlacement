# LEF/DEF and Bookshelf (OpenDB, RosettaStone) translators

Convert netlists in other formats (e.g. LEF/DEF or Bookshelf) to netlist in protocol buffer format

We implemented three different types of versions based on OpenDB.

* **LEF/DEF -> Protocol Buffer Format** :  In this conversion, users need to provide the def file and corresponding lefs.  Here is [an example](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/FormatTranslators/test/LefDef2ProtocolBufferFormat/test2.py).
*  **Bookshelf -> Protocol Buffer Format** :  In this conversion, users can directly convert netlist in Bookshelf format to corresponding netlist in protocol buffer format.  Here is [an example](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/FormatTranslators/test/Bookshelf2ProtocolBufferFormat/test1.py).
*  **Bookshelf -> Lef/Def -> Protocol Buffer Format** : In this conversion, users can firstly map the netlist in Bookshelf format to some technology node (eg. NanGate45 and ASAP7), the convert the netlist to corresponding netlist in protocol buffer format. Here is an example [an example](https://github.com/TILOS-AI-Institute/MacroPlacement/blob/main/CodeElements/FormatTranslators/test/Bookshelf2ProtocolBufferFormat/test3.py).









