`default_nettype none

module default_net (
 input  wire       clk,
 input  wire [3:0] din,
 output wire [3:0] dout );

wire [3:0] mid;
assign mid = din + 4'd1;
assign dout = ~mid;

endmodule

`default_nettype wire
