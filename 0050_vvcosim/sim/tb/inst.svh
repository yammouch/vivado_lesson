wire       clk;
reg        rstx;
reg  [3:0] din;

tb_clk_gen cg(.CLK(clk));

add1 dut ( 
 .clk  (clk),
 .rstx (rstx),
 .din  (din),
 .dout ()
);
