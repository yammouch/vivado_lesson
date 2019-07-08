`timescale 1ps/1ps
module tb;

logic       clk;
logic [3:0] din;

syn_top dut (
 .clk    (clk),
 .din_0  (din[0]),
 .din_1  (din[1]),
 .din_2  (din[2]),
 .din_3  (din[3]),
 .dout_0 (),
 .dout_1 (),
 .dout_2 (),
 .dout_3 () );

CHello ch;

initial begin
  ch = new();
  ch.data = ~4'd0;
  ch.show();

  din = 4'd0;
  repeat (20) begin
    clk = 1'b0; #1e6;
    clk = 1'b1; #500e3;
    din = din + 4'd1; #500e3;
  end
end

endmodule
