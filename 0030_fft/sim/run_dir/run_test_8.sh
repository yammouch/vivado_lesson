# A script to run testcase for Icarus Verilog.
# usage: sh run_test.sh t000

iverilog \
 -g2001 \
 -o intermediate/$1.vvp \
 -I ../common \
 ../common/tb_clk_gen.v \
 ../../rtl/cmplxmul.v \
 ../../rtl/halfrate.v \
 ../../rtl/stage1.v \
 ../../rtl/fft_3_8.v \
 ../scenario/$1.v

if [ $? -eq 0 ] ; then
  vvp intermediate/$1.vvp
fi
