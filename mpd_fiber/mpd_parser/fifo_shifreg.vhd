library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity fifo_shiftreg is 
  generic(
    MEM_STYLE   : string := "shiftreg"; 
    DATA_WIDTH  : integer := 16;
    ADDR_WIDTH  : integer := 7;
    DEPTH       : integer := 65
  );
  port(
    CLK         : in std_logic;
    RESET       : in std_logic;
    IF_EMPTY_N  : out std_logic;
    IF_READ_CE  : in std_logic;
    IF_READ     : in std_logic;
    IF_DOUT     : out std_logic_vector(DATA_WIDTH-1 downto 0);
    IF_FULL_N   : out std_logic;
    IF_WRITE_CE : in std_logic;
    IF_WRITE    : in std_logic;
    IF_DIN      : in std_logic_vector(DATA_WIDTH-1 downto 0)
  );
end fifo_shiftreg;

architecture rtl of fifo_shiftreg is
  type SRL_ARRAY is array (0 to DEPTH-1) of std_logic_vector(DATA_WIDTH-1 downto 0);
  signal SRL_SIG : SRL_ARRAY;

    signal shiftReg_addr : STD_LOGIC_VECTOR(ADDR_WIDTH - 1 downto 0);
    signal shiftReg_data, shiftReg_q : STD_LOGIC_VECTOR(DATA_WIDTH - 1 downto 0);
    signal shiftReg_ce : STD_LOGIC;
    signal mOutPtr : STD_LOGIC_VECTOR(ADDR_WIDTH downto 0) := (others => '1');
    signal internal_empty_n : STD_LOGIC := '0';
    signal internal_full_n  : STD_LOGIC := '1';
begin
    if_empty_n <= internal_empty_n;
    if_full_n <= internal_full_n;
    shiftReg_data <= if_din;
    if_dout <= shiftReg_q;

    process (clk)
    begin
        if clk'event and clk = '1' then
            if reset = '1' then
                mOutPtr <= (others => '1');
                internal_empty_n <= '0';
                internal_full_n <= '1';
            else
                if ((if_read and if_read_ce) = '1' and internal_empty_n = '1') and 
                   ((if_write and if_write_ce) = '0' or internal_full_n = '0') then
                    mOutPtr <= mOutPtr - 1;
                    if (mOutPtr = 0) then 
                        internal_empty_n <= '0';
                    end if;
                    internal_full_n <= '1';
                elsif ((if_read and if_read_ce) = '0' or internal_empty_n = '0') and 
                   ((if_write and if_write_ce) = '1' and internal_full_n = '1') then
                    mOutPtr <= mOutPtr + 1;
                    internal_empty_n <= '1';
                    if (mOutPtr = DEPTH - 2) then 
                        internal_full_n <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

    shiftReg_addr <= (others => '0') when mOutPtr(ADDR_WIDTH) = '1' else mOutPtr(ADDR_WIDTH-1 downto 0);
    shiftReg_ce <= (if_write and if_write_ce) and internal_full_n;

  p_shift: process (clk)
  begin
    if (clk'event and clk = '1') then
        if (shiftReg_ce = '1') then
            SRL_SIG <= shiftReg_data & SRL_SIG(0 to DEPTH-2);
        end if;
    end if;
  end process;

  shiftReg_q <= SRL_SIG(conv_integer(shiftReg_addr));
        
end rtl;
