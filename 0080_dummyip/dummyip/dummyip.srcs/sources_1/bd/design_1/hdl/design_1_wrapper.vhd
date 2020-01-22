--Copyright 1986-2018 Xilinx, Inc. All Rights Reserved.
----------------------------------------------------------------------------------
--Tool Version: Vivado v.2018.2 (win64) Build 2258646 Thu Jun 14 20:03:12 MDT 2018
--Date        : Wed Jan 22 15:53:42 2020
--Host        : LAPTOP-ER85SC8R running 64-bit major release  (build 9200)
--Command     : generate_target design_1_wrapper.bd
--Design      : design_1_wrapper
--Purpose     : IP block netlist
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
library UNISIM;
use UNISIM.VCOMPONENTS.ALL;
entity design_1_wrapper is
  port (
    CLK : in STD_LOGIC;
    Q0 : out STD_LOGIC_VECTOR ( 2 downto 0 );
    Q1 : out STD_LOGIC_VECTOR ( 3 downto 0 );
    SCLR : in STD_LOGIC
  );
end design_1_wrapper;

architecture STRUCTURE of design_1_wrapper is
  component design_1 is
  port (
    CLK : in STD_LOGIC;
    Q0 : out STD_LOGIC_VECTOR ( 2 downto 0 );
    Q1 : out STD_LOGIC_VECTOR ( 3 downto 0 );
    SCLR : in STD_LOGIC
  );
  end component design_1;
begin
design_1_i: component design_1
     port map (
      CLK => CLK,
      Q0(2 downto 0) => Q0(2 downto 0),
      Q1(3 downto 0) => Q1(3 downto 0),
      SCLR => SCLR
    );
end STRUCTURE;
