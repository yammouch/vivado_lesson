interface bus();

logic       d0;
logic       d1;
logic [1:0] d2;

modport send(output d0, d1, d2);
modport recv(input  d0, d1, d2);

endinterface
