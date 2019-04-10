module stage1 #(
 parameter DBW = 3,
 parameter CBW = 3 ) (
 input              clk,
 input              clear,
 input  [2*DBW-1:0] din,
 output [2*DBW-1:0] dout );

reg [CBW-1:0] cnt;
always @(posedge clk)
  if (clear) cnt <= 0;
  else       cnt <= cnt + 1;

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
 .op1  (table_rd), // table_rd is needed be defined.
 .op2  (dout_half),
 .prod (prod) );

endmodule
