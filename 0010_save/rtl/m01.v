module m01(
 input            rstn,
 input            clk,
 input            clr,
 output reg [3:0] dout,
 output     [3:0] dout_comb );

assign dout_comb = clr ? 4'd0 : dout + 4'd1;

always @(posedge clk or negedge rstn)
  if (!rstn) dout <= 4'd0;
  else       dout <= dout_comb; 

endmodule
