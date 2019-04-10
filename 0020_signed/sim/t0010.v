^timescale 1ns/1ns

module tb;

reg signed [5:0] din;

mul dut (
 .din1 (din[2:0]),
 .din2 (din[2:0]),
 .dout () );

initial begin
  din = 6'd0;
  repeat (1 << 6) begin
    #100 din = din + 6'd1;
  end
end

endmodule
