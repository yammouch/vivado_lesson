module stage1 (
 input    clk,
 bus.recv din,
 bus.send dout
);

always @(posedge clk) begin
  dout.d0 <= ~din.d0;
  dout.d1 <= ~din.d1;
  dout.d2 <= din.d2 + 2'd1;
end

endmodule
