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
  repeat (4) @(posedge clk);
  clear <= 1'b0;
  din <= 4'b0100;
  repeat (4) @(posedge clk);
  din <= 4'b0000;
  repeat (4) @(posedge clk);
  repeat (2) begin
    din <= 4'b0100;
    repeat (2) @(posedge clk);
    din <= 4'b0000;
    repeat (2) @(posedge clk);
  end
  repeat (20) @(posedge clk);
  cg.en = 1'b0;
end
endtask

initial begin
  $dumpfile("result/t910.vcd");
  $dumpvars;
  test_main;
end

endmodule
