'''
This Code converts the BookShelf format to Proto buf format
'''
import re
import os
from datetime import date

def find_pin_act_loc(cx, cy, x_offset, y_offset, orient):
    if orient in ["E", "FE", "W", "FW"]:
        x_offset, y_offset = y_offset, x_offset

    if orient in ["FN", "S", "FE", "W"]:
        x_offset *= -1

    if orient in ["S", "FS", "E", "FE"]:
        y_offset *= -1

    pin_x = cx + x_offset
    pin_y = cy + y_offset
    return pin_x, pin_y

def print_placeholder(fp, key, value):
    fp.write("  attr {\n")
    fp.write(f"    key: \"{key}\"\n")
    fp.write("    value {\n")
    fp.write(f"      placeholder: \"{value}\"\n")
    fp.write("    }\n")
    fp.write("  }\n")
    return

def print_float(fp, key, value):
    fp.write("  attr {\n")
    fp.write(f"    key: \"{key}\"\n")
    fp.write("    value {\n")
    fp.write(f"      f: {value}\n")
    fp.write("    }\n")
    fp.write("  }\n")
    return

class instance:
    def __init__(self, idx, name):
        self.id = idx
        self.master_id = None
        self.name = name
        self.width = None
        self.height = None
        self.llx = None
        self.lly = None
        self.cx = None
        self.cy = None
        self.orient = None
        self.isMacro = None   # Considers macro if heigh is more than row height
        self.ipins = []
        self.opins = []
        self.ipin_x = []
        self.ipin_y = []
        self.opin_x = []
        self.opin_y = []
        self.ipin_net_id = []
        self.opin_net_id = []
        self.pstatus = None
        self.ipin_act_x_offset = []
        self.ipin_act_y_offset = []
        self.opin_act_y_offset = []
        self.opin_act_x_offset = []
        return

    def update_size(self, height, width):
        self.height = height
        self.width = width
        return
    
    def update_location(self, x, y, orient, pstatus = "UNPLACED"):
        self.llx = float(x)
        self.lly = float(y)
        self.orient = orient.upper()
        self.pstatus = pstatus.upper()
        return
    
    def update_center(self):
        self.cx = self.llx + self.width/2
        self.cy = self.lly + self.height/2
        return

    def connect_net(self, net_name, net_id, isInput, x_offset = 0.0, \
                    y_offset = 0.0 ):
        # If isInput is 1 means the connected pin is input pin
        # Check if the net exists:
        if isInput:
            if net_id in self.ipin_net_id:
                print(f"[INFO] [ERROR-1] Inst: {self.name} Net: {net_name}"\
                        " is alerady connected")
                return
        else:
            if net_id in self.opin_net_id:
                print(f"[INFO] [ERROR-2] Inst: {self.name} Net: {net_name}"\
                        " is alerady connected")
                return

        if isInput:
            pin_id = len(self.ipins) + 1
            self.ipins.append(f'IP{pin_id}')
            self.ipin_act_x_offset.append(x_offset)
            self.ipin_act_y_offset.append(y_offset)
            self.ipin_net_id.append(net_id)
        else:
            pin_id = len(self.opins) + 1
            self.opins.append(f'OP{pin_id}')
            self.opin_act_x_offset.append(x_offset)
            self.opin_act_y_offset.append(y_offset)
            self.opin_net_id.append(net_id)

    def update_pin_loc(self):
        for i in range(len(self.ipins)):
            pin_x, pin_y = find_pin_act_loc(self.cx, self.cy, \
                                            self.ipin_act_x_offset[i], \
                                            self.ipin_act_y_offset[i], \
                                            self.orient)
            self.ipin_x.append(pin_x)
            self.ipin_y.append(pin_y)

        for i in range(len(self.opins)):
            pin_x, pin_y = find_pin_act_loc(self.cx, self.cy, \
                                            self.opin_act_x_offset[i], \
                                            self.opin_act_y_offset[i], \
                                            self.orient)
            self.opin_x.append(pin_x)
            self.opin_y.append(pin_y)
        return


    def check_pins(self):
        for x_offset in self.ipin_act_x_offset + self.opin_act_x_offset:
            if round(x_offset,6) < round(-1*self.width/2.0,6) \
                or round(x_offset,6) > round(self.width/2,6):
                print(f"[INFO][ERROR] Cell:{self.name} Orient:{self.orient} has pin out of bbox")
                return

        for y_offset in self.ipin_act_y_offset + self.opin_act_y_offset:
            if round(y_offset,6) < round(-1*self.height/2.0,6) \
                or round(y_offset,6) > round(self.height/2,6):
                print(f"[INFO][ERROR] Cell:{self.name} Orient:{self.orient} has pin out of bbox")
                return
        return

    def update_isMacro(self, site_height):
        if self.height != site_height:
            self.isMacro = True
        else:
            self.isMacro = False
        return

    def update_master_id(self, idx):
        self.master_id = idx
        return

