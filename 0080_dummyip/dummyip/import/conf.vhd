use work.all;

configuration conf1 of design_1_wrapper is
  for STRUCTURE
    for c_counter_binary_0 : design_1_c_counter_binary_0_0(STRUCTURE)
      use entity work.design_1_c_counter_binary_0_0(behav1);
    end for;
  end for;
end conf1;
