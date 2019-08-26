`timescale 1ps/1ps

module tb;

`include "inst.svh"

task test1;
logic [3:0] data [$];
//logic [3:0] data [4];
begin
  data.push_back(4'hD);
  data.push_back(4'hC);
  data.push_back(4'hB);
  data.push_back(4'hA);
  for (int i = 0; i < data.size(); i++) begin
    @(negedge clk) din = data[i];
  end
  repeat (4) @(negedge clk);
end
endtask

task main_loop;
begin
  rstx = 1'b0;
  din = ~4'd0;
  #50e3; // 50nu
  cg.en = 1'b1;
  repeat(3) @(negedge clk);
  rstx = 1'b1;
  test1();
  cg.en = 1'b0;
end
endtask

initial begin
  main_loop;
end

endmodule