class master:
    def __init__(self, idx, name):
        self.id = idx
        self.name = name
        self.width = None
        self.height = None
        self.isMacro = None   # Considers macro if heigh is more than row height
        self.ipins = []
        self.opins = []
        self.ipin_act_x_offset = []
        self.ipin_act_y_offset = []
        self.opin_act_y_offset = []
        self.opin_act_x_offset = []
        return

    def update_master(self, inst):
        self.width = inst.width
        self.height = inst.height
        self.isMacro = inst.isMacro
        self.ipins = [x for x in inst.ipins]
        self.opins = [x for x in inst.opins]
        self.ipin_act_x_offset = [x for x in inst.ipin_act_x_offset]
        self.ipin_act_y_offset = [y for y in inst.ipin_act_y_offset]
        self.opin_act_x_offset = [x for x in inst.opin_act_x_offset]
        self.opin_act_y_offset = [y for y in inst.opin_act_y_offset]
        return

class port:
    def __init__(self, name):
        self.id = None
        self.name = name
        self.x = None
        self.y = None
        self.isInput = None
        self.net_id = None
        self.side = None
        self.px = None # Protobuf location
        self.py = None # Protobuf location
    
    def connect_net(self, net_id, net_name, isInput):
        if self.net_id != None:
            print(f"[INFO] [ERROR-3] {self.name} is connected. Check Net: {net_name}")
        
        self.net_id = net_id
        self.isInput = isInput
        return
    
    def update_id(self, idx):
        self.id = idx
        return

    def update_location(self, x, y):
        self.x = x
        self.y = y
        return
    
    def update_side(self, pt_x, pt_y, dx, dy):
        cond1 = pt_x - pt_y
        cond2 = pt_x/dx + pt_y/dy - 1
        if cond1 > 0:
            if cond2 > 0:
                self.side = "right"
                return
            else:
                self.side = "bottom"
                return
        else:
            if cond2 > 0:
                self.side = "top"
                return
            else:
                self.side = "left"
                return

    def update_protobuf_location(self, c2dx, c2dy, cox, coy, dx, dy, dd = 0):
        '''
        c2dx = core to die spacing along x axix
        c2dy = core to die spacing along y axix
        cox = core origin x
        coy = core origin y
        dx = core widht
        dy = core height
        '''
        die_llx = cox - c2dx[0]
        die_lly = coy - c2dy[0]
        die_dx = dx + sum(c2dx)
        die_dy = dy + sum(c2dy)
        
        X = self.x - die_llx
        Y = self.y - die_lly
        
        if self.side == None:
            self.update_side(X, Y, die_dx, die_dy)
        
        co_urx = cox + dx
        co_ury = coy + dy
        
        if self.side == "left":
            self.px = dd
        elif self.side == "right":
            self.px = dx - dd
        
        if self.side in ["left", "right"]:
            if self.y <= coy:
                ## Directly print py Considering Core origin (0, 0)
                self.py = dd
            elif self.y >= co_ury:
                self.py = dy - dd
            else:
                self.py = self.y - coy
        
        if self.side == "top":
            self.py = dy - dd
        elif self.side == "bottom":
            self.py = dd
        
        if self.side in ["top", "bottom"]:
            if self.x <= cox:
                self.px = dd
            elif self.x >= co_urx:
                self.px = dx - dd
            else:
                self.px = self.x - cox
        return

