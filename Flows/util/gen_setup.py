import os
import re
import sys

def gen_setup(run_dir, output_dir):
    design_setup = f'{run_dir}/design_setup.tcl'
    lib_setup = f'{run_dir}/lib_setup.tcl'

    fp = open(design_setup, "r")
    lines = fp.readlines()
    fp.close()

    design = ''
    site = ''
    halo_width = ''
    netlist_file = ''
    def_file = ''

    for line in lines:
        words = line.split()
        if len(words) == 3 and words[0] == 'set':
            if words[1] == 'DESIGN':
                design = words[2]
                design = design.replace('"','')
            elif words[1] == 'SITE':
                site = words[2]
                site = site.replace('"','')
            elif words[1] == 'HALO_WIDTH':
                halo_width = int(words[2])

    ### Other inputs lef and def ###
    def_file = f'{run_dir}/def/{design}.def'
    if not os.path.isfile(def_file):
        print(f'Def: {def_file} do not exists.')

    netlist_file = f'{run_dir}/def/{design}.v'
    if not os.path.exists(netlist_file):
        print(f'Netlist: {netlist_file} does not exists.')

    tmp_dir = os.getcwd()
    os.chdir(run_dir)
    ### Extract details of libs and lef ###
    fp = open(lib_setup, 'r')
    lines = fp.readlines()
    fp.close()
    lefdir = ''
    libdir = ''
    lib_files = []
    lef_files = []
    lefflag = False
    libflag = False
    for line in lines:
        words = line.split()
        if len(words) >= 3 and words[0] == 'set':
            if words[1] == 'lefdir':
                lefdir = words[2]
                lefdir = lefdir.replace('"', '')
            elif words[1] == 'libdir':
                libdir = words[2]
                libdir = libdir.replace('"','')
            elif words[1] == 'lefs':
                if words[2] == '"':
                    lefflag = True
                    libflag = False
                else:
                    lef_files = words[2]
            elif words[1] == 'libworst':
                if words[2] == '"':
                    lefflag = False
                    libflag = True
                elif 'glob' in words[2]:
                    for lib_file in os.listdir(libdir):
                        lib_files.append(libdir+'/'+lib_file)
        elif lefflag:
            words = line.split()
            if words[0] == '"':
                lefflag = False
            else:
                lef_file = re.search(r'([^\/]+\.(lef|tlef))', line)
                if lef_file != None:
                    lef_files.append(lefdir+'/'+lef_file.group())
        elif libflag:
            words = line.split()
            if words[0] == '"':
                libflag = False
            else:
                lib_file = re.search(r'([^\/]+\.lib)', line)
                if lib_file != None:
                    lib_files.append(libdir+'/'+lib_file.group())
    os.chdir(tmp_dir)
    ### Write out Setup ###
    if not os.path.exists(output_dir):
        os.makedirs(output_dir)
    fp = open(output_dir+'/setup.tcl', 'w')
    
    fp.write(f'set design \"{design}\"\n')
    fp.write(f'set top_design \"{design}\"\n')
    fp.write(f'set netlist \"{netlist_file}\"\n')
    fp.write(f'set def_file \"{def_file}\"\n')
    fp.write(f'set ALL_LEFS \"\n')
    for lef_file in lef_files:
        fp.write(f'    {lef_file}\n')
    fp.write(f'\"\n')
    
    fp.write(f'set LIB_BC \"\n')
    for lib_file in lib_files:
        fp.write(f'    {lib_file}\n')
    fp.write(f'\"\n')

    fp.write(f'set site \"{site}\"\n')
    fp.write('''foreach lef_file ${ALL_LEFS} {
    read_lef $lef_file
}
foreach lib_file ${LIB_BC} {
    read_liberty $lib_file
}''')
    fp.close

    work_dir = re.search(r'(/\S+/MacroPlacement)', os.path.abspath(run_dir)).group(1)
    return design, halo_width, work_dir, output_dir+'/setup.tcl'


if __name__ == "__main__":
    run_dir = sys.argv[1]
    output_dir = sys.argv[2]

    a, b, c, d = gen_setup(run_dir, output_dir)
    print(a, b, c, d)

