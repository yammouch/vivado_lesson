`timescale 1ps/1ps

module tb;

`include "inst_fft_3_8.v"
`include "tasks.v"

wire [7:0] dout_re, dout_im;
assign dout_re = dut.dout[ 7:0];
assign dout_im = dut.dout[15:8];

task test_main;
begin
  init; #50_000;
  cg.en = 1'b1;
  repeat (4) @(negedge clk);
  rstx = 1'b1;
  repeat (4) @(posedge clk);
  clear <= 1'b0;
  din <= 8'h40;
  repeat (4) @(posedge clk);
  din <= 8'h00;
  repeat (4) @(posedge clk);
  repeat (2) begin
    din <= 8'h40;
    repeat (2) @(posedge clk);
    din <= 8'h00;
    repeat (2) @(posedge clk);
  end
  repeat (20) @(posedge clk);
  cg.en = 1'b0;
end
endtask

initial begin
  $dumpfile("result/t800.vcd");
  $dumpvars;
  test_main;
end

endmodule
