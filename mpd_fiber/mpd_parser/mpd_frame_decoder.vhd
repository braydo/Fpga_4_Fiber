library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpd_frame_decoder is
  port(
    CLK                           : in  std_logic;
    RESET                         : in  std_logic;

    S_EVIN_V_DOUT                 : in  std_logic_vector(32 downto 0);
    S_EVIN_V_EMPTY                : in  std_logic;
    S_EVIN_V_READ                 : out std_logic;

    S_AVGASAMPLES_V_DATA_V_DIN    : out std_logic_vector(12 downto 0);
    S_AVGASAMPLES_V_DATA_V_FULL   : in  std_logic;
    S_AVGASAMPLES_V_DATA_V_WRITE  : out std_logic;

    M_OFFSET_V_ADDRESS0           : out std_logic_vector(10 downto 0);
    M_OFFSET_V_CE0                : out std_logic;
    M_OFFSET_V_Q0                 : in  std_logic_vector(12 downto 0);

    S_AVGAPREHEADER_V_DIN         : out std_logic_vector(28 downto 0);
    S_AVGAPREHEADER_V_FULL_N      : in  std_logic;
    S_AVGAPREHEADER_V_WRITE       : out std_logic
  );
end mpd_frame_decoder;

architecture synthesis of mpd_frame_decoder is
  constant BLOCK_HEADER           : std_logic_vector(2 downto 0) := "000";
  constant BLOCK_TRAILER          : std_logic_vector(2 downto 0) := "001";
  constant EVENT_TRAILER          : std_logic_vector(2 downto 0) := "101";
  constant APV_CH_DATA            : std_logic_vector(2 downto 0) := "100";
  constant APV_HEADER             : std_logic_vector(1 downto 0) := "00";
  constant APV_DATA               : std_logic_vector(1 downto 0) := "01";
  constant APV_TRAILER            : std_logic_vector(1 downto 0) := "10";
  constant AVG_HEADER_TYPE_APVHDR : std_logic_vector(1 downto 0) := "01";
  constant AVG_HEADER_TYPE_EVEND  : std_logic_vector(1 downto 0) := "10";

  type STATE_TYPE is (S_BLOCK_HEADER, S_APV_HEADER, S_GETMIN, S_GETMAX, S_LOAD_OFFSET, S_APV_DATA, S_APV_TRAILER);

  signal PS                   : STATE_TYPE;
  signal NS                   : STATE_TYPE;
  signal DO_MPD_ID            : std_logic;
  signal DO_APV_ID            : std_logic;
  signal DO_CLEAR             : std_logic;
  signal DO_ADC_WORD_CNT_INC  : std_logic;
  signal DO_MIN               : std_logic;
  signal DO_MAX               : std_logic;
  signal DO_MINMAX_TEST       : std_logic;
  signal DO_LOAD_MIN          : std_logic;
  signal DO_LOAD_MAX          : std_logic;
  
  signal ADC_WORD_CNT_DONE    : std_logic;
  signal ADC_WORD_CNT         : unsigned(6 downto 0);
  signal SUM                  : signed(19 downto 0);
  signal CNT                  : unsigned(7 downto 0);
  signal ADC                  : signed(12 downto 0);
  signal MIN                  : signed(12 downto 0);
  signal MAX                  : signed(12 downto 0);
  signal MPD_ID               : std_logic_vector(4 downto 0);
  signal APV_ID               : std_logic_vector(3 downto 0);
