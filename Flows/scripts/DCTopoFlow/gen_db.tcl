##################################################################
# Portions Copyright 2022 Synopsys, Inc. All rights reserved.
# Portions of these TCL scripts are proprietary to and owned
# by Synopsys, Inc. and may only be used for internal use by
# educational institutions (including United States government
# labs, research institutes and federally funded research and
# development centers) on Synopsys tools for non-profit research,
# development, instruction, and other non-commercial uses or as
# otherwise specifically set forth by written agreement with
# Synopsys. All other use, reproduction, modification, or
# distribution of these TCL scripts is strictly prohibited.
##################################################################

# Actual lib path is ${lib_path}/${lib_name}.lib
set lib_path ""
set lib_name ""

# Output *.db file is ${db_path}/${db_path}.db
set db_path ""

read_lib ${lib_path}/${lib_name}.lib
check_library
write_lib [get_object_name [get_libs]] -output ${db_path}/${db_path}.db
exit