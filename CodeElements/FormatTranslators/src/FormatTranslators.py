#############################################################
# Convert the OpenDB to open-source protocol buffer format
# Please refer to the Circuit Training repo for details of
# the open-source protocol buffer format
#############################################################
import os
import time
import shutil
import sys
sys.path.append('./utils')

# String Helper #
def print_placeholder(key, value):
    line = "  attr {\n"
    line += f'    key: "{key}"\n'
    line += '    value {\n'
    line += f'      placeholder: "{value}"\n'
    line += '    }\n'
    line += '  }\n'
    return line

def print_float(key, value):
    value = round(value, 6)
    line = "  attr {\n"
    line += f'    key: "{key}"\n'
    line += '    value {\n'
    line += f'      f: {value}\n'
    line += '    }\n'
    line += '  }\n'
    return line

# Port
class Port:
    def __init__(self, name, x = 0.0, y = 0.0, side = "BOTTOM"):
        self.name = name
        self.x = x
        self.y = y
        self.side = side # "BOTTOM", "TOP", "LEFT", "RIGHT"
        self.sinks = [] # standard cells, macro pins, ports driven by this cell

    def SetPos(self, x, y):
        self.x = x
        self.y = y

    def SetSide(self, side):
        self.side = side

    def AddSink(self, sink):
        if (sink not in self.sinks) and (self.name != sink):
            self.sinks.append(sink)

    def AddSinks(self, sinks):
        for sink in sinks:
            if (sink not in self.sinks) and (self.name != sink):
                self.sinks.append(sink)

    def GetType(self):
        return "PORT"

    def __str__(self):
        self.str = ""
        self.str += "node {\n"
        name = ''
        for char in self.name:
            if char == '\\':
                name += '\\\\'
            else:
                name += char
        self.str += '  name: "' + name + '"\n'

        for sink in self.sinks:
            sink_new = ''
            for char in sink:
                if char == '\\':
                    sink_new += '\\\\'
                else:
                    sink_new += char
            sink = sink_new
            self.str += '  input: "' + sink + '"\n'

        self.str += print_placeholder('type', 'PORT')
        self.str += print_placeholder('side', self.side)
        self.str += print_float('x', self.x)
        self.str += print_float('y', self.y)
        self.str += "}\n"
        return self.str


# Standard Cell
# Based on our understanding of the format description,
# the location of standard cell (x, y) is the center of
# its bounding box in def file.
# Each Standard cell only have one input pin and one output pin
class StandardCell:
    def __init__(self, name, width, height, x = 0.0, y = 0.0):
        self.name = name
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.sinks = [] # standard cells, macro pins, ports driven by this cell

    def SetPos(self, x, y):
        self.x = x
        self.y = y

    def AddSink(self, sink):
        if (sink not in self.sinks) and (self.name != sink):
            self.sinks.append(sink)

    def AddSinks(self, sinks):
        for sink in sinks:
            if (sink not in self.sinks) and (self.name != sink):
                self.sinks.append(sink)

    def GetType(self):
        return "STDCELL"


    def __str__(self):
        self.str = ""
        self.str += "node {\n"
        name = ''
        for char in self.name:
            if char == '\\':
                name += '\\\\'
            else:
                name += char
        self.str += '  name: "' + name + '"\n'
        for sink in self.sinks:
            sink_new = ''
            for char in sink:
                if char == '\\':
                    sink_new += '\\\\'
                else:
                    sink_new += char
            sink = sink_new
            self.str += '  input: "' + sink + '"\n'

        self.str += print_placeholder('type', 'STDCELL')
        self.str += print_float('height', self.height)
        self.str += print_float('width', self.width)
        self.str += print_float('x', self.x)
        self.str += print_float('y', self.y)
        self.str += "}\n"
        return self.str

