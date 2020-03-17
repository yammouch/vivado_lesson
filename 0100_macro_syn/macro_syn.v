module macro_syn #(parameter BW = 1) (
 input               clk,
 input      [BW-1:0] di0,
 output reg [BW-1:0] do0,
`ifdef ADDITIONAL
 input               di1,
 //output reg          do1,
 output              do1,
`endif
 input               rst
);

always @(posedge clk) begin
  if (rst) do0 <= {BW{1'b0}};
  else     do0 <= di0;
end

`ifdef ADDITIONAL
//always @(posedge clk) begin
//  if (rst) do1 <= 1'b0;
//  else     do1 <= di1;
//end
sub i_sub (
 .di (di1),
 .do (do1) );
`endif

endmodule
