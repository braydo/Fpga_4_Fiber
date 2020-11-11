library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpd_avgb_fifo is
  port(
    CLK                 : in std_logic;
    RESET               : in std_logic;

    SAMPLES_IN          : in std_logic_vector(12 downto 0);
    SAMPLES_IN_WR       : in std_logic;
    SAMPLES_IN_FULL     : out std_logic;

    SAMPLES_OUT         : out std_logic_vector(12 downto 0);
    SAMPLES_OUT_RD      : in std_logic;
    SAMPLES_OUT_EMPTY   : out std_logic;
    
    DO0                 : in std_logic_vector(31 downto 0);
    DO1                 : in std_logic_vector(31 downto 0);
    WRADDR0             : out std_logic_vector(8 downto 0);
    WRADDR1             : out std_logic_vector(8 downto 0);
    WREN0               : out std_logic;
    WREN1               : out std_logic;
    RDEN0               : out std_logic;
    RDEN1               : out std_logic;
    RDADDR0             : out std_logic_vector(8 downto 0);
    RDADDR1             : out std_logic_vector(8 downto 0);
    DI                  : out std_logic_vector(31 downto 0);
    WE                  : out std_logic_vector(3 downto 0)
  );
end mpd_avgb_fifo;

architecture synthesis of mpd_avgb_fifo is
  signal SEL              : std_logic_vector(1 downto 0);
  signal RDEN0_i          : std_logic;
  signal RDEN1_i          : std_logic;
  signal DO               : std_logic_vector(12 downto 0);
  signal WREN             : std_logic;
  signal STD_FIFO_RD      : std_logic;
  signal STD_EMPTY        : std_logic;
  signal FIFO_WR_LEN_DONE : std_logic;
  signal FIFO_WR_S6       : std_logic;
  signal FIFO_WR_LEN      : std_logic_vector(9 downto 0);
  signal FIFO_LEN         : std_logic_vector(11 downto 0);
  signal FIFO_WR_CH       : std_logic_vector(6 downto 0);
  signal FIFO_WR_SAMPLE   : std_logic_vector(2 downto 0);
  signal FIFO_WR_POS      : std_logic_vector(10 downto 0);
  signal FIFO_RD_POS      : std_logic_vector(10 downto 0);
  signal FULL             : std_logic;
  signal EMPTY            : std_logic;
