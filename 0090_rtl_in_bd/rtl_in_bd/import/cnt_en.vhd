library ieee;
use ieee.std_logic_1164.all;

entity cnt is
  port (
    clk : in  std_logic;
    clr : in  std_logic;
    q   : out std_logic_vector(2 downto 0)
  );
end cnt;