# Macro
# Based on our understanding of the format description,
# the location of standard cell (x, y) is the center of
# its bounding box in def file.
# the pins of each macro are sperately defined
# The orientation of macro can be N, FN, S, FS, E, FE, W, FW
# if the example, they set the type to "MACRO" instead of "macro"
class Macro:
    def __init__(self, name, width, height, x = 0.0, y = 0.0, orientation = "N"):
        self.name = name
        self.width = width
        self.height = height
        self.x = x
        self.y = y
        self.orientation = orientation
        self.is_soft = False
        self.input_pins = []
        self.output_pins = []

    def AddInputPin(self, macro_pin):
        self.input_pins.append(macro_pin)

    def GetInputPins(self):
        return self.input_pins

    def AddOutputPin(self, macro_pin):
        self.output_pins.append(macro_pin)

    def GetOutputPins(self):
        return self.output_pins

    def SetPos(self, x, y):
        self.x = x
        self.y = y

    def SetOrientation(self, orientation):
        self.orientation = orientation

    def GetPins(self):
        return self.input_pins + self.output_pins

    def IsSoft(self):
        self.is_soft = True

    def GetType(self):
        if (self.is_soft == True):
            return "macro"
        else:
            return "MACRO"

    def __str__(self):
        self.str = ""
        self.str += "node {\n"
        name = ''
        for char in self.name:
            if char == '\\':
                name += '\\\\'
            else:
                name += char
        self.str += '  name: "' + name + '"\n'
        self.str += print_placeholder('type', self.GetType())
        self.str += print_placeholder('orientation', self.orientation)
        self.str += print_float('height', self.height)
        self.str += print_float('width', self.width)
        self.str += print_float('x', self.x)
        self.str += print_float('y', self.y)
        self.str += "}\n"
        return self.str

# Macro pin
class MacroPin:
    def __init__(self, name, macro_name, x_offset, y_offset, macro_type,
                x = 0.0, y = 0.0):
        self.name = name
        self.macro_name = macro_name
        self.macro_type = macro_type
        self.x_offset = x_offset
        self.y_offset = y_offset
        self.x = x
        self.y = y
        self.sinks = [] # standard cells, macro pins, ports driven by this cell
        self.weight = 1 # If multiple std cells in a soft-macros
                        # drive std cells in another soft-macro,
                        # the weight will be larger than 1.

    def GetName(self):
        return self.name

    def SpecifyWeight(self, weight):
        self.weight = weight

    def AddSink(self, sink):
        if (sink not in self.sinks) and (self.name != sink):
            self.sinks.append(sink)

    def AddSinks(self, sinks):
        for sink in sinks:
            if (sink not in self.sinks) and (self.name != sink):
                self.sinks.append(sink)


    def __str__(self):
        self.str = ""
        self.str += "node {\n"
        name = ''
        for char in self.name:
            if char == '\\':
                name += '\\\\'
            else:
                name += char
        self.str += '  name: "' + name + '"\n'
        for sink in self.sinks:
            sink_new = ''
            for char in sink:
                if char == '\\':
                    sink_new += '\\\\'
                else:
                    sink_new += char
            sink = sink_new
            self.str += '  input: "' + sink + '"\n'

        macro_name = ''
        for char in self.macro_name:
            if char == '\\':
                macro_name += '\\\\'
            else:
                macro_name += char
        self.str += print_placeholder('macro_name', str(macro_name))
        if self.macro_type == "MACRO":
            self.str += print_placeholder('type', 'MACRO_PIN')
        else:
            self.str += print_placeholder('type', 'macro_pin')
        if (self.weight > 1):
            self.str += print_float('weight', self.weight)

        self.str += print_float('x_offset', self.x_offset)
        self.str += print_float('y_offset', self.y_offset)
        self.str += print_float('x', self.x)
        self.str += print_float('y', self.y)
        self.str += "}\n"
        return self.str



