library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpd_avgb is
  port(
    CLK                             : in  std_logic;
    RESET                           : in  std_logic;

    S_AVGASAMPLES_V_DATA_V_DOUT     : in  std_logic_vector(12 downto 0);
    S_AVGASAMPLES_V_DATA_V_EMPTY    : in  std_logic;
    S_AVGASAMPLES_V_DATA_V_READ     : out std_logic;

    S_AVGAHEADER_V_DOUT             : in  std_logic_vector(13 downto 0);
    S_AVGAHEADER_V_EMPTY_N          : in  std_logic;
    S_AVGAHEADER_V_READ             : out std_logic;

    S_AVGBSAMPLES_V_DIN             : out std_logic_vector(12 downto 0);
    S_AVGBSAMPLES_V_WRITE           : out std_logic;
    S_AVGBSAMPLES_V_FULL            : in std_logic;

    S_AVGBPREHEADER_V_DIN           : out std_logic_vector(28 downto 0);
    S_AVGBPREHEADER_V_FULL_N        : in  std_logic;
    S_AVGBPREHEADER_V_WRITE         : out std_logic;
  
    M_APVTHRB_V_ADDRESS0            : out std_logic_vector(10 downto 0);
    M_APVTHRB_V_CE0                 : out std_logic;
    M_APVTHRB_V_Q0                  : in  std_logic_vector(8 downto 0)
  );
end mpd_avgb;

architecture synthesis of mpd_avgb is
  constant AVG_HEADER_TYPE_APVHDR   : std_logic_vector(1 downto 0) := "01";
  constant AVG_HEADER_TYPE_EVEND    : std_logic_vector(1 downto 0) := "10";
  
  type STATE_TYPE is (S_IDLE, S_READ_AVGHDR, S_READ_APV_DATA, S_WRITE_AVGHDR);

  signal PS       : STATE_TYPE;
  signal NS       : STATE_TYPE;
  signal DO_INIT  : std_logic;
  signal DO_N_INC : std_logic;
  signal DO_AVG   : std_logic;
  signal DO_SUM   : std_logic;
  signal SUM      : signed(19 downto 0);
  signal CNT      : unsigned(7 downto 0);
  signal N        : unsigned(6 downto 0);
  signal N_DONE   : std_logic;
  signal AVG      : signed(12 downto 0);
  signal THR      : signed(13 downto 0);
  signal APV_ID   : std_logic_vector(3 downto 0);
begin

  THR <= signed("00000"&M_APVTHRB_V_Q0) + resize(AVG,14);

  N_DONE <= '1' when N = to_unsigned(127,7) else '0';

  M_APVTHRB_V_ADDRESS0 <= APV_ID & std_logic_vector(N);
  M_APVTHRB_V_CE0 <= '1';

  S_AVGBSAMPLES_V_DIN <= S_AVGASAMPLES_V_DATA_V_DOUT;

  process(CLK)
  begin
    if rising_edge(CLK) then
      if DO_INIT = '1' then
        APV_ID <= S_AVGAHEADER_V_DOUT(5 downto 2);
      end if;

      if DO_INIT = '1' then
        N <= (others=>'0');
      elsif DO_N_INC = '1' then
        N <= N + 1;
      end if;

      if DO_INIT = '1' then
        SUM <= (others=>'0');
        CNT <= (others=>'0');
      elsif DO_SUM = '1' then
        SUM <= SUM + resize(signed(S_AVGASAMPLES_V_DATA_V_DOUT),20);
        CNT <= CNT + 1;
      end if;

      if DO_AVG = '1' then
        AVG <= signed(S_AVGAHEADER_V_DOUT(12 downto 0));
      end if;

    end if;
  end process;

  process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        PS <= S_IDLE;
      else
        PS <= NS;
      end if;
    end if;
  end process;

  process(PS, S_AVGASAMPLES_V_DATA_V_EMPTY, S_AVGBSAMPLES_V_FULL, S_AVGAHEADER_V_EMPTY_N, S_AVGBPREHEADER_V_FULL_N, S_AVGAHEADER_V_DOUT, S_AVGASAMPLES_V_DATA_V_DOUT, THR, SUM, CNT)
  begin
    NS <= PS;
    DO_INIT <= '0';
    DO_SUM <= '0';
    DO_AVG <= '0';
    DO_N_INC <= '0';
    S_AVGAHEADER_V_READ <= '0';
    S_AVGASAMPLES_V_DATA_V_READ <= '0';
    S_AVGBPREHEADER_V_DIN <= (others=>'0');
    S_AVGBPREHEADER_V_WRITE <= '0';
    S_AVGBSAMPLES_V_WRITE <= '0';

    case PS is
      when S_IDLE =>
        if (S_AVGAHEADER_V_EMPTY_N = '1') and (S_AVGBPREHEADER_V_FULL_N = '1') then
          S_AVGAHEADER_V_READ <= '1';
          if (S_AVGAHEADER_V_DOUT(13) = '1') and (S_AVGAHEADER_V_DOUT(1 downto 0) = AVG_HEADER_TYPE_APVHDR) then
            NS <= S_READ_AVGHDR;
            S_AVGBPREHEADER_V_DIN(28) <= '1';
            S_AVGBPREHEADER_V_DIN(10 downto 0) <= S_AVGAHEADER_V_DOUT(10 downto 2) & AVG_HEADER_TYPE_APVHDR;
            S_AVGBPREHEADER_V_WRITE <= '1';
            DO_INIT <= '1';
          elsif (S_AVGAHEADER_V_DOUT(13) = '1') and (S_AVGAHEADER_V_DOUT(1 downto 0) = AVG_HEADER_TYPE_EVEND) then
            S_AVGBPREHEADER_V_DIN(28) <= '1';
            S_AVGBPREHEADER_V_DIN(1 downto 0) <= AVG_HEADER_TYPE_EVEND;
            S_AVGBPREHEADER_V_WRITE <= '1';
          end if;
        end if;

      when S_READ_AVGHDR =>
        if S_AVGAHEADER_V_EMPTY_N = '1' then
          NS <= S_READ_APV_DATA;
          S_AVGAHEADER_V_READ <= '1';
          DO_AVG <= '1';
        end if;

      when S_READ_APV_DATA =>
        if (S_AVGASAMPLES_V_DATA_V_EMPTY = '0') and (S_AVGBSAMPLES_V_FULL = '0') then
          S_AVGASAMPLES_V_DATA_V_READ <= '1';
          S_AVGBSAMPLES_V_WRITE <= '1';
          DO_N_INC <= '1';
          if resize(signed(S_AVGASAMPLES_V_DATA_V_DOUT),14) <= THR then
            DO_SUM <= '1';
          end if;
          if N_DONE = '1' then
            NS <= S_WRITE_AVGHDR;
          end if;
        end if;

--      when S_WRITE_AVGHDR =>
      when others =>
        if S_AVGBPREHEADER_V_FULL_N = '1' then
          S_AVGBPREHEADER_V_DIN(19 downto 0) <= std_logic_vector(SUM);
          S_AVGBPREHEADER_V_DIN(27 downto 20) <= std_logic_vector(CNT);
          S_AVGBPREHEADER_V_DIN(28) <= '0';
          S_AVGBPREHEADER_V_WRITE <= '1';
          NS <= S_IDLE;
        end if;

    end case;
  end process;

end synthesis;

