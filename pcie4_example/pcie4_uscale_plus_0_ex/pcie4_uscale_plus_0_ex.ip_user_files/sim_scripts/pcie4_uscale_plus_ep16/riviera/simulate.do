onbreak {quit -force}
onerror {quit -force}

asim -t 1ps +access +r +m+pcie4_uscale_plus_ep16 -L xil_defaultlib -L xpm -L gtwizard_ultrascale_v1_7_4 -L unisims_ver -L unimacro_ver -L secureip -O5 xil_defaultlib.pcie4_uscale_plus_ep16 xil_defaultlib.glbl

do {wave.do}

view wave
view structure

do {pcie4_uscale_plus_ep16.udo}

run -all

endsim

quit -force