# BookShelf Format to open-source protocol buffer format
# Please check http://vlsicad.eecs.umich.edu/BK/ISPD06bench/BookshelfFormat.txt for details of BookShelf Format
class BookShelf2ProBufFormat:
    def __init__(self, file_dir, design,  output_file):
        self.design = design
        self.file_dir = file_dir
        self.nets_file = file_dir + "/" + design + ".nets"
        self.nodes_file = file_dir + "/" + design + ".nodes"
        self.pl_file = file_dir + "/" + design + ".pl"
        self.scl_file = file_dir + "/" + design + ".scl"
        self.output_file = output_file
        self.insts = {  }  # map name to Port, Macro, StandardCell

        # circuit row information
        self.site_height = 0.0
        self.fp_lx = 0.0
        self.fp_ly = 0.0
        self.fp_ux = 0.0
        self.fp_uy = 0.0


        # functions
        self.CheckFiles()
        self.ReadSclFile()
        self.ReadNodesFile()
        self.ReadPlFile()
        self.ReadNetsFile()
        self.Output()

    def CheckFiles(self):
        ###
        # zzz.nodes: specifies the set of objects. For each object,
        # object_name        width         height        terminal
        # keyword "terminal" appears only for fixed objects.
        if (os.path.exists(self.nodes_file) == False):
            print("[INFO]  Error! ",  self.nodes_file, " does not exist!!!\n")
            exit()

        ###
        # zzz.nets: specifies the set of nets. For each net,
        # NetDegree : k net_name
        # input pin  pin offset is measured from the center of corresponding object
        #  if pin offsets are unavailable, assumed to be (0,0)
        #        object_name        I : x_offset        y_offset
        #  output pin
        #        object_name        O : x_offset        y_offset
        if (os.path.exists(self.nets_file) == False):
            print("[INFO]  Error! ",  self.nets_file, " does not exist!!!\n")
            exit()

        ###
        # zzz.pl: specifies the location & orientation of objects. For each object,
        # x_location & y_location are bottom left coordinates of an object
        # orientation is one of N, S, E, W, FN, FS, FE, FW
        # and interpreted as in LEF/DEF (see Orientation.ppt in this
        # documentation for visual representations of each orientation)
        # object_name        x_location        y_location        : orientation
        # fixed object
        # object_name        x_location        y_location        : orientation    /FIXED
        if (os.path.exists(self.pl_file) == False):
             print("[INFO]  Error! ",  self.pl_file, " does not exist!!!\n")
             exit()

        ###
        #zzz.scl: circuit row information. For each row,
        #CoreRow Horizontal
        #   Coordinate :    www  # row starts at coordinate www
                                 # (y-coordinate if horizontal, x-coordinate if vertical row)
        #   Height :        yyy  # row height is yyy
        #   Sitewidth :     1
        #   Sitespacing :   1    # distance between the left edges of two adjacent sites
        #   Siteorient :    1
        #   Sitesymmetry :  1
        # You can specify subrows within a row. They following says the subrow spans from
        # aaa to (aaa + (bbb-1)*Sitespacing + Sitewidth) with yyy height.
        #   SubrowOrigin :  aaa  NumSites : bbb
        # Additional Subrows may be specified if there are breaks in the row
        # due to obstacles, but are not required. One subrow is always required.
        if (os.path.exists(self.scl_file) == False):
             print("[INFO]  Error! ",  self.scl_file, " does not exist!!!\n")
             exit()


    # Read Circuit Row information from zzz.scl
    def ReadSclFile(self):
        with open(self.scl_file) as f:
            content = f.read().splitlines()
        f.close()

        line_id = 0
        # read Numrows
        num_rows = 0
        while(line_id < len(content)):
            items = content[line_id].split()
            if((len(items) == 3) and ((items[0] == "Numrows") or (items[0] == "NumRows"))):
                num_rows = int(items[-1])
                break
            else:
                line_id += 1

        # Read site_height, site_width,
        # num_sites, fp_lx, fp_ly
        site_width = 0.0
        num_sites = 0
        while(line_id < len(content)):
            items = content[line_id].split()
            if((len(items) == 2) and (items[0] == "CoreRow")):
                line_id += 1
                items = content[line_id].split()
                self.fp_ly = float(items[-1])
                line_id += 1
                items = content[line_id].split()
                self.site_height = float(items[-1])
                line_id += 1
                items = content[line_id].split()
                site_width = float(items[-1])
                line_id += 4
                items = content[line_id].split()
                self.fp_lx = float(items[2])
                num_sites = int(items[-1])
                break
            else:
                line_id += 1

        self.fp_ux = self.fp_lx + site_width * num_sites
        self.fp_uy = self.fp_ly + num_rows * self.site_height

        print('*'*80)
        print("Circuit Row Information")
        print("[INFO] Core Size : ", self.fp_lx, self.fp_ly, self.fp_ux, self.fp_uy)
        print("[INFO] Site Height : ", self.site_height)
        print("\n\n")


    # Read zzz.nodes file and create instances
    # We determine the type of node based on its width and height
    # if height < self.site_height, type = Node
    # if height > self.site_height, type = Macro
    # otherwise,  type = StdandCell
    def ReadNodesFile(self):
        with open(self.nodes_file) as f:
            content = f.read().splitlines()
        f.close()

        start_line = 0
        for i in range(len(content)):
            items = content[i].split()
            if ((len(items) == 3) and (items[0] == "NumTerminals")):
                start_line = i  +  1
                break

        for i in range(start_line, len(content)):
            items = content[i].split()
            if (len(items) < 3):
                continue

            inst_name = items[0]
            width = float(items[1])
            height = float(items[2])
            if (height < self.site_height):
                self.insts[inst_name] = Port(inst_name)
            elif (height == self.site_height):
                self.insts[inst_name] = StandardCell(inst_name, width, height)
            else:
                self.insts[inst_name] = Macro(inst_name, width, height)

    # Read Pl file
    def ReadPlFile(self):
        with open(self.pl_file) as f:
            content = f.read().splitlines()
        f.close()

        start_line = 0
        for i in range(len(content)):
            items = content[i].split()
            if (len(items) == 5):
                start_line = i
                break

        for i in range(start_line, len(content)):
            items = content[i].split()
            if (len(items) < 5):
                continue

            inst_name = items[0]
            x = float(items[1])
            y = float(items[2])
            orientation = items[4]
            self.insts[inst_name].SetPos(x, y)
            if (self.insts[inst_name].GetType() == "MACRO"):
                self.insts[inst_name].SetOrientation(orientation)
            elif (self.insts[inst_name].GetType() == "PORT"):
                if (x <= self.fp_lx):
                    self.insts[inst_name].SetSide("LEFT")
                elif ( x >= self.fp_ux):
                    self.insts[inst_name].SetSide("RIGHT")
                elif ( y >= self.fp_uy):
                    self.insts[inst_name].SetSide("TOP")
                else:
                    self.insts[inst_name].SetSide("BOTTOM")

    # Read Nets file
    def ReadNetsFile(self):
        with open(self.nets_file) as f:
            content = f.read().splitlines()
        f.close()

        start_line = 0
        for i in range(len(content)):
            items = content[i].split()
            if ((len(items) == 3) and (items[0] == "NumPins")):
                start_line = i + 1
                break

        # We ignore all the bidirectional nets
        # We don't see any definition related to bidirectional nets
        # in circuit training repo
        line_id = start_line
        while (line_id < len(content)):
            items = content[line_id].split()
            if ((len(items) == 4) and (items[0] == "NetDegree")):
                line_id += 1
                sink_list = []
                driver = None
                while((line_id < len(content)) and (len(content[line_id].split()) == 5)):
                    items = content[line_id].split()
                    inst_name = items[0]
                    io_type = items[1]
                    x_offset = float(items[3])
                    y_offset = float(items[4])
                    if (io_type == "O"):
                        driver = [inst_name, x_offset, y_offset]
                    else:
                        sink_list.append([inst_name, x_offset, y_offset])
                    line_id += 1
                # if the net have a driver
                if ((driver != None) and (len(sink_list) > 0)):
                    sink_name_list = [] # Port, StandardCell, MacroPin
                    for sink in sink_list:
                        inst_name = sink[0]
                        if (self.insts[inst_name].GetType() == "MACRO"):
                            pin_name = inst_name + "/Pinput_" + str(len(self.insts[inst_name].GetInputPins()))
                            self.insts[inst_name].AddInputPin(MacroPin(pin_name, inst_name, sink[1], sink[2], "MACRO"))
                            sink_name_list.append(pin_name)
                        else:
                            sink_name_list.append(inst_name)

                    driver_name = driver[0]
                    if (self.insts[driver_name].GetType() == "MACRO"):
                        pin_id = len(self.insts[driver_name].GetOutputPins())
                        pin_name = inst_name + "/Poutput_" + str(pin_id)
                        macro_pin = MacroPin(pin_name, driver_name, driver[1], driver[2], "MACRO")
                        macro_pin.AddSinks(sink_name_list)
                        self.insts[driver_name].AddOutputPin(macro_pin)
                    else:
                        self.insts[driver_name].AddSinks(sink_name_list)
            else:
                line_id += 1


    # Generate.pb.txt file
    def Output(self):
        f = open(self.output_file, "w")
        for inst_name, inst in self.insts.items():
            f.write(str(inst))
            if (inst.GetType() == "MACRO"):
                for macro_pin in inst.GetPins():
                    f.write(str(macro_pin))
        f.close()



