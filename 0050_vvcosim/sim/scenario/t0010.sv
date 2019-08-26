`timescale 1ps/1ps

module t0010;

`include "inst.svh"

task test1;
logic [3:0] data [$];
//logic [3:0] data [4];
begin
  //data = new();
  data.push_back(4'd0);
  data.push_back(4'd1);
  data.push_back(4'd2);
  data.push_back(4'd3);
  for (int i = 0; i < data.size(); i++) begin
  //data[0] = 4'd0;
  //data[1] = 4'd1;
  //data[2] = 4'd2;
  //data[3] = 4'd3;
  //for (int i = 0; i < 4; i++) begin
    @(negedge clk) din = data[i];
  end
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

