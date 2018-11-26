onbreak {quit -f}
onerror {quit -f}

vsim -t 1ps -lib xil_defaultlib pcie4_uscale_plus_ep16_opt

do {wave.do}

view wave
view structure
view signals

do {pcie4_uscale_plus_ep16.udo}

run -all

quit -force
