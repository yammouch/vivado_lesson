class CHello;

logic [3:0] data;

automatic function show();
  $display("### hello %d ###", data);
endfunction

endclass