class net:
    def __init__(self, idx, name) -> None:
        self.id = idx
        self.name = name
        self.dtype = None
        self.did = None
        self.stypes = []
        self.sids = []
        return
    def add_driver(self, dtype, did):
        if self.did == None:
            self.dtype = dtype
            self.did = did
        else:
            print(f"[INFO][ERROR-4] Net has the driver id:{did} type:{dtype}")
        return
    
    def add_sink(self, stype, sid):
        if sid not in self.sids:
            self.sids.append(sid)
            self.stypes.append(stype)
        else:
            print(f"[INFO][ERROR-5] Net:{self.name} has the sink id:{sid} type:{stype}")      
        return

class row:
    def __init__(self, idx):
        self.id = idx
        self.llx = None
        self.lly = None
        self.urx = None
        self.ury = None
        self.orient = None
        self.site_count = None
        self.inst_ids = []
        return
    def update_llx(self, llx):
        self.llx = llx
        return
    def update_lly(self, lly):
        self.lly = lly
        return
    def update_site_count(self, count):
        if self.site_count == None:
            self.site_count = int(count)
            self.inst_ids = [None]*int(count)
        elif self.site_count != int(count):
            print(f"[INFO][ERROR-6] Row id: {self.id} check site count")
        return
    def update_orient(self, orient):
        if self.orient == None:
            self.orient = orient
        elif self.orient != orient:
            print(f"[INFO][ERROR-7] Row id: {self.id} multiple orient")
        return
    def update_size(self, swidth, sheight):
        self.urx = self.llx + self.site_count*swidth
        self.ury = self.lly + sheight
        return

