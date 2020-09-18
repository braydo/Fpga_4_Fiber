library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;

entity mpd_event_writer is
  port(
    CLK                           : in  std_logic;
    RESET                         : in  std_logic;

    S_EVOUT_V_DIN                 : out std_logic_vector(32 downto 0);
    S_EVOUT_V_FULL                : in  std_logic;
    S_EVOUT_V_WRITE               : out std_logic;

    S_AVGBHEADER_V_DOUT           : in  std_logic_vector(13 downto 0);
    S_AVGBHEADER_V_EMPTY_N        : in  std_logic;
    S_AVGBHEADER_V_READ           : out std_logic;

    S_AVGBSAMPLES_V_DOUT          : in std_logic_vector(12 downto 0);
    S_AVGBSAMPLES_V_READ          : out std_logic;
    S_AVGBSAMPLES_V_EMPTY         : in std_logic;

    BUILD_ALL_SAMPLES_V           : in  std_logic_vector(0 downto 0);
    BUILD_DEBUG_HEADERS_V         : in  std_logic_vector(0 downto 0);
    ENABLE_CM_V                   : in  std_logic_vector(0 downto 0);
    FIBER_V                       : in  std_logic_vector(4 downto 0);

    M_APVTHR_V_ADDRESS0           : out std_logic_vector(10 downto 0);
    M_APVTHR_V_CE0                : out std_logic;
    M_APVTHR_V_Q0                 : in  std_logic_vector(8 downto 0)
  );
end mpd_event_writer;

architecture synthesis of mpd_event_writer is
  constant AVG_HEADER_TYPE_APVHDR   : std_logic_vector(1 downto 0) := "01";
  constant AVG_HEADER_TYPE_EVEND    : std_logic_vector(1 downto 0) := "10";

  type s13a is array(natural range <>) of signed(12 downto 0);
  type STATE_TYPE is (S_HEADER, S_READ, S_TEST, S_WRITE0, S_WRITE1, S_WRITE2);

  signal PS                   : STATE_TYPE;
  signal NS                   : STATE_TYPE;
  signal DO_APV_ID            : std_logic;
  signal DO_AVGB              : std_logic;
  signal DO_CNT_RST           : std_logic;
  signal DO_CNT_INC           : std_logic;
  signal DO_SUM_RST           : std_logic;
  signal DO_SAMPLE_N_INC      : std_logic;
  signal DO_SAMPLE_N_RST      : std_logic;
  signal DO_READ              : std_logic;

  signal SAMPLE_N             : unsigned(6 downto 0);
  signal CNT                  : unsigned(2 downto 0);
  signal APV_ID               : std_logic_vector(3 downto 0);
  signal AVGB                 : s13a(0 to 5);
  signal S                    : s13a(0 to 5);
  signal SUM                  : signed(15 downto 0);
  signal THR                  : signed(15 downto 0);
  signal S0_CMP               : std_logic_vector(0 to 4);
  signal S5_CMP               : std_logic_vector(0 to 4);
