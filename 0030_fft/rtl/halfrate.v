module halfrate #(
 parameter DBW = 3,
 parameter CBW = 3 ) (
 input            clk,
 input  [CBW-1:0] cnt,
 input  [DBW-1:0] din,
 output [DBW-1:0] dout );

reg  [DBW-1:0] mem [(1<<(CBW-1))- 2:0];
reg  [DBW-1:0] mem_rd;
wire [CBW-1:0] cnt_half = {~cnt[CBW-1], cnt[CBW-2:0]};
wire mem_wren = cnt[CBW-1] && |cnt[CBW-2:1];
wire [CBW-2:0] mem_waddr = cnt[CBW-2:0] - 2;
always @(posedge clk)
  //if (cnt[CBW-1] && |cnt[CBW-2:1])
  if (mem_wren)
    //mem[cnt[CBW-2:1] - 2] <= din;
    mem[mem_waddr] <= din;
wire mem_rden = cnt[0] && 3 <= cnt_half && !(&cnt_half);
wire [CBW-2:0] mem_raddr = cnt_half[CBW-1:1] - {{(CBW-1){1'b0}}, 1'b1};
always @(posedge clk)
  //if (cnt[0] && 3 <= cnt_half && !(&cnt_half))
  if (mem_rden)
    //mem_rd <= mem[cnt_half[CBW-1:1]-1];
    mem_rd <= mem[mem_raddr];

reg [DBW-1:0] din_d1;
always @(posedge clk)
  if (cnt[CBW-1] && cnt[CBW-2:1] == 0) din_d1 <= din;

assign dout
 = !cnt[CBW-1]                              ? mem_rd
 : (cnt[CBW-2:0] == 0)                      ? din
 : (1 <= cnt[CBW-2:0] && cnt[CBW-2:0] <= 3) ? din_d1
 :                                            mem_rd;

endmodule