# OpenDB to open-source protocol buffer format
# We use the OpenDB database in OpenROAD to read lef/def files
# We have provided an openroad exe
class ODB2ProBufFormat:
    def __init__(self, file_dir, design, output_file, openroad_exe,
                net_size_threshold):
        self.design = design
        self.file_dir = file_dir
        self.db_file = file_dir + "/" + design + ".odb"
        self.openroad_exe = openroad_exe
        self.net_size_threshold = net_size_threshold
        self.output_file = output_file

        self.io_file = file_dir + "/" + design + ".hgr.io"
        self.macro_pin_file = file_dir + "/" + design + ".hgr.macro_pin"
        self.inst_file  = file_dir + "/" + design + ".hgr.instance"
        self.outline_file = file_dir + "/" + design + ".hgr.outline"
        self.net_file = file_dir + "/" + design + ".hgr.net"
        self.insts = {  }  # map name to Port, Macro, StandardCell
        self.macro_pin_offset = {  } # map macro_pin_name to offset

        # circuit row information
        self.fp_lx = 0.0
        self.fp_ly = 0.0
        self.fp_ux = 0.0
        self.fp_uy = 0.0

        # functions
        self.CheckFiles()
        self.ReadOutlineFile()
        self.ReadIOFile()
        self.ReadInstFile()
        self.ReadMacroPinFile()
        self.ReadNetFile()
        self.Output()


    def CheckFiles(self):
        # IO file
        if (os.path.exists(self.io_file) == False):
            print("[INFO]  Error! ",  self.io_file, " does not exist!!!\n")
            exit()

        # macro_pin file
        if (os.path.exists(self.macro_pin_file) == False):
            print("[INFO]  Error! ",  self.macro_pin_file, " does not exist!!!\n")
            exit()

        # inst file
        if (os.path.exists(self.inst_file) == False):
            print("[INFO]  Error! ",  self.inst_file, " does not exist!!!\n")
            exit()

        # outline file
        if (os.path.exists(self.outline_file) == False):
            print("[INFO]  Error! ",  self.outline_file, " does not exist!!!\n")
            exit()

        # net file
        if (os.path.exists(self.net_file) == False):
            print("[INFO]  Error! ",  self.net_file, " does not exist!!!\n")
            exit()


    # Read outline file
    def ReadOutlineFile(self):
        with open(self.outline_file) as f:
            content = f.read().splitlines()
        f.close()

        items = content[0].split()
        self.fp_lx = float(items[0])
        self.fp_ly = float(items[1])
        self.fp_ux = float(items[2])
        self.fp_uy = float(items[3])

        print('*'*80)
        print("Outline Information")
        print("[INFO] Core Size : ", self.fp_lx, self.fp_ly, self.fp_ux,
                self.fp_uy)
        print("\n\n")


    # Read IO file
    def ReadIOFile(self):
        with open(self.io_file) as f:
            content = f.read().splitlines()
        f.close()

        for line in content:
            items = line.split()
            io_name = items[0]
            lx = float(items[1])
            ly = float(items[2])
            ux = float(items[3])
            uy = float(items[4])
            side = "LEFT"

            if (lx <= self.fp_lx):
                side = "LEFT"
            elif (ux >= self.fp_ux):
                side = "RIGHT"
            elif (uy >= self.fp_uy):
                side = "TOP"
            else:
                side = "BOTTOM"

            self.insts[io_name] = Port(io_name, (lx + ux) / 2.0, (ly + uy) / 2.0, side)


    # Read instance file
    def ReadInstFile(self):
        with open(self.inst_file) as f:
            content = f.read().splitlines()
        f.close()

        for line in content:
            items = line.split()
            inst_name = items[0]
            block_flag = items[1]
            lx = float(items[2])
            ly = float(items[3])
            ux = float(items[4])
            uy = float(items[5])
            orientation = items[6]
            width = ux - lx
            height = uy - ly
            x = (lx + ux) / 2.0
            y = (ly + uy) / 2.0
            if block_flag == '1':
                self.insts[inst_name] = Macro(inst_name, width, height, x, y, orientation)
            else:
                self.insts[inst_name] = StandardCell(inst_name, width, height, x, y)



    # Read Macro Pin file
    def ReadMacroPinFile(self):
        with open(self.macro_pin_file) as f:
            content = f.read().splitlines()
        f.close()

        for line in content:
            items = line.split()
            pin_name = items[0] + '/' + items[1]
            x_offset = float(items[2])
            y_offset = float(items[3])
            self.macro_pin_offset[pin_name] = [x_offset, y_offset]


    # Read Net file
    def ReadNetFile(self):
        with open(self.net_file) as f:
            content = f.read().splitlines()
        f.close()

        for line in content:
            items = line.split()
            num_pin = len(items) / 4
            if (num_pin > self.net_size_threshold):
                pass
            else:
                driver_name = items[2]
                driver_pin_name = driver_name + '/' + items[0]
                sinks_name = []
                for i in range(1, int(num_pin)):
                    inst_name = items[4 * i + 2]
                    pin_name = inst_name + '/' + items[4 * i]
                    if (self.insts[inst_name].GetType() == "MACRO"):
                        offset = self.macro_pin_offset[pin_name]
                        self.insts[inst_name].AddInputPin(MacroPin(pin_name, inst_name, offset[0], offset[1]))
                        sinks_name.append(pin_name)
                    else:
                        sinks_name.append(inst_name)
                # Add sinks to driver
                if (self.insts[driver_name].GetType() == "MACRO"):
                    offset = self.macro_pin_offset[driver_pin_name]
                    macro_pin = MacroPin(driver_pin_name, driver_name, offset[0], offset[1])
                    macro_pin.AddSinks(sinks_name)
                    self.insts[driver_name].AddOutputPin(macro_pin)
                else:
                    self.insts[driver_name].AddSinks(sinks_name)


    # Generate.pb.txt file
    def Output(self):
        f = open(self.output_file, "w")
        for inst_name, inst in self.insts.items():
            f.write(str(inst))
            if (inst.GetType() == "MACRO"):
                for macro_pin in inst.GetPins():
                    f.write(str(macro_pin))
        f.close()



