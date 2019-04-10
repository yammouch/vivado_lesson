module cmplxmul #(
 parameter DBW = 3
) (
 input  [2*DBW-1:0] op1,
 input  [2*DBW-1:0] op2,
 output [4*DBW-1:0] prod
)

wire signed [  DBW-1:0] op1_re, op1_im, op2_re, op2_im;
wire signed [2*DBW-1:0] prod_re, prod_im;

assign {op1_im, op1_re} = op1;
assign prod_re = op1_re * op2_re - op1_im * op2_im;
assign prod_im = op1_re * op2_im + op1_im * op2_re;
assign prod = {prod_re, prod_im};

endmodule
