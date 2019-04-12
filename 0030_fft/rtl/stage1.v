module stage1 #(
 parameter DBW = 4,
 parameter CBW = 3 ) (
 input                           clk,
 input  [               CBW-1:0] cnt,
 input  [2*DBW*(1<<(CBW-1))-1:0] trigon,
 input  [             2*DBW-1:0] din,    // s1.DBW-2
 output [             2*DBW-1:0] dout ); // s1.DBW-2

function [DBW*2:0] addsub(
 input [  DBW-1:0] din1,
 input [DBW*2-1:0] din2,
 input             sub);
// s1.DBW-2 + s3.DBW*2-4 -> s4.DBW*2-4
  addsub
   = {din1[DBW-1], din1[DBW-1:0], {(DBW){1'b0}}}
   + ({(2*DBW+1){sub}} ^ {din2[2*DBW-1], din2[2*DBW-1:0]})
   + {{(2*DBW){1'b0}}, sub};
endfunction

// s4.DBW*2-4 to s5.DBW-3
function [DBW+2:0] round(input [DBW*2:0] din);
  round = {din[2*DBW], din[2*DBW:DBW-1]} + {{(DBW+2){1'b0}}, din[DBW-2]};
endfunction

function [DBW-1:0] clip(input [DBW+2:0] din);
// s5.DBW-3 to s2.DBW-3
  if      (!din[DBW+2] && din[DBW+1:DBW] != 2'b00)
    clip = {1'b0, {(DBW-1){1'b1}}};
  else if ( din[DBW+2] && din[DBW+1:DBW] != 2'b11)
    clip = {1'b1, {(DBW-1){1'b0}}};
  else
    clip = din[DBW-1:0];
endfunction

reg [2*DBW-1:0] mem [(1<<(CBW-1))-1:0];
reg [2*DBW-1:0] mem_rd;
wire [CBW-2:0] mem_raddr
 = {~cnt[CBW-1], cnt[CBW-2:1]} + {{(CBW-2){1'b0}}, 1'b1};
//wire mem_rden
 //=  cnt[CBW-1:1] >= {1'b0, {(CBW-2){1'b1}}}
 //&& cnt[CBW-1:1] <  {(CBW-1){1'b1}}
 //&& cnt[0];
always @(posedge clk)
  if (!cnt[CBW-1]) mem[cnt[CBW-2:0]] <= din;
always @(posedge clk)
  //if (cnt[CBW-1:1] >= {1'b0, {(CBW-2){1'b1}}}
  // && cnt[CBW-1:1] <  {(CBW-1){1'b1}}
  // && cnt[0])
  //if (mem_rden)
  if (cnt[0])
    //mem_rd <= mem[{~cnt[CBW-1], cnt[CBW-2:1]} + {{(CBW-2){1'b0}}, 1'b1}];
    mem_rd <= mem[mem_raddr];

wire [2*DBW-1:0] dout_half;
halfrate #( .DBW(2*DBW), .CBW(CBW) ) halfrate_i (
 .clk  (clk),
 .cnt  (cnt),
 .din  (din),
 .dout (dout_half) );

wire [4*DBW-1:0] prod; // s3.DBW*2-4
wire [2*DBW-1:0] trigon1 = trigon >> ({~cnt[CBW-1], cnt[CBW-2:1]}*2*DBW);
cmplxmul #( .DBW(DBW) ) cmplxmul_i (
 .op1  (trigon1),
 .op2  (dout_half),
 .prod (prod) );

wire [2*DBW:0] sum_im = addsub(din[2*DBW-1:DBW], prod[4*DBW-1:2*DBW], cnt[0]);
// ^-- s4.DBW*2-4
wire [DBW+2:0] sum_im_round = round(sum_im); // s5.DBW-3
assign dout[2*DBW-1:DBW] = clip(sum_im_round); // s2.DBW-3

wire [2*DBW:0] sum_re = addsub(din[DBW-1:0], prod[2*DBW-1:0], ~cnt[0]);
wire [DBW+1:0] sum_re_round = round(sum_re);
assign dout[DBW-1:0] = clip(sum_re_round);

endmodule
