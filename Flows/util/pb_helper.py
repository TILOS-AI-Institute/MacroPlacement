import shutil
import re
import os
from datetime import date, datetime
import matplotlib.pyplot as plt

class node:
  def __init__(self, id):
    self.name = None
    self.sinks = set()
    self.sink_ids = set()
    self.node_id = id
    self.height = 0
    self.width = 0
    self.weight = None
    self.x = -1
    self.x_offset = None
    self.y = -1
    self.y_offset = None
    self.macro_name = None
    self.macro_id = None
    self.type = None
    self.side = None
    self.orientation = None

class plc_info:
    def __init__(self, design):
        self.design = design
        self.date = datetime.now()
        self.columns = 0
        self.rows = 0
        self.width = 0.0
        self.height = 0.0
        self.area = 0.0
        self.route_hor = 0.0
        self.route_ver = 0.0
        self.macro_route_hor = 0.0
        self.macro_route_ver = 0.0
        self.sm_factor = 0
        self.ovrlp_thrshld = 0.0
    def plc_info_print(self, out_plc_fp):
        out_plc_fp.write("# Placement file for Circuit Training\n")
        out_plc_fp.write(f"# Date : {self.date}\n")
        out_plc_fp.write(f"# Columns : {self.columns}  Rows : {self.rows}\n")
        out_plc_fp.write(f"# Width : {self.width}  Height : {self.height}\n")
        out_plc_fp.write(f"# Area : {self.area}\n")
        out_plc_fp.write(f"# Block : {self.design}\n")
        out_plc_fp.write(f"# Routes per micron, hor : {self.route_hor}  ver : {self.route_ver}\n")
        out_plc_fp.write(f"# Routes used by macros, hor : {self.macro_route_hor}  ver : {self.macro_route_ver}\n")
        out_plc_fp.write(f"# Smoothing factor : {self.sm_factor}\n")
        out_plc_fp.write(f"# Overlap threshold : {self.ovrlp_thrshld}\n")
        

