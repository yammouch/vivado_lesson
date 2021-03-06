library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity add1 is
  port (
   clk  : in  std_logic;
   rstx : in  std_logic;
   din  : in  std_logic_vector(3 downto 0);
   dout : out std_logic_vector(3 downto 0)
  );
end entity;

architecture rtl of add1 is
  signal dout_r : std_logic_vector(3 downto 0);
begin
  dout <= dout_r;

  process (clk, rstx) begin
    if rstx = '0' then
      dout_r <= (others => '0');
    elsif clk = '1' and clk'event then
      dout_r <= std_logic_vector(unsigned(din) + 1);
    end if;
  end process;
end rtl;
