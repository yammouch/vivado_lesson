module syn_top (
 input  clk,
 input  din_0,
 input  din_1,
 input  din_2,
 input  din_3,
 output dout_0,
 output dout_1,
 output dout_2,
 output dout_3 );

bus bus_1(), bus_2(), bus_3();

assign bus_1.d0 = din_0;
assign bus_1.d1 = din_1;
assign bus_1.d2 = {din_3, din_2};

assign dout_0 = bus_3.d0;
assign dout_1 = bus_3.d1;
assign {dout_3, dout_2} = bus_3.d2;

stage1 stage1_1 (
 .clk    (clk),
 .din    (bus_1),
 .dout   (bus_2) );

stage1 stage1_2 (
 .clk    (clk),
 .din    (bus_2),
 .dout   (bus_3) );

endmodule
