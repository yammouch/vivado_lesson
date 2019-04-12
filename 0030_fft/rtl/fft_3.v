module fft_3 #(
 parameter DBW = 3,
 parameter CBW = 3) (
 input              clk,
 input              rstx,
 input              clear,
 input  [2*DBW-1:0] din,
 output [2*DBW-1:0] dout );

reg [CBW-1:0] cnt;
always @(posedge clk or negedge rstx)
  if (!rstx)      cnt <= {CBW{1'b0}};
  else if (clear) cnt <= {CBW{1'b0}};
  else            cnt <= cnt + {{(CBW-1){1'b0}}, 1'b1};

wire [2*DBW-1:0] dout_1, dout_2;

stage1 stage1_1 #(.DBW(DBW), .CBW(CBW)) (
 .clk    (clk),
 .cnt    (cnt),
 .trigon (...), // to be generated from a sub program
 .din    (din),
 .dout   (dout_1) );

stage1 stage1_2 #(.DBW(DBW), .CBW(CBW)) (
 .clk    (clk),
 .cnt    ({^cnt[CBW-1], cnt[CBW-2:0]}),
 .trigon (...), // to be generated from a sub program
 .din    (dout_1),
 .dout   (dout_2) );

stage1 stage1_3 #(.DBW(DBW), .CBW(CBW)) (
 .clk    (clk),
 .cnt    (cnt),
 .trigon (...), // to be generated from a sub program
 .din    (dout_2),
 .dout   (dout) );

endmodule