# Convert LEF/DEF files to Protocol Buffer Format
class LefDef2ProBufFormat:
    def __init__(self, lef_list, def_file, design, openroad_exe, net_size_threshold):
        self.lef_list = lef_list
        self.def_file = def_file
        self.design = design
        self.output_file = self.design + ".pb.txt"
        self.openroad_exe = openroad_exe
        self.net_size_threshold = net_size_threshold
        self.file_dir = os.getcwd() + "/rtl_mp"

        if not os.path.exists(self.file_dir):
            os.makedirs(self.file_dir)

        self.CreateODB()
        ODB2ProBufFormat(self.file_dir, self.design, self.output_file, self.openroad_exe, self.net_size_threshold)

        cmd = "rm -rf " + self.file_dir
        os.system(cmd)

    def CreateODB(self):
        file_name = "generate_odb.tcl"
        line  = "set top_design " + self.design + "\n"
        line += "set def_file " + self.def_file + "\n"
        line += 'set ALL_LEFS "\n'
        for lef in self.lef_list:
            line += '    ' + lef + '\n'
        line += '"\n'
        line += 'foreach lef_file ${ALL_LEFS} {\n'
        line += '    read_lef $lef_file\n'
        line += '}\n'
        line += "read_def " + self.def_file + "\n"
        line += "partition_design -max_num_inst 2000000 -min_num_inst 40000 "
        line += "-max_num_macro 12 -min_num_macro 4 "
        line += "-net_threshold 20  -virtual_weight 50 "
        line += "-num_hop 0 -timing_weight 1000 "
        line += "-report_file ${top_design}.hgr \n"
        line += "exit\n"
        f = open(file_name, "w")
        f.write(line)
        f.close()

        cmd = self.openroad_exe + ' ' + file_name
        os.system(cmd)

        cmd = "rm " + file_name
        os.system(cmd)