class pb_design:
    def __init__(self, design, netlist, unit = 100, site_height = 16, \
                site_width = 1):
        self.design = design
        self.netlist_path = netlist
        self.node_list = []
        self.node_name_to_id = {}
        self.key1 = ['"height"', '"weight"', '"width"', '"x"', '"x_offset"', \
                    '"y"', '"y_offset"']
        self.key2 = ['"macro_name"', '"orientation"', '"side"', '"type"']
        self.node_count = 0
        self.net_weights = []
        self.unit = unit ## For bookshelf
        self.site_height = site_height
        self.site_width = site_width
        self.plc_info = plc_info(design)
    
    def read_netlist(self):
        fp = open(self.netlist_path, "r")
        lines = fp.readlines()
        fp.close()
        node_id = 0
        key = ""
        for line in lines:
            words = line.split()
            if words[0] == 'node':
            ## TODO: Check if the node name is __metadata__ then remove it ##
                if len(self.node_list) > 0 and \
                    self.node_list[-1].name == '__metadata__':
                    self.node_list.pop(-1)
                
                self.node_list.append(node(node_id))
                node_id += 1
            elif words[0] == 'name:':
                self.node_list[-1].name = words[1].replace('"', '')
            elif words[0] == 'input:':
                self.node_list[-1].sinks.add(words[1].replace('"', ''))
            elif words[0] == 'key:':
                key = words[1]
            elif words[0] == 'placeholder:' :
                words[1] = words[1].replace('"', '')
                if key == self.key2[0]:
                    self.node_list[-1].macro_name = words[1]
                elif key == self.key2[1]:
                    self.node_list[-1].orientation = words[1]
                elif key == self.key2[2]:
                    self.node_list[-1].side = words[1]
                elif key == self.key2[3]:
                    self.node_list[-1].type = words[1]
                else:
                    print(f'Do not support Key: {key}')
            elif words[0] == "f:":
                if key == self.key1[0]:
                    self.node_list[-1].height = float(words[1])
                elif key == self.key1[1]:
                    self.node_list[-1].weight = int(float(words[1]))
                elif key == self.key1[2]:
                    self.node_list[-1].width = float(words[1])
                elif key == self.key1[3]:
                    self.node_list[-1].x = float(words[1])
                elif key == self.key1[4]:
                    self.node_list[-1].x_offset = float(words[1])
                elif key == self.key1[5]:
                    self.node_list[-1].y = float(words[1])
                elif key == self.key1[6]:
                    self.node_list[-1].y_offset = float(words[1])
        ## Update the Name to id map ##
        self.node_count = len(self.node_list)
        for i in range(self.node_count):
            self.node_name_to_id[self.node_list[i].name] = i

        ## Update sink list and sink id ##
        self.read_netlist_post_processing()
        return

    def read_netlist_post_processing(self):
        for i in range(self.node_count):
            ## Update the sink list ##
            for sink in self.node_list[i].sinks:
                self.node_list[i].sink_ids.add(self.node_name_to_id[sink])
            
            ## Update the macro id ##
            if self.node_list[i].type in {'MACRO_PIN', 'macro_pin'}:
                self.node_list[i].macro_id = \
                    self.node_name_to_id[self.node_list[i].macro_name]
            
            ## TODO: Update the macro pin location based on macro orientation ##
        return

    def print_helper (self, fp, key, value, isPlaceHolder):
        fp.write("  attr {\n")
        fp.write(f"    key: \"{key}\"\n")
        fp.write("    value {\n")
        if isPlaceHolder:
            fp.write(f"      placeholder: \"{value}\"\n")
        else:
            fp.write(f"      f: {value}\n")
        fp.write("    }\n")
        fp.write("  }\n")
        return

    def print_float(self, fp, key, value):
        self.print_helper(fp, key, value, 0)

    def print_placeholder(self, fp, key, value):
        self.print_helper(fp, key, value, 1)    

    def print_macro(self, fp, node: node):
        if node.type not in {'MACRO', 'macro'}:
            return
        
        fp.write("node {\n")
        fp.write(f"  name: \"{node.name}\"\n")
        self.print_placeholder(fp, "type", node.type)
        self.print_float(fp, "width", node.width)
        self.print_float(fp, "height", node.height)
        self.print_float(fp, "x", node.x)
        self.print_float(fp, "y", node.y)
        if node.orientation != None:
            self.print_placeholder(fp, "orientation", node.orientation)
        fp.write("}\n")
        return
    
    def print_macro_pin(self, fp, node: node):
        if node.type not in {'MACRO_PIN', 'macro_pin'}:
            return
        fp.write("node {\n")
        fp.write(f"  name: \"{node.name}\"\n")
        for sink in node.sinks:
            fp.write(f"  input: \"{sink}\"\n")
        
        self.print_placeholder(fp, "macro_name", f"{node.macro_name}")
        self.print_placeholder(fp, "type", f"{node.type}")
        self.print_float(fp, "x_offset", node.x_offset)
        self.print_float(fp, "y_offset", node.y_offset)
        self.print_float(fp, "x", node.x)
        self.print_float(fp, "y", node.y)
        if node.weight != None:
            self.print_float(fp, "weight", node.weight)
        fp.write("}\n")
        return
    
    def print_port(self, fp, node: node):
        if node.type not in {'PORT', 'port'}:
            return
        
        fp.write("node {\n")
        fp.write(f"  name: \"{node.name}\"\n")
        for sink in node.sinks:
            fp.write(f"  input: \"{sink}\"\n")
        self.print_placeholder(fp, "side", node.side)
        self.print_placeholder(fp, "type", node.type)
        self.print_float(fp, "x", node.x)
        self.print_float(fp, "y", node.y)
        fp.write("}\n")
        return

    def get_net_counts(self):
        net_count = 0
        pin_count = 0
        for node in self.node_list:
            if node.sinks:
                net_count += 1
                pin_count += len(node.sinks) + 1
        return net_count, pin_count
    
    def print_node(self, fp, node):
        if node.type in {'MACRO', 'macro'}:
            self.print_macro(fp, node)
        elif node.type == 'PORT':
            self.print_port(fp, node)
        elif node.type in {'MACRO_PIN', 'macro_pin'}:
            self.print_macro_pin(fp, node)
        return

    def write_nets(self, out_dir):
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
        net_id = 0
        for node in self.node_list:
            if not node.sinks:
                continue
            fp = open(f'{out_dir}/net{net_id}.pb.txt', "w")
            pnodes = []
            pnodes.append(node)
            self.print_node(fp, node)
            for sink_id in node.sink_ids:
                sink_node = self.node_list[sink_id]
                if sink_node not in pnodes:
                    pnodes.append(sink_node)
                    self.print_node(fp, sink_node)
                if sink_node.type in {'MACRO_PIN', 'macro_pin'}:
                    macro_node = self.node_list[sink_node.macro_id]
                    if macro_node not in pnodes:
                        pnodes.append(macro_node)
                        self.print_node(fp, macro_node)
            net_id += 1
            if net_id % 1000 == 0:
                print(f'{net_id}..', end=" ")
        return
    
    def write_hard_macro(self, out_dir):
        if not os.path.exists(out_dir):
            os.makedirs(out_dir)
        fp = open(f'{out_dir}/macro.pb.txt', "w")
        
        for node in self.node_list:
            if node.type == 'MACRO':
                self.print_node(fp, node)
        
        fp.close()
        return

    def read_bookshelf_pl_and_update_top_ports(self, pl_file, updatePort = True,\
                                        updateMacro = False ):
        if not os.path.exists(pl_file):
            print("[ERROR] pl file does not exists. Check the below file path:"\
                f"\n{pl_file}")
            return
        pl_fp = open(pl_file, 'r')
        
        for line in pl_fp.readlines():
            if re.match(r"(^\s*#)|(^\s*UCLA\s*pl\s*1.0\s*$)|(^\s*$)", line):
                continue
            items = line.split()
            
            name = items[0]
            _x = float(items[1])/self.unit
            _y = float(items[2])/self.unit
            if name in self.node_name_to_id:
                node_id = self.node_name_to_id[name]
                if updatePort and self.node_list[node_id].type == "PORT":
                    self.node_list[node_id].x = _x
                    self.node_list[node_id].y = _y
                elif updateMacro and self.node_list[node_id].type in ['MACRO', 'macro']:
                    self.node_list[node_id].x = _x + self.node_list[node_id].width/2
                    self.node_list[node_id].y = _y + self.node_list[node_id].height/2
        pl_fp.close()
        return
    def update_plc_info(self, line):
        items = line.split() 
        if len(items) > 6 and items[1] == 'Columns':
            self.plc_info.columns = int(items[3])
            self.plc_info.rows = int(items[6])
        elif len(items) > 6 and items[1] == 'Width':
            self.plc_info.width = float(items[3])
            self.plc_info.height = float(items[6])
        elif len(items) > 3 and items[1] == 'Area':
            self.plc_info.area = float(items[3])
        elif len(items) > 9 and items[1] == 'Routes' and items[2] == 'per':
            self.plc_info.route_hor = float(items[6])
            self.plc_info.route_ver = float(items[9])
        elif len(items) > 10 and items[1] == 'Routes' and items[2] == 'used':
            self.plc_info.macro_route_hor = float(items[7])
            self.plc_info.macro_route_ver = float(items[10])
        elif len(items) > 4 and  items[1] == 'Smoothing':
            self.plc_info.sm_factor = int(items[4])
        elif len(items) > 4 and items[1] == 'Overlap':
            self.plc_info.ovrlp_thrshld = float(items[4])
        return
        
    def read_plc(self, plc_file, updatePort = False, updateMacro = True):
        if not os.path.exists(plc_file):
            print("[ERROR] *.plc file does not exist. Chec the file path:\n"\
                  f"{plc_file}")
            return

        plc_fp = open(plc_file, 'r')
        
        for line in plc_fp.readlines():
            ## If the line starts with # the ignore it. Also ignore empty lines 
            if re.match(r"(^\s*#)|(^\s*$)", line):
                self.update_plc_info(line)
                continue
            items = line.split()
            node_id = int(items[0])
            
            if updatePort and self.node_list[node_id].type in ["PORT", "port"]:
                self.node_list[node_id].x = float(items[1])
                self.node_list[node_id].y = float(items[2])
            
            ## Update only soft macro and hardmacro locations ##
            elif updateMacro and self.node_list[node_id].type in ["MACRO", "macro"]:
                self.node_list[node_id].x = float(items[1])
                self.node_list[node_id].y = float(items[2])
                self.node_list[node_id].orientation = items[3]
            
        plc_fp.close()
        return

    def write_plc(self, output_plc_file):
        plc_fp = open(output_plc_file, 'w')
        self.plc_info.plc_info_print(plc_fp)
        idx = 0
        
        for node in self.node_list:
            x = round(node.x, 6)
            y = round(node.y, 6)
            if node.type in ['PORT', 'port']:
                plc_fp.write(f"{idx} {x} {y} - 1\n")
            elif node.type in ['MACRO', 'macro']:
                if node.orientation != None:
                    plc_fp.write(f"{idx} {x} {y} {node.orientation} 0\n")
                else:
                    plc_fp.write(f"{idx} {x} {y} N 0\n")
            idx += 1
        
        plc_fp.close()
        return
    
    def write_bookshelf_nodes(self, node_file):
        fp = open(node_file, "w")
        today = date.today()
        user = user = os.environ["USER"]
        fp.write("UCLA nodes 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")
        
        total_nodes = 0
        total_terminals = 0
        ## Here we consider only ports as the fixed terminals
        for node in self.node_list:
            if node.type in ['MACRO', 'macro', 'PORT', 'port']:
                total_nodes += 1
            
            if node.type in ['PORT', 'port']:
                total_terminals += 1
        
        fp.write(f"NumNodes : {total_nodes}\nNumTerminals : {total_terminals}\n")
        
        for node in self.node_list:
            if node.type in ['PORT', 'port']:
                fp.write(f"  {node.name}  1  1 terminal\n")
            elif node.type == 'MACRO':
                height = round(node.height * self.unit, 6)
                width = round(node.width * self.unit, 6)
                fp.write(f"  {node.name}  {width}  {height}\n")
            elif node.type == 'macro':
                height = round(node.height * self.unit, 6)
                width = round(node.width * self.unit, 6)
                area = height*width
                ack_height = round(height/self.site_height, 0)*self.site_height
                ack_height = round(ack_height, 6)
                if ack_height == 0:
                    ack_height = self.site_height
                    #print(f"Name:{node.name} Width:{node.width} Height:{node.height}")
                ack_width = round(area/ack_height, 6)
                node.height = ack_height/self.unit
                node.width = ack_width/self.unit
                fp.write(f"  {node.name}  {ack_width}  {ack_height}\n")
        fp.close()
        return

    def get_node_name(self, node):
        if node.type in ['PORT', 'port']:
            return node.name, None, None
        
        if node.type in ['macro_pin', 'MACRO_PIN']:
            return node.macro_name, round(node.x_offset*self.unit, 6), \
                round(node.y_offset*self.unit, 6)
        
        return None, None, None
        
    def write_bookshelf_nets(self, net_file):
        fp = open(net_file, 'w')
        today = date.today()
        user = os.environ["USER"]
        fp.write("UCLA nets 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")
        
        net_count, pin_count = self.get_net_counts()
        fp.write(f"NumNets : {net_count}\nNumPins : {pin_count}\n")
        
        net_id = 0
        for node in self.node_list:
            if node.sinks:
                net_w = 1
                net_degree = len(node.sinks) + 1
                if node.weight != None:
                    net_w = node.weight
                for _ in range(net_w):
                    ## Print the driver ##
                    fp.write(f"NetDegree : {net_degree} net{net_id}\n")
                    driver_name, x_offset, y_offset = self.get_node_name(node)
                    if x_offset != None and y_offset != None:
                        fp.write(f"    {driver_name} O  :  {x_offset} {y_offset}\n")
                    else:
                        fp.write(f"    {driver_name} O\n")
                    
                    ## Print the sinks ##
                    for sink_name in node.sinks:
                        sink_node = self.node_list[self.node_name_to_id[sink_name]]
                        sink_name, x_offset, y_offset = self.get_node_name(sink_node)
                        if x_offset != None and y_offset != None:
                            fp.write(f"    {sink_name} I  :  {x_offset} {y_offset}\n")
                        else:
                            fp.write(f"    {sink_name} I\n")
                    net_id += 1
        fp.close()
        return
    
    def write_bookshelf_pl(self, pl_file):
        fp = open(pl_file, 'w')
        today = date.today()
        user = os.environ["USER"]
        fp.write("UCLA pl 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")
        
        for node in self.node_list:
            if node.type in ['PORT', 'port']:
                px = round(node.x * self.unit, 6)
                py = round(node.y * self.unit, 6)
                fp.write(f"  {node.name}  {px}  {py} : N /FIXED\n")
            elif node.type in ['MACRO', 'macro']:
                width = node.width
                height = node.height
                x = (node.x - width/2) * self.unit 
                y = (node.y - height/2) * self.unit
                x = round(x, 6)
                y = round(y, 6)
                fp.write(f" {node.name}  {x}  {y} : N\n")
    
        fp.close()
        return
    
    def write_bookshelf_wts(self, wts_file):
        fp = open(wts_file, 'w')
        today = date.today()
        user = os.environ["USER"]
        fp.write("UCLA wts 1.0\n")
        fp.write(f"# Created : {today}\n")
        fp.write(f"# User: {user}\n\n")
        
        for node in self.node_list:
            if node.type in ['PORT', 'port']:
                fp.write(f"    {node.name}    0\n")
            elif node.type in ['MACRO', 'macro']:
                area = round(node.height * node.width * self.unit * self.unit, 0)
                fp.write(f"    {node.name}    {area}\n")
        fp.close()
        return
        
        
    ## Create output_dir/design directory and write out *nets, *.nodes, *.pl
    ## *.wts and copy *.aux and *.scl to the output_dir/design directory
    def write_bookshelf(self, input_bookshelf_dir, output_dir):
        if not os.path.exists(input_bookshelf_dir):
            print("[ERROR] The input Bookshelf directory path does not"\
                f"exists.\nPath:{input_bookshelf_dir}")
            return
        
        ## Read the *.pl file and update the port locations
        pl_input = f"{input_bookshelf_dir}/{self.design}.pl"
        self.read_bookshelf_pl_and_update_top_ports(pl_input)
        
        output_bookshelf_dir = f"{output_dir}/{self.design}"
        if not os.path.exists(output_bookshelf_dir):
            os.makedirs(output_bookshelf_dir)
        
        ## Copy the *.aux, *.scl and *.wts files ##
        src_pref = f"{input_bookshelf_dir}/{self.design}"
        dst_pref = f"{output_bookshelf_dir}/{self.design}"
        shutil.copy(f"{src_pref}.aux", f"{dst_pref}.aux")
        shutil.copy(f"{src_pref}.scl", f"{dst_pref}.scl")
        
        
        ## Write out the *.nets *.nodes and *.pl file ##
        nets_file = f"{dst_pref}.nets"
        nodes_file = f"{dst_pref}.nodes"
        pl_file = f"{dst_pref}.pl"
        wts_file = f"{dst_pref}.wts"
        self.write_bookshelf_nodes(nodes_file)
        self.write_bookshelf_nets(nets_file)
        self.write_bookshelf_pl(pl_file)
        self.write_bookshelf_wts(wts_file)
        return
    def visualize_placement(self):
        plt.figure(constrained_layout=True,figsize=(8,5),dpi=600)
        for node in self.node_list:
            if node.type == 'macro':
                color = 'red'
            elif node.type == 'MACRO':
                color = 'blue'
            else:
                continue
            
            lx = node.x - node.width/2.0
            ly = node.y - node.height/2.0
            width = node.width
            height = node.height
            rectangle = plt.Rectangle((lx, ly), width, height, fc = color, ec = "black")
            plt.gca().add_patch(rectangle)
        canvas_width = self.plc_info.width
        canvas_height = self.plc_info.height
            # Add boundries
        lx = 0.0
        ly = 0.0
        ux = lx + canvas_width
        uy = ly + canvas_height
        lw = 5.0

        x = []
        y = []
        x.append(lx)
        y.append(ly)
        x.append(ux)
        y.append(ly)
        plt.plot(x,y, '-k', lw = lw)

        x = []
        y = []
        x.append(lx)
        y.append(uy)
        x.append(ux)
        y.append(uy)
        plt.plot(x,y, '-k', lw = lw)


        x = []
        y = []
        x.append(lx)
        y.append(ly)
        x.append(lx)
        y.append(uy)
        plt.plot(x,y, '-k', lw = lw)


        x = []
        y = []
        x.append(ux)
        y.append(ly)
        x.append(ux)
        y.append(uy)
        plt.plot(x,y, '-k', lw = lw)

        plt.xlim(lx, ux)
        plt.ylim(ly, uy)
        plt.axis("scaled")
        plt.show()
        return
##############################################################################
if __name__ == "__main__":
    pb_file = ''

    plc = pb_design(pb_file)
    plc.read_netlist()

    plc.write_hard_macro('ariane_macro')