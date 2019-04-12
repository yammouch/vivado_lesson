`timescale 1ps/1ps

module tb;

`include "inst_fft_3.v"
`include "tasks.v"

task test_main;
begin
  init; #50_000;
  cg.en = 1'b1;
  repeat (4) @(negedge clk);
  rstx = 1'b1;
  repeat (4) @(negedge clk);
  clear = 1'b1;
  repeat (64) @(negedge clk);
  cg.en = 1'b0;
end
endtask

initial begin
  $dumpfile("result/t900.vcd");
  $dumpvars;
  test_main;
end

endmodule
