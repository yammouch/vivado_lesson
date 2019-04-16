module fft_3_8 #(
 parameter DBW = 8,
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

stage1 #(.DBW(DBW), .CBW(CBW), .FBW(6)) stage1_1 (
 .clk    (clk),
 .cnt    (cnt),
 .trigon ({ 8'h00, 8'h40
          , 8'h00, 8'h40
          , 8'h00, 8'h40
          , 8'h00, 8'h40 }),
 .din    ({{DBW{1'b0}}, din}),
 .dout   (dout_1) );

stage1 #(.DBW(DBW), .CBW(CBW), .FBW(6)) stage1_2 (
 .clk    (clk),
 .cnt    ({~cnt[CBW-1], cnt[CBW-2:0]}),
 .trigon ({ 8'hC0, 8'h00
          , 8'h00, 8'h40
          , 8'hC0, 8'h00
          , 8'h00, 8'h40 }),
 .din    (dout_1),
 .dout   (dout_2) );

stage1 #(.DBW(DBW), .CBW(CBW), .FBW(6)) stage1_3 (
 .clk    (clk),
 .cnt    (cnt),
 .trigon ({ 8'hD3, 8'hD3
          , 8'hD3, 8'h2D
          , 8'hC0, 8'h00
          , 8'h00, 8'h40 }),
 .din    (dout_2),
 .dout   (dout) );

endmodule