begin

  process(CLK)
    variable fifo_wr_pos_add  : std_logic_vector(10 downto 0);
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        FIFO_WR_CH     <= (others=>'0');
        FIFO_WR_SAMPLE <= (others=>'0');
        FIFO_WR_POS    <= (others=>'0');
        FIFO_WR_LEN    <= (others=>'0');
      else
        if (WREN = '1') and (FIFO_WR_CH /= "1111111") then
          fifo_wr_pos_add := std_logic_vector(to_unsigned(6,fifo_wr_pos_add'length));
        elsif (WREN = '1') and (FIFO_WR_CH =  "1111111") and (FIFO_WR_SAMPLE /= "101") then
          fifo_wr_pos_add := std_logic_vector(to_unsigned(2**fifo_wr_pos_add'length-761, fifo_wr_pos_add'length));
          FIFO_WR_SAMPLE  <= std_logic_vector(unsigned(FIFO_WR_SAMPLE) + 1);
        elsif (WREN = '1') and (FIFO_WR_CH =  "1111111") and (FIFO_WR_SAMPLE =  "101") then
          fifo_wr_pos_add := std_logic_vector(to_unsigned(1,fifo_wr_pos_add'length));
          FIFO_WR_SAMPLE  <= (others=>'0');
        else
          fifo_wr_pos_add := std_logic_vector(to_unsigned(0,fifo_wr_pos_add'length));
        end if;
        FIFO_WR_POS <= std_logic_vector(unsigned(FIFO_WR_POS) + unsigned(fifo_wr_pos_add));

        if WREN = '1' then
          FIFO_WR_CH      <= std_logic_vector(unsigned(FIFO_WR_CH) + 1);
        end if;

        if WREN = '1' then
          if FIFO_WR_LEN_DONE = '0' then
            FIFO_WR_LEN     <= std_logic_vector(unsigned(FIFO_WR_LEN) + 1);
          else
            FIFO_WR_LEN     <= (others=>'0');
          end if;
        end if;

      end if;

      if RESET = '1' then
        FIFO_RD_POS <= (others=>'0');
      elsif STD_FIFO_RD = '1' then
        FIFO_RD_POS <= std_logic_vector(unsigned(FIFO_RD_POS) + 1);
      end if;

      if RESET = '1' then
        FIFO_LEN <= (others=>'0');
      else
        if    (WREN = '1') and (FIFO_WR_S6 = '1') and (STD_FIFO_RD = '1') then
          FIFO_LEN <= std_logic_vector(unsigned(FIFO_LEN) + 5);
        elsif (WREN = '1') and (FIFO_WR_S6 = '1') and (STD_FIFO_RD = '0') then
          FIFO_LEN <= std_logic_vector(unsigned(FIFO_LEN) + 6);
        elsif                                         (STD_FIFO_RD = '1') then
          FIFO_LEN <= std_logic_vector(unsigned(FIFO_LEN) - 1);
        end if;
      end if;

      if RESET = '1' then
        EMPTY <= '1';
      elsif STD_FIFO_RD = '1' then
        EMPTY <= '0';
      elsif SAMPLES_OUT_RD = '1' then
        EMPTY <= '1';
      end if;
      
      if    (RDEN0_i = '1') and (FIFO_RD_POS(0) = '0') then
        SEL <= "00";
      elsif (RDEN0_i = '1') and (FIFO_RD_POS(0) = '1') then
        SEL <= "01";
      elsif (RDEN1_i = '1') and (FIFO_RD_POS(0) = '0') then
        SEL <= "10";
      elsif (RDEN1_i = '1') and (FIFO_RD_POS(0) = '1') then
        SEL <= "11";
      end if;
    end if;
  end process;
  
  FIFO_WR_LEN_DONE  <= '1' when unsigned(FIFO_WR_LEN)  = to_unsigned(767, FIFO_WR_LEN'length) else '0';
  FIFO_WR_S6        <= '1' when unsigned(FIFO_WR_LEN) >= to_unsigned(640, FIFO_WR_LEN'length) else '0';

  SAMPLES_IN_FULL   <= FULL;
  DI                <= "000" & SAMPLES_IN & "000" & SAMPLES_IN;

  SAMPLES_OUT_EMPTY <= EMPTY;
  SAMPLES_OUT       <= DO;

  STD_FIFO_RD       <= not STD_EMPTY and (SAMPLES_OUT_RD or EMPTY);
  STD_EMPTY         <= '1' when unsigned(FIFO_LEN) = to_unsigned(0   ,FIFO_LEN'length) else '0';
  FULL              <= '1' when unsigned(FIFO_LEN) = to_unsigned(2048,FIFO_LEN'length) else '0';

  WRADDR0 <= FIFO_WR_POS(10 downto 2);
  WRADDR1 <= FIFO_WR_POS(10 downto 2);
  WREN    <= (not FULL) and SAMPLES_IN_WR;
  WREN0   <= (not FULL) and SAMPLES_IN_WR and (not FIFO_WR_POS(1));
  WREN1   <= (not FULL) and SAMPLES_IN_WR and (    FIFO_WR_POS(1));
  WE      <= "0011" when (FIFO_WR_POS(0) = '0') else "1100";
  
  RDEN0 <= RDEN0_i;
  RDEN1 <= RDEN1_i;
  
  RDEN0_i <= STD_FIFO_RD and not FIFO_RD_POS(1);
  RDEN1_i <= STD_FIFO_RD and     FIFO_RD_POS(1);
  RDADDR0 <= FIFO_RD_POS(10 downto 2);
  RDADDR1 <= FIFO_RD_POS(10 downto 2);
  DO <= DO0(12 downto  0) when SEL = "00" else 
        DO0(28 downto 16) when SEL = "01" else 
        DO1(12 downto  0) when SEL = "10" else 
        DO1(28 downto 16);
    
end synthesis;
