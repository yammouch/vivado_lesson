library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

architecture rtl of cnt is
signal r_q: std_logic_vector(2 downto 0);
begin

  process
  begin
    report "cnt_a1";
    wait;
  end process;

  process (clk) begin
    if clr = '1' then
      r_q <= (others => '0');
    elsif (clk = '1' and clk'event) then
      r_q <= std_logic_vector(unsigned(r_q) + 1);
    end if;
  end process;
  q <= r_q;
end rtl;
