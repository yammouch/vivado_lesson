# c:\Xilinx\Vivado\2019.2\settings.64.bat
# vivado -mode batch -source this_file -log log_file_name
############################################################
# Create Top Project

set project_name "default_net_cui_syn"

# exec rm -rf ${project_name}
if { [ file exists ${project_name}/${project_name}.xpr ] == 1 } then {
  # Open Project
  open_project ${project_name}/${project_name}.xpr
  update_compile_order -fileset sources_1
} else {
  # Create Project
  #create_project ${project_name} ./${project_name} -part xcvu9p-flga2577-1-e
  create_project ${project_name} ./${project_name} -part xcku3p-ffva676-1-e

  set d ../rtl
  # Read Source
  read_verilog $d/default_net.v
  update_compile_order -fileset sources_1
}

############################################################

# Synthesis
launch_runs synth_1 -jobs 8
wait_on_run synth_1

# Save checkpoint
open_run synth_1 -name synth_1
write_checkpoint -force ${project_name}_synth.dcp

# Close Project
close_project

