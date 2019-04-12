module fft_3 #(
 parameter DBW = 4,
 parameter CBW = 3) (
 input              clk,
 input              rstx,
 input              clear,
 input  [  DBW-1:0] din,
 output [2*DBW-1:0] dout );

reg [CBW-1:0] cnt;
always @(posedge clk or negedge rstx)
  if (!rstx)      cnt <= {CBW{1'b0}};
  else if (clear) cnt <= {CBW{1'b0}};
  else            cnt <= cnt + {{(CBW-1){1'b0}}, 1'b1};

wire [2*DBW-1:0] dout_1, dout_2;

stage1 #(.DBW(DBW), .CBW(CBW)) stage1_1 (
 .clk    (clk),
 .cnt    (cnt),
 .trigon ({ 4'b0000, 4'b0100
          , 4'b0000, 4'b0100
          , 4'b0000, 4'b0100
          , 4'b0000, 4'b0100 }),
 .din    ({{DBW{1'b0}}, din}),
 .dout   (dout_1) );

stage1 #(.DBW(DBW), .CBW(CBW)) stage1_2 (
 .clk    (clk),
 .cnt    ({^cnt[CBW-1], cnt[CBW-2:0]}),
 .trigon ({ 4'b0000, 4'b0100
          , 4'b0100, 4'b0000
          , 4'b0000, 4'b0100
          , 4'b0100, 4'b0000 }),
 .din    (dout_1),
 .dout   (dout_2) );

stage1 #(.DBW(DBW), .CBW(CBW)) stage1_3 (
 .clk    (clk),
 .cnt    (cnt),
 .trigon ({ 4'b0000, 4'b0100
          , 4'b0100, 4'b0000
          , 4'b0011, 4'b0011
          , 4'b0011, 4'b1011 }),
 .din    (dout_2),
 .dout   (dout) );

endmodule
