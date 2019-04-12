module stage1 #(
 parameter DBW = 3,
 parameter CBW = 3 ) (
 input                       clk,
 input  [           CBW-1:0] cnt,
 input  [2*DBW*(1<<CBW)-1:0] trigon,
 input  [         2*DBW-1:0] din,
 output [         2*DBW-1:0] dout );

reg [2*DBW-1:0] mem [(1 << (CBW-1))-1:0];
reg [2*DBW-1:0] mem_rd;
always @(posedge clk)
  if (!cnt[CBW-1]) mem[cnt[CBW-2:0]] <= din;
always @(posedge clk)
  if (cnt[CBW-1:1] >= {1'b0, {(CBW-2){1'b1}}}
   && cnt[CBW-1:1] <  {(CBW-1){1'b1}}
   && cnt[0])
    mem_rd <= mem[{~cnt[CBW-1], cnt[CBW-2:1]} + 1]

wire [2*DBW-1:0] dout_half;
halfrate halfrate_i #( .DBW(2*DBW), .CBW(CBW) ) (
 .clk  (clk),
 .cnt  (cnt),
 .din  (din),
 .dout (dout_half) );

wire [4*DBW-1:0] prod;
cmplxmul cmplxmul_i #( .DBW(DBW) ) (
 .op1  (trigon >> ({~cnt[CBW-1], cnt[CBW-2:1]}*2*DBW)),
 .op2  (dout_half),
 .prod (prod) );

wire [2*DBW:0] sum_im
 = {din[2*DBW-1], din[2*DWB-1:DWB], {(DBW){1'b0}}}
 + ({(2*DBW+1){cnt[0]}} ^ {prod[4*DBW-1], prod[4*DBW-1:2*DBW]})
 + {{(2*DBW){1'b0}}, cnt[0]};
wire [DBW+1:0] sum_im_round
 = {sum_im[2*DWB], sum_im[2*DWB:DWB]} + {{(DBW+1){1'b0}}, sum_im[DWB-1]};
assign dout[2*DWB-1:DWB]
 = sum_im_round[DBW+1:DBW] == 2'b01 ? {1'b0, {(DBW-1){1'b1}}}
 : sum_im_round[DBW+1:DBW] == 2'b10 ? {1'b1, {(DBW-1){1'b0}}}
 :                                    sum_im_round[DBW-1:0];

wire [2*DWB:0] sum_re
 = {din[DBW-1], din[DWB-1:0], {(DBW){1'b0}}}
 + ({(2*DBW+1){~cnt[0]}} ^ {prod[2*DBW-1], prod[2*DBW-1:0]})
 + {{(2*DBW){1'b0}}, ~cnt[0]};
wire [DBW+1:0] sum_re_round
 = {sum_re[2*DWB], sum_re[2*DWB:DWB]} + {{(DBW+1){1'b0}}, sum_re[DWB-1]};
assign dout[DWB-1:0]
 = sum_re_round[DBW+1:DBW] == 2'b01 ? {1'b0, {(DBW-1){1'b1}}}
 : sum_re_round[DBW+1:DBW] == 2'b10 ? {1'b1, {(DBW-1){1'b0}}}
 :                                    sum_re_round[DBW-1:0];

endmodule