### Map Bookshelf to LEF/DEF files for different technology
### Currently we support NanGate45 and ASAP7
### Technology can be NanGate45 and ASAP7
class Bookshelf2LefDef2ProBufFormat:
    def __init__(self, lef_list, openroad_exe, file_dir, design, tech, src_dir, net_size_threshold):
        self.lef_list = lef_list
        self.openroad_exe = openroad_exe
        self.file_dir = file_dir
        self.design = design
        self.tech = tech
        self.src_dir = src_dir
        self.net_size_threshold = net_size_threshold

        self.Mapper()

        self.lef_list.append(self.design + "_macro.lef")
        self.def_file = self.design + ".def"
        LefDef2ProBufFormat(self.lef_list, self.def_file, self.design, self.openroad_exe, self.net_size_threshold)

    def Mapper(self):
        f = open("map_tech.py", "w")
        line = 'import sys\n'
        line += 'sys.path.append("'+ self.src_dir + '")\n'
        line += 'sys.path.append("'+ self.src_dir + '/utils")\n'
        line += 'from mapper import MapNanGate45\n'
        line += 'from mapper import MapASAP7\n'
        line += 'file_dir = "' + self.file_dir + '"\n'
        line += 'design = "' + self.design + '"\n'
        line += 'utils_dir = "' + self.src_dir + '/utils"\n'
        line += 'lef_list = ['
        for i in range(len(self.lef_list)):
            line += '"'+ self.lef_list[i] + '"'
            if (i < (len(self.lef_list) - 1)):
                line += ','
            else:
                line += ']\n'
        if (self.tech == "NanGate45"):
            line += "MapNanGate45(file_dir, lef_list, design, utils_dir)\n"
        else:
            line += "MapASAP7(file_dir, lef_list, design, utils_dir)\n"
        f.write(line)
        f.close()

        cmd = self.openroad_exe + " -python map_tech.py"
        os.system(cmd)

        cmd = "rm map_tech.py"
        os.system(cmd)





