class canvas_object:
    def __init__(self, name, unit = 100):
        self.design = name
        self.unit = float(unit)
        self.site_width = None
        self.site_height = None
        self.site_spacing = None
        self.core_llx = None
        self.core_lly = None
        self.core_urx = None
        self.core_ury = None
        self.core_dx = None
        self.core_dy = None
        self.die_llx = None
        self.die_lly = None
        self.die_urx = None
        self.die_ury = None
        self.die_dx = None
        self.die_dy = None
        self.row_count = None
        self.port_count = None
        self.inst_count = None
        self.pin_count = None
        self.net_count = None
        self.BookShelf_dir = None
        self.c2dx = []
        self.c2dy = []
        self.nets = []
        self.insts = []
        self.masters = []
        self.ports = []
        self.netMap = {}
        self.instMap = {}
        self.masterMap = {}
        self.portMap = {}
        self.pb_id = {}
        self.pb_type = {}
        self.rows = []
        return
    def init_core(self):
        self.core_llx = self.rows[0].llx
        self.core_lly = self.rows[0].lly
        self.core_urx = self.rows[0].urx
        self.core_ury = self.rows[0].ury
        return
    def init_die(self):
        self.die_llx = self.core_llx
        self.die_lly = self.core_lly
        self.die_urx = self.core_urx
        self.die_ury = self.core_ury
        return
    def update_c2d_spacing(self):
        self.c2dx.append(self.core_llx - self.die_llx)
        self.c2dx.append(self.die_urx - self.core_urx)
        self.c2dy.append(self.core_lly - self.die_lly)
        self.c2dy.append(self.die_ury - self.core_ury)
        return
    def print_core_details(self):
        print(f"Core llx:{self.core_llx} Core lly:{self.core_lly}")
        print(f"Core urx:{self.core_urx} Core ury:{self.core_ury}")
        print(f"Core dx:{self.core_dx} Core dy:{self.core_dy}")
        return
    def print_die_details(self):
        print(f"Die llx:{self.die_llx} Die lly:{self.die_lly}")
        print(f"Die urx:{self.die_urx} Die ury:{self.die_ury}")
        print(f"Die dx:{self.die_dx} Die dy:{self.die_dy}")
        return

    def check_inst_op(self, count, isPrint = False):
        _count = 0
        for _inst in self.insts:
            if len(_inst.opins) == count:
                _count += 1
                if isPrint:
                    print(f"Inst Name:{_inst.name} id:{_inst.id} Macro:{_inst.isMacro}")

        print(f"Total number of instances with {count} output pins is {_count}")
        return

    def report_macros(self, isPrint = False):
        _count = 0
        for _inst in self.insts:
            if _inst.isMacro:
                if isPrint:
                    print(f"Inst id:{_inst.id} name:{_inst.name}")
                _count += 1
        print(f"Total number of macro instances is {_count}")
        return

    def update_port_side(self):
        for _port in self.ports:
            _port.update_protobuf_location(self.c2dx, self.c2dy, self.core_llx,\
                self.core_lly, self.core_dx, self.core_dy, 0.5/self.unit)
        return
    
    def update_inst_type(self):
        for _inst in self.insts:
            _inst.update_isMacro(self.site_height)
        return

    def update_inst_pin_loc(self):
        for _inst in self.insts:
            _inst.update_pin_loc()
        return

    def check_inst_pins(self):
        for _inst in self.insts:
            _inst.check_pins()

    def read_scl(self, scl_file):
        '''
        This reads the design.scl file and updates the core information.

        This function updates the row information.
        '''
        scl_fp = open(scl_file, 'r')
        row_id = 0
    
        crow = None
        for line in scl_fp.readlines():
            if re.match(r"(^\s*#)|(^\s*UCLA\s*scl\s*1.0$)|(^\s*$)|(^\sEnd\s*$)", line):
                continue
            
            if re.match("^\s*CoreRow\s*Horizontal\s*$", line):
                self.rows.append(row(row_id))
                crow = self.rows[row_id]
                row_id += 1
                continue
            
            lly = re.findall(r"^\s*Coordinate\s*:\s*([0-9,-,\.]*)", line)
            sheight = re.findall(r"\s*Height\s*:\s*([0-9,-,\.]*)", line)
            swidth = re.findall(r"^\s*Sitewidth\s*:\s*([0-9,-,\.]*)", line)
            sorient = re.findall(r"^\s*Siteorient\s*:\s*([F, S, E, W, N]*)", line)
            llx = re.findall(r"^\s*SubrowOrigin\s*:\s*([0-9,-,\.]*)", line)
            sspacing = re.findall(r"^\s*Sitespacing\s*:\s*([0-9,-,\.]*)", line)
            numsites = re.findall(r"\s\s*Num[S,s]ites\s*:\s*([0-9]*)", line)

            if lly and lly[0] != "" :
                _lly = float(lly[0])/self.unit
                crow.update_lly(_lly)
            
            if sheight and sheight[0] != "":
                if self.site_height == None:
                    self.site_height = float(sheight[0])/self.unit
                elif self.site_height != float(sheight[0])/self.unit:
                    print(f"[INFO][ERROR-8] Row id:{row_id-1} site height is different")
            
            if swidth and swidth[0] != "":
                if self.site_width == None:
                    self.site_width = float(swidth[0])/self.unit
                elif self.site_width != float(swidth[0])/self.unit:
                    print(f"[INFO][ERROR-9] Row id:{row_id-1} site width is different")
            
            if sorient and sorient[0] != "":
                crow.update_orient(sorient[0])
            
            if llx and llx[0] != "":
                _llx = float(llx[0])/self.unit
                crow.update_llx(_llx)
            
            if sspacing and sspacing[0] != "":
                if self.site_spacing == None:
                    self.site_spacing = float(sspacing[0])/self.unit
                elif self.site_spacing != float(sspacing[0])/self.unit:
                    print(f"[INFO][ERROR-10] Row id:{row_id-1} site spacing is different")
            
            if numsites and numsites[0] != "":
                crow.update_site_count(numsites[0])
        
        self.rows[0].update_size(self.site_width, self.site_height)
        self.init_core()
        for _row in self.rows:
            _row.update_size(self.site_width, self.site_height)
            self.core_llx = min(self.core_llx, _row.llx)
            self.core_lly = min(self.core_lly, _row.lly)
            self.core_urx = max(self.core_urx, _row.urx)
            self.core_ury = max(self.core_ury, _row.ury)
        self.core_dx = self.core_urx - self.core_llx
        self.core_dy = self.core_ury - self.core_lly

        scl_fp.close()
        return

    def read_nodes(self, nodes_file):
        '''
        Read design.nodes file and updated the terminals and instances
        '''
        nodes_fp = open(nodes_file, 'r')
        node_count = None
        port_id = 0
        inst_id = 0
        terminal_count = None
        fixed_inst_count = 0
        for line in nodes_fp.readlines():
            if re.match(r"(^\s*#)|(^\s*UCLA\s*nodes\s*1.0$)|(^\s*$)", line):
                continue

            num_nodes = re.findall(r"^\s*NumNodes\s*:\s*([0-9]*)", line)
            if num_nodes and num_nodes[0] != "":
                node_count = int(num_nodes[0])
                if self.port_count != None:
                    self.inst_count = node_count - self.port_count
                continue

            num_terminal = re.findall(r"^\s*NumTerminals\s*:\s*([0-9]*)", line)
            if num_terminal and num_terminal[0] != "":
                terminal_count = int(num_terminal[0])
                continue

            items = line.split()
            # By default ports has 1 width and 1 height
            if len(items) == 4 and items[1] == "1" and items[2] == "1" and \
                items[3] in ['terminal', 'terminal_NI']:
                self.ports.append(port(items[0]))
                self.ports[-1].update_id(port_id)
                self.portMap[items[0]] = port_id
                port_id += 1
            elif (len(items) == 4 and items[3] == 'terminal') or \
                len(items) == 3:
                self.insts.append(instance(inst_id, items[0]))
                _height = float(items[2])/self.unit
                _width = float(items[1])/self.unit
                self.insts[-1].update_size(_height, _width)
                self.instMap[items[0]] = inst_id
                inst_id += 1
                if len(items) == 4 and items[3] == 'terminal':
                    fixed_inst_count += 1
        
        self.inst_count = inst_id
        self.port_count = port_id
        if port_id + inst_id != node_count:
            print(f"[INFO][ERROR-11] Mismatch in total number of nodes and read nodes")

        if terminal_count - fixed_inst_count != port_id:
            print(f"[INFO][ERROR-12] Mismatch in the port count and fixed instance count")
        
        nodes_fp.close()
        return

    def read_pl(self, pl_file):
        '''
        Read design.pl file and update the terminal and isntance locations
        '''
        pl_fp = open(pl_file, 'r')

        for line in pl_fp.readlines():
            if re.match(r"(^\s*#)|(^\s*UCLA\s*pl\s*1.0$)|(^\s*$)", line):
                continue
            items = line.split()

            _x = float(items[1])/self.unit
            _y = float(items[2])/self.unit
            _orient = items[4]

            if items[0] in self.portMap:
                port_id = self.portMap[items[0]]
                _port = self.ports[port_id]
                _port.update_location(_x, _y)
            elif items[0] in self.instMap:
                inst_id = self.instMap[items[0]]
                _inst = self.insts[inst_id]
                _pstatus = "UNPLACED"
                if len(items) == 6:
                    _pstatus = items[5]

                _inst.update_location(_x, _y, _orient, _pstatus)
                _inst.update_center()

        self.init_die()
        for _port in self.ports:
            self.die_llx = min(self.die_llx, _port.x)
            self.die_lly = min(self.die_lly, _port.y)
            self.die_urx = max(self.die_urx, _port.x)
            self.die_ury = max(self.die_ury, _port.y)

        self.die_dx = self.die_urx - self.die_llx
        self.die_dy = self.die_ury - self.die_lly
        self.update_c2d_spacing()
        self.update_port_side()
        self.update_inst_type()
        pl_fp.close()
        return

    def read_net_healper(self, line, net_name, net_id, isDriver):
        items = line.split()
        pname = items[0]
        ptype = None
        idx = None
        if items[0] in self.portMap:
            ptype = "port"
            idx = self.portMap[pname]
            self.ports[idx].connect_net(net_id, net_name, isDriver)
        else:
            ptype = "inst"
            idx = self.instMap[pname]
            _x_offset = float(items[3])/self.unit
            _y_offset = float(items[4])/self.unit
            self.insts[idx].connect_net(net_name, net_id, not isDriver, \
                                        _x_offset, _y_offset)
        
        if isDriver:
            self.nets[net_id].add_driver(ptype, idx)
        else:
            self.nets[net_id].add_sink(ptype, idx)
        return

    def read_nets(self, nets_file):
        '''
        Read design.nets file and add nets, pins and pin locations and pin typs.

        For each net we consider the first pin is the driver.
        '''
        nets_fp = open(nets_file, 'r')
        net_id = 0
        lines = nets_fp.readlines()
        no_lines = len(lines)
        i = 0
        while i < no_lines:
            if re.match(r"(^\s*#)|(^\s*UCLA\s*nets\s*1.0$)|(^\s*$)", lines[i]):
                i += 1
                continue

            num_nets = re.findall(r"^\s*NumNets\s*:\s*([0-9]*)", lines[i])
            num_pins = re.findall(r"^\s*NumPins\s*:\s*([0-9]*)", lines[i])

            if num_nets and num_nets[0] != "":
                self.net_count = int(num_nets[0])
                i += 1
                continue

            if num_pins and num_pins[0] != "":
                self.pin_count = int(num_pins[0])
                i += 1
                continue

            items = lines[i].split()
            net_degree = 0
            if items[0] == "NetDegree":
                ## Add net details ##
                net_degree = int(items[2])
                net_name = items[3]
                self.nets.append(net(net_id, net_name))
                self.netMap[net_name] = net_id
                i += 1

                ## SPins = Sinks DPins = Drivers BiPins = Bidrections ##
                SPins = []
                DPins = []
                BiPins = []
                for _ in range(net_degree):
                    items = lines[i].split()
                    if items[1] == 'I':
                        SPins.append(i)
                    elif items[1] == 'O':
                        DPins.append(i)
                    elif items[1] == 'B':
                        BiPins.append(i)
                    else:
                        print(f"[INFO][ERROR] Check net:{net_name} sink/driver not defined")
                    i += 1
                
                AckDriver = None
                if len(DPins) > 0:
                    AckDriver = DPins[0]
                    del DPins[0]
                elif len(BiPins) > 0:
                    AckDriver = BiPins[0]
                    del BiPins[0]
                elif len(SPins) > 0:
                    AckDriver = SPins[0]
                    del SPins[0]
                else:
                    print(f"[INFO][ERROR] Check net:{net_name} does not have driver and sink")
                
                self.read_net_healper(lines[AckDriver], net_name, net_id, True)
                for j in DPins + SPins + BiPins:
                    self.read_net_healper(lines[j], net_name, net_id, False)
                
                net_id += 1
        del lines
        nets_fp.close()
        self.update_inst_pin_loc()
        return

    def write_header(self, fp):
        user = os.environ["USER"]
        if self.BookShelf_dir == None:
            run_dir = os.environ["PWD"]
        else:
            run_dir = self.BookShelf_dir
        today = date.today()
        fp.write(f"# User: {user}\n")
        fp.write(f"# Date: {today}\n")
        fp.write(f"# Run area: {run_dir}\n")
        fp.write(f"# Block: {self.design}\n")
        fp.write("# FP bbox: {0.0 0.0} {" f"{self.core_dx} {self.core_dy}" "}\n")
        fp.write("# Columns : 10  Rows : 10\n")
        return

    def print_net(self, net_id, fp):
        no_sink = len(self.nets[net_id].sids)
        for i in range(no_sink):
            stype = self.nets[net_id].stypes[i]
            sid = self.nets[net_id].sids[i]
            if stype == "inst":
                inst_name = self.insts[sid].name
                if self.insts[sid].isMacro:
                    # print(f"inst id:{sid} net id:{net_id}")
                    idx = self.insts[sid].ipin_net_id.index(net_id)
                    pin_name = self.insts[sid].ipins[idx]
                    fp.write(f"  input: \"{inst_name}/{pin_name}\"\n")
                else:
                    fp.write(f"  input: \"{inst_name}\"\n")
            else:
                port_name = self.ports[sid].name
                fp.write(f"  input: \"{port_name}\"\n")
        return

    def write_node_port(self, port_id, fp):
        fp.write("node {\n")
        _port = self.ports[port_id]
        port_name = _port.name
        fp.write(f"  name: \"{port_name}\"\n")
        
        if _port.isInput:
            self.print_net(_port.net_id, fp)
        
        print_placeholder(fp, "type", "port")
        print_placeholder(fp, "side", _port.side)
        print_float(fp, "x", _port.px)
        print_float(fp, "y", _port.py)
        fp.write("}\n")
        return

    def write_node_macro(self, macro_id, fp):
        fp.write("node {\n")
        _macro = self.insts[macro_id]
        macro_name = _macro.name
        fp.write(f"  name: \"{macro_name}\"\n")

        print_float(fp, "width", _macro.width)
        print_float(fp, "height", _macro.height)
        print_placeholder(fp, "type", "macro")
        print_float(fp, "x", _macro.cx)
        print_float(fp, "y", _macro.cy)
        fp.write("}\n")
        return

    def write_node_macro_ipin(self, macro_id, pin_id, fp):
        fp.write("node {\n")
        _macro = self.insts[macro_id]
        macro_name = _macro.name
        pin_name = _macro.ipins[pin_id]
        fp.write(f"  name: \"{macro_name}/{pin_name}\"\n")
        print_placeholder(fp, "macro_name", macro_name)
        print_placeholder(fp, "type", "macro_pin")
        print_float(fp, "x_offset", _macro.ipin_act_x_offset[pin_id])
        print_float(fp, "y_offset", _macro.ipin_act_y_offset[pin_id])
        if len(_macro.ipin_x) > pin_id:
            print_float(fp, "x", _macro.ipin_x[pin_id])
            print_float(fp, "y", _macro.ipin_y[pin_id])
        fp.write("}\n")
        return

    def write_node_macro_opin(self, macro_id, pin_id, fp):
        fp.write("node {\n")
        _macro = self.insts[macro_id]
        macro_name = _macro.name
        pin_name = _macro.opins[pin_id]
        fp.write(f"  name: \"{macro_name}/{pin_name}\"\n")
        net_id = _macro.opin_net_id[pin_id]
        self.print_net(net_id, fp)
        print_placeholder(fp, "macro_name", macro_name)
        print_placeholder(fp, "type", "macro_pin")
        
        print_float(fp, "x_offset", _macro.opin_act_x_offset[pin_id])
        print_float(fp, "y_offset", _macro.opin_act_y_offset[pin_id])
        if len(_macro.opin_x) > pin_id:
            print_float(fp, "x", _macro.opin_x[pin_id])
            print_float(fp, "y", _macro.opin_y[pin_id])
        fp.write("}\n")
        return

    def write_node_stdcell(self, inst_id, fp):
        fp.write("node {\n")
        _inst = self.insts[inst_id]
        inst_name = _inst.name
        fp.write(f"  name: \"{inst_name}\"\n")

        for net_id in _inst.opin_net_id:
            self.print_net(net_id, fp)
        print_placeholder(fp, "type", "stdcell")
        print_float(fp, "width", _inst.width)
        print_float(fp, "height", _inst.height)
        print_float(fp, "x", _inst.cx)
        print_float(fp, "y", _inst.cy)
        fp.write("}\n")
        return

    def gen_pb_netlist(self, file_name=None):
        if file_name == None:
            if self.BookShelf_dir == None:
                file_name = f"{self.design}.pb.txt"
            else:
                file_name = f"{self.BookShelf_dir}/{self.design}.pb.txt"

        fp = open(file_name, "w")
        self.write_header(fp)
        for _port in self.ports:
            self.write_node_port(_port.id, fp)

        for _inst in self.insts:
            if _inst.isMacro:
                self.write_node_macro(_inst.id, fp)
                for i in range(len(_inst.ipins)):
                    self.write_node_macro_ipin(_inst.id, i, fp)

                for i in range(len(_inst.opins)):
                    self.write_node_macro_opin(_inst.id, i, fp)
            else:
                self.write_node_stdcell(_inst.id, fp)

        fp.close()
        print(f"Output protobuf netlist: {file_name}")
        return

    def read_BookShelf(self, dir, design = None):
        if design == None:
            design = self.design

        if os.path.exists(dir):
            self.BookShelf_dir = dir
        else:
            print(f"[INFO][ERROR-13] BookShelf dir does not exists.\nDIR:{dir}")
            return

        scl_file = f"{dir}/{design}.scl"
        if os.path.isfile(scl_file):
            print(f"Parsing: {scl_file}")
            self.read_scl(scl_file)
        else:
            print(f"[INFO][ERROR-14] Check file: \n{scl_file}")

        nodes_file = f"{dir}/{design}.nodes"
        if os.path.isfile(nodes_file):
            print(f"Parsing: {nodes_file}")
            self.read_nodes(nodes_file)
        else:
            print(f"[INFO][ERROR-15] Check file: \n{nodes_file}")

        pl_file = f"{dir}/{design}.pl"
        if os.path.isfile(pl_file):
            print(f"Parsing: {pl_file}")
            self.read_pl(pl_file)
        else:
            print(f"[INFO][ERROR-16] Check file: \n{pl_file}")

        nets_file = f"{dir}/{design}.nets"
        if os.path.isfile(nets_file):
            print(f"Parsing: {nets_file}")
            self.read_nets(nets_file)
        else:
            print(f"[INFO][ERROR-17] Check file: \n{nets_file}")
        
        for inst in self.insts:
            inst.name = inst.name.replace("\\","")
        
        for port in self.ports:
            port.name = port.name.replace("\\","")
        return

    def read_pb(self, pb_netlist):
        fp = open(pb_netlist, 'r')
        lines = fp.readlines()
        node_id = 0
        for line in lines:
            words = line.split()
            if words[0] == 'name:':
                node_name = words[1].replace('"','')
                if node_name == "__metadata__":
                    continue

                if node_name in self.portMap:
                    self.pb_id[node_id] = self.portMap[node_name]
                    self.pb_type[node_id] = "port"
                elif node_name in self.instMap:
                    self.pb_id[node_id] = self.instMap[node_name]
                    self.pb_type[node_id] = "inst"
                else:
                    self.pb_type[node_id] = "other"
                node_id += 1
        return
    
    def read_plc(self, plc_file):
        fp = open(plc_file, 'r')
        lines = fp.readlines()
        id_pattern = re.compile("[0-9]+")
        for line in lines:
            words = line.split()
            if id_pattern.match(words[0]) and (len(words) == 5):
                idx = int(words[0])
                if self.pb_type[idx] == "inst":
                    if self.insts[self.pb_id[idx]].isMacro:
                        self.insts[self.pb_id[idx]].cx = float(words[1])
                        self.insts[self.pb_id[idx]].cy = float(words[2])
                        self.insts[self.pb_id[idx]].pstatus = "FIXED"
        return
    
    def write_node(self, node_file = None):
        if node_file == None:
            node_file = f"{self.BookShelf_dir}/{self.design}.updated.nodes"
        
        fp = open(node_file, "w")
        today = date.today()
        user = user = os.environ["USER"]
        fp.write("UCLA nodes 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")
        total_nodes = len(self.insts) + len(self.ports)
        total_fixed_instance = 0
        for inst in self.insts:
            if inst.pstatus == "FIXED":
                total_fixed_instance += 1
        
        total_terminals = len(self.ports) + total_fixed_instance

        fp.write(f"NumNodes : {total_nodes}\nNumTerminals : {total_terminals}\n")
        for port in self.ports:
            fp.write(f"  {port.name}  1  1 terminal\n")
        for inst in self.insts:
            height = round(inst.height * self.unit, 6)
            width = round(inst.width * self.unit, 6)
            eol = ""
            if inst.pstatus == "FIXED":
                eol = "terminal"
            fp.write(f"  {inst.name}  {width}  {height}  {eol}\n")
        fp.close()
        return

    def write_pl(self, pl_file = None):
        if pl_file == None:
            pl_file = f"{self.BookShelf_dir}/{self.design}.updated.pl"
        
        fp = open(pl_file, "w")
        today = date.today()
        user = user = os.environ["USER"]
        fp.write("UCLA pl 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")

        for port in self.ports:
            px = port.x * self.unit
            py = port.y * self.unit
            fp.write(f"  {port.name}  {px}  {py} : N /FIXED\n")
        
        for inst in self.insts:
            px = (inst.cx - (inst.width * 0.5)) * self.unit
            py = (inst.cy - (inst.height * 0.5)) * self.unit
            eol = ""
            if inst.pstatus == "FIXED":
                eol = "/FIXED"
            else:
                px = (self.core_dx*0.5 - (inst.width * 0.5)) * self.unit
                px = (self.core_dy*0.5 - (inst.width * 0.5)) * self.unit

            px = round(px, 6)
            py = round(py, 6)
            fp.write(f"  {inst.name}  {px}  {py} : N {eol}\n")
        
        fp.close()


