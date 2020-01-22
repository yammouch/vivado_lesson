--use work.all;

--configuration conf1 of design_1_wrapper is
--  for STRUCTURE
--    for c_counter_binary_0 : work.design_1_c_counter_binary_0_0
--      use entity work.design_1_c_counter_binary_0_0(behav1);
--    end for;
--  end for;
--end conf1;


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity design_1_c_counter_binary_0_0 is
  port (
    CLK : in STD_LOGIC;
    SCLR : in STD_LOGIC;
    Q : out STD_LOGIC_VECTOR ( 2 downto 0 )
  );
end design_1_c_counter_binary_0_0;

architecture behav1 of design_1_c_counter_binary_0_0 is
begin
  process
  begin
    report "behav1";
    wait;
  end process;
end behav1;
