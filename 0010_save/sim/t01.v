^timescale 1ps/1ps

module tb;

reg  rstn;
reg  clk
reg  clk_en;
reg  clr;
time hi_period, lo_period;

m01 i_m01(
 .rstn      (rstn),
 .clk       (clk),
 .clr       (clr),
 .dout      (),
 .dout_comb () );

always @(clk_en)
  while (clk_en) begin
    clk = 1'b1; #(hi_period);
    clk = 1'b0; #(lo_period);
  end

initial begin
  hi_period = 500e3; // 1 MHz
  lo_period = 500e3;
  rstn      = 1'b0;
  clk       = 1'b0;
  clr       = 1'b0;

  clk_en = 1'b1;
  repeat (4) @(negedge clk);
  rstn = 1'b1;
  repeat (4) @(negedge clk);
  $save("snapshot");
  $finish;
end

endmodule
