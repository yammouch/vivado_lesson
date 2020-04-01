`timescale 1ps/1ps

module sub(output reg dout = 1'b0);
endmodule

module tb;

wire [1:0] sub_dout;

genvar gv;

generate
for (gv = 0; gv < 2; gv = gv+1) begin : g_sub
  sub i_sub(.dout(sub_dout[gv]));
end
endgenerate

task test_main;
logic [31:0] fh;
int i;
begin
  fh = $fopen("../t0010.log");
  $fwrite(fh, "t0010 runs\n");
  $fclose(fh);

  for (i = 0; i < 2; i = i+1) begin
    #1000;
    //g_sub[i].i_sub.dout = 1'b1; // does not work
    g_sub[0].i_sub.dout = 1'b1;
    #1000;
    g_sub[0].i_sub.dout = 1'b0;
  end
end
endtask

initial begin
  test_main;
end

endmodule