begin

  M_APVTHR_V_CE0 <= '1';
  M_APVTHR_V_ADDRESS0 <= APV_ID & std_logic_vector(SAMPLE_N);

  process(S)
  begin
    for I in 0 to 4 loop
      if S(0) > S(1+I) then
        S0_CMP(I) <= '1';
      else
        S0_CMP(I) <= '0';
      end if;
      
      if S(5) > S(I) then
        S5_CMP(I) <= '1';
      else
        S5_CMP(I) <= '0';
      end if;
    end loop;
  end process;

  process(CLK)
    variable sample : signed(13 downto 0);
    variable avg    : signed(13 downto 0);
    variable thr2   : std_logic_vector(15 downto 0);
    variable thr4   : std_logic_vector(15 downto 0);
  begin
    if rising_edge(CLK) then
      thr2(0) := '0';
      thr2(9 downto 1) := M_APVTHR_V_Q0;
      thr2(15 downto 10) := "000000";

      thr4(1 downto 0) := "00";
      thr4(10 downto 2) := M_APVTHR_V_Q0;
      thr4(15 downto 11) := "00000";
    
      THR <= signed(thr2)+signed(thr4);

      if RESET = '1' or DO_CNT_RST = '1' then
        CNT <= (others=>'0');
      elsif DO_CNT_INC = '1' then
        CNT <= CNT + 1;
      end if;
    
      if DO_SAMPLE_N_RST = '1' then
        SAMPLE_N <= (others=>'0');
      elsif DO_SAMPLE_N_INC = '1' then
        SAMPLE_N <= SAMPLE_N + 1;
      end if;
      
      if DO_APV_ID = '1' then
        APV_ID <= S_AVGBHEADER_V_DOUT(5 downto 2);
      end if;

      if DO_AVGB = '1' then
        case CNT is
          when "000"  => AVGB(0) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
          when "001"  => AVGB(1) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
          when "010"  => AVGB(2) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
          when "011"  => AVGB(3) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
          when "100"  => AVGB(4) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
          when others => AVGB(5) <= signed(S_AVGBHEADER_V_DOUT(12 downto 0));
        end case;
      end if;

      if DO_READ = '1' then
        case CNT is
          when "000"  => avg := resize(AVGB(0),14);
          when "001"  => avg := resize(AVGB(1),14);
          when "010"  => avg := resize(AVGB(2),14);
          when "011"  => avg := resize(AVGB(3),14);
          when "100"  => avg := resize(AVGB(4),14);
          when others => avg := resize(AVGB(5),14);
        end case;

        sample := resize(signed(S_AVGBSAMPLES_V_DOUT),14);
        if ENABLE_CM_V(0) = '1' then
          sample := sample - avg;
          if sample < to_signed(-4095,14) then
            sample := to_signed(-4095,14);
          elsif sample >= to_signed(4095,14) then
            sample := to_signed(4095,14);
          end if;
        end if;

        case CNT is
          when "000"  => S(0) <= resize(sample,13);
          when "001"  => S(1) <= resize(sample,13);
          when "010"  => S(2) <= resize(sample,13);
          when "011"  => S(3) <= resize(sample,13);
          when "101"  => S(4) <= resize(sample,13);
          when others => S(5) <= resize(sample,13);
        end case;
      end if;

      if DO_SUM_RST = '1' then
        SUM <= (others=>'0');
      elsif DO_READ = '1' then
        SUM <= SUM + resize(sample,16);
      end if;

    end if;
  end process;

  process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        PS <= S_HEADER;
      else
        PS <= NS;
      end if;
    end if;
  end process;

  process(PS, S_AVGBHEADER_V_EMPTY_N, S_EVOUT_V_FULL, S_AVGBHEADER_V_DOUT, CNT, S_AVGBSAMPLES_V_EMPTY, BUILD_ALL_SAMPLES_V, SUM, THR, S0_CMP, S5_CMP, SAMPLE_N, S)
  begin
    NS <= PS;
    S_AVGBHEADER_V_READ <= '0';
    DO_CNT_INC <= '0';
    DO_CNT_RST <= '0';
    DO_SUM_RST <= '0';
    DO_AVGB <= '0';
    DO_READ <= '0';
    DO_APV_ID <= '0';
    DO_SAMPLE_N_INC <= '0';
    DO_SAMPLE_N_RST <= '0';
    S_EVOUT_V_WRITE <= '0';
    S_EVOUT_V_DIN <= (others=>'1');
    S_AVGBSAMPLES_V_READ <= '0';

    case PS is
      when S_HEADER =>
        if (S_AVGBHEADER_V_EMPTY_N = '1') and (S_EVOUT_V_FULL = '0') then
          S_AVGBHEADER_V_READ <= '1';
          if (S_AVGBHEADER_V_DOUT(13) = '1') and (S_AVGBHEADER_V_DOUT(1 downto 0) = AVG_HEADER_TYPE_APVHDR) then
            DO_APV_ID <= '1';
            if CNT = "000" then
              S_EVOUT_V_WRITE <= '1';
              S_EVOUT_V_DIN(32)           <= '0';
              S_EVOUT_V_DIN(31 downto 27) <= "10101";
              S_EVOUT_V_DIN(26 downto 21) <= (others=>'0');
              S_EVOUT_V_DIN(20 downto 16) <= FIBER_V;
              S_EVOUT_V_DIN(15 downto 5)  <= (others=>'0');
              S_EVOUT_V_DIN(4 downto 0)   <= S_AVGBHEADER_V_DOUT(10 downto 6);
            end if;
          elsif (S_AVGBHEADER_V_DOUT(13) = '1') and (S_AVGBHEADER_V_DOUT(1 downto 0) = AVG_HEADER_TYPE_EVEND) then
            S_EVOUT_V_WRITE <= '1';
          elsif (S_AVGBHEADER_V_DOUT(13) = '0') then
            DO_AVGB <= '1';
            if CNT = "101" then
              DO_CNT_RST <= '1';
              DO_SUM_RST <= '1';
              DO_SAMPLE_N_RST <= '1';
              NS <= S_READ;
            else
              DO_CNT_INC <= '1';
            end if;
          end if;

        end if;

      when S_READ =>
        if S_AVGBSAMPLES_V_EMPTY = '0' then
          S_AVGBSAMPLES_V_READ <= '1';
          DO_READ <= '1';
          if CNT = "101" then
            NS <= S_TEST;
            DO_CNT_RST <= '1';
          else            
            DO_CNT_INC <= '1';
          end if;
        end if;

      when S_TEST =>
        DO_SUM_RST <= '1';
        if (BUILD_ALL_SAMPLES_V(0) = '1') or ( (SUM >= THR) and (and_reduce(S0_CMP) = '0') and (and_reduce(S5_CMP) = '0') ) then
          NS <= S_WRITE0;
        elsif SAMPLE_N = to_unsigned(127,7) then
          NS <= S_HEADER;
          DO_SAMPLE_N_INC <= '1';
        else
          NS <= S_READ;
          DO_SAMPLE_N_INC <= '1';
        end if;

      when S_WRITE0 =>
        if S_EVOUT_V_FULL = '0' then
          NS <= S_WRITE1;
          S_EVOUT_V_WRITE <= '1';
          S_EVOUT_V_DIN(32)           <= '0';
          S_EVOUT_V_DIN(31)           <= '0';
          S_EVOUT_V_DIN(30 downto 26) <= std_logic_vector(SAMPLE_N(4 downto 0));
          S_EVOUT_V_DIN(25 downto 13) <= std_logic_vector(S(1));
          S_EVOUT_V_DIN(12 downto  0) <= std_logic_vector(S(0));
        end if;

      when S_WRITE1 =>
        if S_EVOUT_V_FULL = '0' then
          NS <= S_WRITE2;
          S_EVOUT_V_WRITE <= '1';
          S_EVOUT_V_DIN(32)           <= '0';
          S_EVOUT_V_DIN(31)           <= '0';
          S_EVOUT_V_DIN(30 downto 28) <= "000";
          S_EVOUT_V_DIN(27 downto 26) <= std_logic_vector(SAMPLE_N(6 downto 5));
          S_EVOUT_V_DIN(25 downto 13) <= std_logic_vector(S(3));
          S_EVOUT_V_DIN(12 downto  0) <= std_logic_vector(S(2));
        end if;

--      when S_WRITE2 =>
      when others =>
        if S_EVOUT_V_FULL = '0' then
          if SAMPLE_N = to_unsigned(127,7) then
            NS <= S_HEADER;
          else
            NS <= S_READ;
          end if;
          DO_SAMPLE_N_INC <= '1';
          S_EVOUT_V_WRITE <= '1';
          S_EVOUT_V_DIN(32)           <= '0';
          S_EVOUT_V_DIN(31)           <= '0';
          S_EVOUT_V_DIN(30)           <= '0';
          S_EVOUT_V_DIN(29 downto 26) <= APV_ID;
          S_EVOUT_V_DIN(25 downto 13) <= std_logic_vector(S(5));
          S_EVOUT_V_DIN(12 downto  0) <= std_logic_vector(S(4));
        end if;

    end case;
  end process;

end synthesis;