begin

  M_OFFSET_V_CE0 <= '1';
  
  ADC_WORD_CNT_DONE <= '1' when ADC_WORD_CNT = to_unsigned(127,ADC_WORD_CNT'length) else '0';

  S_AVGASAMPLES_V_DATA_V_DIN <= std_logic_vector(ADC);

  M_OFFSET_V_ADDRESS0 <= "1111" & "000" & APV_ID when DO_LOAD_MIN = '1' else
                         "1111" & "001" & APV_ID when DO_LOAD_MAX = '1' else
                         APV_ID & std_logic_vector(ADC_WORD_CNT);

  process(S_EVIN_V_DOUT, M_OFFSET_V_Q0, DO_MINMAX_TEST)
    variable val    : signed(13 downto 0);
    variable offset : signed(12 downto 0);
  begin
    val := signed("00" & S_EVIN_V_DOUT(11 downto 0));
    val := val - resize(signed(M_OFFSET_V_Q0),14);
    if val(12) = '1' then
      ADC(12) <= val(13);
      ADC(11 downto 0) <= (others=>val(12));
    else
      ADC(12) <= val(13);
      ADC(11 downto 0) <= val(11 downto 0);
    end if;
  end process;

  process(CLK)
  begin
    if rising_edge(CLK) then
      if DO_MPD_ID = '1' then
        MPD_ID <= S_EVIN_V_DOUT(20 downto 16);
      end if;

      if DO_APV_ID = '1' then
        APV_ID <= S_EVIN_V_DOUT(3 downto 0);
      end if;

      if DO_CLEAR = '1' then
        SUM <= (others=>'0');
        CNT <= (others=>'0');
      end if;
      
      if DO_CLEAR = '1' then
        ADC_WORD_CNT <= (others=>'0');
      elsif DO_ADC_WORD_CNT_INC = '1' then
        ADC_WORD_CNT <= ADC_WORD_CNT + 1;
      end if;

      if DO_MIN = '1' then
        MIN <= signed(M_OFFSET_V_Q0);
      end if;

      if DO_MAX = '1' then
        MAX <= signed(M_OFFSET_V_Q0);
      end if;

      if (DO_MINMAX_TEST = '1') and (ADC >= MIN) and (ADC <= MAX) then
        SUM <= SUM + resize(ADC,20);
        CNT <= CNT + 1;
      end if;
    end if;
  end process;

  process(CLK)
  begin
    if rising_edge(CLK) then
      if RESET = '1' then
        PS <= S_BLOCK_HEADER;
      else
        PS <= NS;
      end if;
    end if;
  end process;

  process(PS, S_EVIN_V_EMPTY, S_AVGAPREHEADER_V_FULL_N, S_EVIN_V_DOUT, MPD_ID, S_AVGASAMPLES_V_DATA_V_FULL, ADC_WORD_CNT_DONE, SUM, CNT)
  begin
    NS <= PS;
    S_EVIN_V_READ <= '0';
    DO_MPD_ID <= '0';
    DO_APV_ID <= '0';
    DO_CLEAR <= '0';
    DO_MINMAX_TEST <= '0';
    DO_LOAD_MIN <= '0';
    DO_LOAD_MAX <= '0';
    DO_MIN <= '0';
    DO_MAX <= '0';
    DO_ADC_WORD_CNT_INC <= '0';
    S_AVGAPREHEADER_V_DIN <= (others=>'0');
    S_AVGAPREHEADER_V_WRITE <= '0';
    S_AVGASAMPLES_V_DATA_V_WRITE <= '0';

    case PS is
      when S_BLOCK_HEADER =>
        if S_EVIN_V_EMPTY = '0' then
          S_EVIN_V_READ <= '1';
          if S_EVIN_V_DOUT(23 downto 21) = BLOCK_HEADER then
            NS <= S_APV_HEADER;
            DO_MPD_ID <= '1';
          end if;
        end if;

      when S_APV_HEADER =>
        if S_EVIN_V_EMPTY = '0' and S_AVGAPREHEADER_V_FULL_N = '1' then
          S_EVIN_V_READ <= '1';
          if S_EVIN_V_DOUT(32) = '1' then
            NS <= S_BLOCK_HEADER;
            S_AVGAPREHEADER_V_DIN(1 downto 0) <= AVG_HEADER_TYPE_EVEND;
            S_AVGAPREHEADER_V_DIN(28) <= '1';
            S_AVGAPREHEADER_V_WRITE <= '1';
          elsif S_EVIN_V_DOUT(23 downto 21) = APV_CH_DATA and S_EVIN_V_DOUT(20 downto 19) = APV_HEADER then
            NS <= S_GETMIN;
            DO_LOAD_MIN <= '1';
            S_AVGAPREHEADER_V_DIN(1 downto 0) <= AVG_HEADER_TYPE_APVHDR;
            S_AVGAPREHEADER_V_DIN(5 downto 2) <= S_EVIN_V_DOUT(3 downto 0); --APV_ID
            S_AVGAPREHEADER_V_DIN(10 downto 6) <= MPD_ID;
            S_AVGAPREHEADER_V_DIN(28) <= '1';
            S_AVGAPREHEADER_V_WRITE <= '1';
            DO_APV_ID <= '1';
            DO_CLEAR <= '1';
          end if;
        end if;

      when S_GETMIN =>
        DO_MIN <= '1';
        DO_LOAD_MAX <= '1';
        NS <= S_GETMAX;
        
      when S_GETMAX =>
        DO_MAX <= '1';
        NS <= S_LOAD_OFFSET;

      when S_LOAD_OFFSET =>
        NS <= S_APV_DATA;

      when S_APV_DATA =>        
        if S_EVIN_V_EMPTY = '0' and S_AVGASAMPLES_V_DATA_V_FULL = '0' then
          S_EVIN_V_READ <= '1';
          if (S_EVIN_V_DOUT(23 downto 21) = APV_CH_DATA) and (S_EVIN_V_DOUT(20 downto 19) = APV_DATA) then
            DO_ADC_WORD_CNT_INC <= '1';
            if ADC_WORD_CNT_DONE = '1' then
              NS <= S_APV_TRAILER;
            else
              NS <= S_LOAD_OFFSET;
            end if;
            S_AVGASAMPLES_V_DATA_V_WRITE <= '1';
            DO_MINMAX_TEST <= '1';
          end if;
        end if;

--      when S_APV_TRAILER =>
      when others =>
        if S_AVGAPREHEADER_V_FULL_N = '1' then
          NS <= S_APV_HEADER;
          S_AVGAPREHEADER_V_DIN(19 downto 0) <= std_logic_vector(SUM);
          S_AVGAPREHEADER_V_DIN(27 downto 20) <= std_logic_vector(CNT);
          S_AVGAPREHEADER_V_DIN(28) <= '0';
          S_AVGAPREHEADER_V_WRITE <= '1';
        end if;

    end case;
  end process;

end synthesis;

