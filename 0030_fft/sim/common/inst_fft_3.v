wire clk;
reg  rstx;
reg  clear;
reg  din;
reg  dout;

tb_clk_gen cg(.clk(clk));

fft_3 dut (
 .clk   (clk),
 .rstx  (rstx),
 .clear (clear),
 .din   (din),
 .dout  () );
