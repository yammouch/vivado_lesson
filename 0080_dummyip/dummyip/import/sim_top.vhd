library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity sim_top is
end entity;

architecture tb of sim_top is
  component design_1_wrapper is
    port (
      CLK : in STD_LOGIC;
      Q0 : out STD_LOGIC_VECTOR ( 2 downto 0 );
      Q1 : out STD_LOGIC_VECTOR ( 3 downto 0 );
      SCLR : in STD_LOGIC
    );
  end component;

  for dut : design_1_wrapper use configuration work.conf1;
begin
  dut : design_1_wrapper
    port map (
      CLK  => '0',
      Q0   => open,
      Q1   => open,
      SCLR => '0'
    );
end tb;
