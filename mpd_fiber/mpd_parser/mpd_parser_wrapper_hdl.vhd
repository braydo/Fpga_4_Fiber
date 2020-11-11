library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mpd_parser_wrapper_hdl is
  generic(
    FIBER                           : integer
  );
  port(
    -- From MPD/APV event builder
    EVT_DATA_CLK                    : in  std_logic;
    EVT_DATA_BUSY                   : out std_logic;
    EVT_DATA_VALID                  : in  std_logic;
    EVT_DATA                        : in  std_logic_vector(31 downto 0);
    EVT_DATA_END                    : in  std_logic;

    -- This must be same as mpd_fiber_interface reference clock (125MHz for 2.5Gbps, 62.5MHz for 1.25Gbps)
    -- All signals below must be synchronous to this clock, with exception of the Event builder interface
    CLK                             : in std_logic;
    RESET                           : in std_logic;

    -- Register interface
    -- CM/ZERO suppression configuration
    BUILD_ALL_SAMPLES               : in std_logic;
    BUILD_DEBUG_HEADERS             : in std_logic;
    ENABLE_CM                       : in std_logic;
    EVT_ENABLE                      : in std_logic;

    -- 13bit signed offset for each APV channel & chip
    APV_OFFSET                      : in std_logic_vector(12 downto 0);
    APV_OFFSET_WR                   : in std_logic;
    APV_OFFSET_ADDR                 : in std_logic_vector(10 downto 0);

    -- 9bit signed threshoold of each APV channel & chip
    APV_THR                         : in std_logic_vector(8 downto 0);
    APV_THR_WR                      : in std_logic;
    APV_THR_ADDR                    : in std_logic_vector(10 downto 0);

    -- Event builder interface, connects to fiber interface
    EVT_FIFO_RD                     : in  std_logic;
    EVT_FIFO_DOUT                   : out std_logic_vector(32 downto 0);
    EVT_FIFO_EMPTY                  : out std_logic
  );
end mpd_parser_wrapper_hdl;

architecture synthesis of mpd_parser_wrapper_hdl is
  signal RESET_ARRAY                      : std_logic_vector(7 downto 0) := (others=>'0');
  signal RESET_N_ARRAY                    : std_logic_vector(0 downto 0);

  --MPD PARSER
  signal S_AVGAPREHEADER_V_DIN            : std_logic_vector(28 downto 0);
  signal S_AVGAPREHEADER_V_FULL_N         : std_logic;
  signal S_AVGAPREHEADER_V_WRITE          : std_logic;
  signal S_AVGBPREHEADER_V_DIN            : std_logic_vector(28 downto 0);
  signal S_AVGBPREHEADER_V_FULL_N         : std_logic;
  signal S_AVGBPREHEADER_V_WRITE          : std_logic;
  signal S_AVGAHEADER_V_DOUT              : std_logic_vector(13 downto 0);
  signal S_AVGAHEADER_V_EMPTY_N           : std_logic;
  signal S_AVGAHEADER_V_READ              : std_logic;
  signal S_AVGBHEADER_V_DOUT              : std_logic_vector(13 downto 0);
  signal S_AVGBHEADER_V_EMPTY_N           : std_logic;
  signal S_AVGBHEADER_V_READ              : std_logic;

  --AVG DIVIDER
  signal S_AVGAPREHEADER_V_DOUT           : std_logic_vector(28 downto 0);
  signal S_AVGAPREHEADER_V_EMPTY_N        : std_logic;
  signal S_AVGAPREHEADER_V_READ           : std_logic;
  signal S_AVGBPREHEADER_V_DOUT           : std_logic_vector(28 downto 0);
  signal S_AVGBPREHEADER_V_EMPTY_N        : std_logic;
  signal S_AVGBPREHEADER_V_READ           : std_logic;
  signal S_AVGAHEADER_V_DIN               : std_logic_vector(13 downto 0);
  signal S_AVGAHEADER_V_FULL_N            : std_logic;
  signal S_AVGAHEADER_V_WRITE             : std_logic;
  signal S_AVGBHEADER_V_DIN               : std_logic_vector(13 downto 0);
  signal S_AVGBHEADER_V_FULL_N            : std_logic;
  signal S_AVGBHEADER_V_WRITE             : std_logic;

  --AVGB FIFO
  signal S_AVGBSAMPLES_V_DIN              : std_logic_vector(12 downto 0);
  signal S_AVGBSAMPLES_V_WRITE            : std_logic;
  signal S_AVGBSAMPLES_V_FULL             : std_logic;
  signal S_AVGBSAMPLES_V_DOUT             : std_logic_vector(12 downto 0);
  signal S_AVGBSAMPLES_V_READ             : std_logic;
  signal S_AVGBSAMPLES_V_EMPTY            : std_logic;
  
  --Block FIFO/RAM
  signal M_OFFSET_V_ADDRESS0             : std_logic_vector(10 downto 0);
  signal M_OFFSET_V_CE0                  : std_logic;
  signal M_OFFSET_V_Q0                   : std_logic_vector(12 downto 0);
  signal M_APVTHRB_V_ADDRESS0            : std_logic_vector(10 downto 0);
  signal M_APVTHRB_V_CE0                 : std_logic;
  signal M_APVTHRB_V_Q0                  : std_logic_vector(8 downto 0);
  signal M_APVTHR_V_ADDRESS0             : std_logic_vector(10 downto 0);
  signal M_APVTHR_V_CE0                  : std_logic;
  signal M_APVTHR_V_Q0                   : std_logic_vector(8 downto 0);
  signal S_EVIN_V_RESET                  : std_logic;
  signal S_EVIN_V_DOUT                   : std_logic_vector(32 downto 0);
  signal S_EVIN_V_EMPTY                  : std_logic;
  signal S_EVIN_V_READ                   : std_logic;
  signal S_EVOUT_V_RESET                 : std_logic;
  signal S_EVOUT_V_DIN                   : std_logic_vector(32 downto 0);
  signal S_EVOUT_V_FULL                  : std_logic;
  signal S_EVOUT_V_WRITE                 : std_logic;
  signal RAM_AVGB_DO0                    : std_logic_vector(31 downto 0);
  signal RAM_AVGB_DO1                    : std_logic_vector(31 downto 0);
  signal RAM_AVGB_WRADDR0                : std_logic_vector(8 downto 0);
  signal RAM_AVGB_WRADDR1                : std_logic_vector(8 downto 0);
  signal RAM_AVGB_WREN0                  : std_logic;
  signal RAM_AVGB_WREN1                  : std_logic;
  signal RAM_AVGB_RDEN0                  : std_logic;
  signal RAM_AVGB_RDEN1                  : std_logic;
  signal RAM_AVGB_RDADDR0                : std_logic_vector(8 downto 0);
  signal RAM_AVGB_RDADDR1                : std_logic_vector(8 downto 0);
  signal RAM_AVGB_DI                     : std_logic_vector(31 downto 0);
  signal RAM_AVGB_WE                     : std_logic_vector(3 downto 0);
  signal S_AVGASAMPLESOUT_V_DATA_V_RESET : std_logic;
  signal S_AVGASAMPLESOUT_V_DATA_V_DIN   : std_logic_vector(12 downto 0);
  signal S_AVGASAMPLESOUT_V_DATA_V_FULL  : std_logic;
  signal S_AVGASAMPLESOUT_V_DATA_V_WRITE : std_logic;
  signal S_AVGASAMPLESIN_V_DATA_V_DOUT   : std_logic_vector(12 downto 0);
  signal S_AVGASAMPLESIN_V_DATA_V_EMPTY  : std_logic;
  signal S_AVGASAMPLESIN_V_DATA_V_READ   : std_logic;
begin

  process(CLK)
  begin
    if rising_edge(CLK) then
      S_AVGASAMPLESOUT_V_DATA_V_RESET <= RESET;
      S_EVIN_V_RESET                  <= RESET;
      S_EVOUT_V_RESET                 <= RESET;
      RESET_ARRAY                     <= (others=>RESET);
      RESET_N_ARRAY                   <= (others=>(not RESET));
    end if;
  end process;

  mpd_frame_decoder_inst: entity work.mpd_frame_decoder
    port map(
      CLK                           => CLK,
      RESET                         => RESET_ARRAY(0),
      S_EVIN_V_DOUT                 => S_EVIN_V_DOUT,
      S_EVIN_V_EMPTY                => S_EVIN_V_EMPTY,
      S_EVIN_V_READ                 => S_EVIN_V_READ,
      S_AVGASAMPLES_V_DATA_V_DIN    => S_AVGASAMPLESOUT_V_DATA_V_DIN,
      S_AVGASAMPLES_V_DATA_V_FULL   => S_AVGASAMPLESOUT_V_DATA_V_FULL,
      S_AVGASAMPLES_V_DATA_V_WRITE  => S_AVGASAMPLESOUT_V_DATA_V_WRITE,
      M_OFFSET_V_ADDRESS0           => M_OFFSET_V_ADDRESS0,
      M_OFFSET_V_CE0                => M_OFFSET_V_CE0,
      M_OFFSET_V_Q0                 => M_OFFSET_V_Q0,
      S_AVGAPREHEADER_V_DIN         => S_AVGAPREHEADER_V_DIN,
      S_AVGAPREHEADER_V_FULL_N      => S_AVGAPREHEADER_V_FULL_N,
      S_AVGAPREHEADER_V_WRITE       => S_AVGAPREHEADER_V_WRITE
    );

  mpd_avgb_inst: entity work.mpd_avgb
    port map(
      CLK                             => CLK,
      RESET                           => RESET_ARRAY(1),
      S_AVGASAMPLES_V_DATA_V_DOUT     => S_AVGASAMPLESIN_V_DATA_V_DOUT(12 downto 0),
      S_AVGASAMPLES_V_DATA_V_EMPTY    => S_AVGASAMPLESIN_V_DATA_V_EMPTY,
      S_AVGASAMPLES_V_DATA_V_READ     => S_AVGASAMPLESIN_V_DATA_V_READ,
      S_AVGAHEADER_V_DOUT             => S_AVGAHEADER_V_DOUT,
      S_AVGAHEADER_V_EMPTY_N          => S_AVGAHEADER_V_EMPTY_N,
      S_AVGAHEADER_V_READ             => S_AVGAHEADER_V_READ,
      S_AVGBSAMPLES_V_DIN             => S_AVGBSAMPLES_V_DIN,
      S_AVGBSAMPLES_V_WRITE           => S_AVGBSAMPLES_V_WRITE,
      S_AVGBSAMPLES_V_FULL            => S_AVGBSAMPLES_V_FULL,
      S_AVGBPREHEADER_V_DIN           => S_AVGBPREHEADER_V_DIN,
      S_AVGBPREHEADER_V_FULL_N        => S_AVGBPREHEADER_V_FULL_N,
      S_AVGBPREHEADER_V_WRITE         => S_AVGBPREHEADER_V_WRITE,
      M_APVTHRB_V_ADDRESS0            => M_APVTHRB_V_ADDRESS0,
      M_APVTHRB_V_CE0                 => M_APVTHRB_V_CE0,
      M_APVTHRB_V_Q0                  => M_APVTHRB_V_Q0
    );

  mpd_event_writer_inst: entity work.mpd_event_writer
    port map(
      CLK                           => CLK,
      RESET                         => RESET_ARRAY(2),
      S_EVOUT_V_DIN                 => S_EVOUT_V_DIN,
      S_EVOUT_V_FULL                => S_EVOUT_V_FULL,
      S_EVOUT_V_WRITE               => S_EVOUT_V_WRITE,
      S_AVGBHEADER_V_DOUT           => S_AVGBHEADER_V_DOUT,
      S_AVGBHEADER_V_EMPTY_N        => S_AVGBHEADER_V_EMPTY_N,
      S_AVGBHEADER_V_READ           => S_AVGBHEADER_V_READ,
      S_AVGBSAMPLES_V_DOUT          => S_AVGBSAMPLES_V_DOUT,
      S_AVGBSAMPLES_V_READ          => S_AVGBSAMPLES_V_READ,
      S_AVGBSAMPLES_V_EMPTY         => S_AVGBSAMPLES_V_EMPTY,
      BUILD_ALL_SAMPLES_V(0)        => BUILD_ALL_SAMPLES,
      BUILD_DEBUG_HEADERS_V(0)      => BUILD_DEBUG_HEADERS,
      ENABLE_CM_V(0)                => ENABLE_CM,
      FIBER_V                       => std_logic_vector(to_unsigned(FIBER, 5)),
      M_APVTHR_V_ADDRESS0           => M_APVTHR_V_ADDRESS0,
      M_APVTHR_V_CE0                => M_APVTHR_V_CE0,
      M_APVTHR_V_Q0                 => M_APVTHR_V_Q0
    );

  ------------------------------------------------------
  -- AVG DIVIDER
  ------------------------------------------------------  
  fifo_shiftreg_avgaprehdr: entity work.fifo_shiftreg
    generic map(
      MEM_STYLE   => "shiftreg",
      DATA_WIDTH  => 29,
      ADDR_WIDTH  => 3,
      DEPTH       => 4
    )
    port map(
      CLK         => CLK,
      RESET       => RESET_ARRAY(3),
      IF_FULL_N   => S_AVGAPREHEADER_V_FULL_N,
      IF_DIN      => S_AVGAPREHEADER_V_DIN,
      IF_WRITE_CE => S_AVGAPREHEADER_V_WRITE,
      IF_WRITE    => S_AVGAPREHEADER_V_WRITE,
      IF_READ_CE  => S_AVGAPREHEADER_V_READ,
      IF_READ     => S_AVGAPREHEADER_V_READ,
      IF_EMPTY_N  => S_AVGAPREHEADER_V_EMPTY_N,
      IF_DOUT     => S_AVGAPREHEADER_V_DOUT
    );

  fifo_shiftreg_avgbprehdr: entity work.fifo_shiftreg
    generic map(
      MEM_STYLE   => "shiftreg",
      DATA_WIDTH  => 29,
      ADDR_WIDTH  => 3,
      DEPTH       => 4
    )
    port map(
      CLK         => CLK,
      RESET       => RESET_ARRAY(4),
      IF_FULL_N   => S_AVGBPREHEADER_V_FULL_N,
      IF_DIN      => S_AVGBPREHEADER_V_DIN,
      IF_WRITE_CE => S_AVGBPREHEADER_V_WRITE,
      IF_WRITE    => S_AVGBPREHEADER_V_WRITE,
      IF_READ_CE  => S_AVGBPREHEADER_V_READ,
      IF_READ     => S_AVGBPREHEADER_V_READ,
      IF_EMPTY_N  => S_AVGBPREHEADER_V_EMPTY_N,
      IF_DOUT     => S_AVGBPREHEADER_V_DOUT
    );

  fifo_shiftreg_avgahdr: entity work.fifo_shiftreg
    generic map(
      MEM_STYLE   => "shiftreg",
      DATA_WIDTH  => 14,
      ADDR_WIDTH  => 3,
      DEPTH       => 5
    )
    port map(
      CLK         => CLK,
      RESET       => RESET_ARRAY(5),
      IF_FULL_N   => S_AVGAHEADER_V_FULL_N,
      IF_DIN      => S_AVGAHEADER_V_DIN,
      IF_WRITE_CE => S_AVGAHEADER_V_WRITE,
      IF_WRITE    => S_AVGAHEADER_V_WRITE,
      IF_READ_CE  => S_AVGAHEADER_V_READ,
      IF_READ     => S_AVGAHEADER_V_READ,
      IF_EMPTY_N  => S_AVGAHEADER_V_EMPTY_N,
      IF_DOUT     => S_AVGAHEADER_V_DOUT
    );

  fifo_shiftreg_avgbhdr: entity work.fifo_shiftreg
    generic map(
      MEM_STYLE   => "shiftreg",
      DATA_WIDTH  => 14,
      ADDR_WIDTH  => 3,
      DEPTH       => 4
    )
    port map(
      CLK         => CLK,
      RESET       => RESET_ARRAY(6),
      IF_FULL_N   => S_AVGBHEADER_V_FULL_N,
      IF_DIN      => S_AVGBHEADER_V_DIN,
      IF_WRITE_CE => S_AVGBHEADER_V_WRITE,
      IF_WRITE    => S_AVGBHEADER_V_WRITE,
      IF_READ_CE  => S_AVGBHEADER_V_READ,
      IF_READ     => S_AVGBHEADER_V_READ,
      IF_EMPTY_N  => S_AVGBHEADER_V_EMPTY_N,
      IF_DOUT     => S_AVGBHEADER_V_DOUT
    );

  avgHeaderDiv_inst: entity work.avgHeaderDiv
    port map(
      AP_CLK                    => CLK,
      AP_RST_N                  => RESET_N_ARRAY(0),
      AP_START                  => '1',
      AP_DONE                   => open,
      AP_IDLE                   => open,
      AP_READY                  => open,
      S_AVGAPREHEADER_V_DOUT    => S_AVGAPREHEADER_V_DOUT,
      S_AVGAPREHEADER_V_EMPTY_N => S_AVGAPREHEADER_V_EMPTY_N,
      S_AVGAPREHEADER_V_READ    => S_AVGAPREHEADER_V_READ,
      S_AVGBPREHEADER_V_DOUT    => S_AVGBPREHEADER_V_DOUT,
      S_AVGBPREHEADER_V_EMPTY_N => S_AVGBPREHEADER_V_EMPTY_N,
      S_AVGBPREHEADER_V_READ    => S_AVGBPREHEADER_V_READ,
      S_AVGAHEADER_V_DIN        => S_AVGAHEADER_V_DIN,
      S_AVGAHEADER_V_FULL_N     => S_AVGAHEADER_V_FULL_N,
      S_AVGAHEADER_V_WRITE      => S_AVGAHEADER_V_WRITE,
      S_AVGBHEADER_V_DIN        => S_AVGBHEADER_V_DIN,
      S_AVGBHEADER_V_FULL_N     => S_AVGBHEADER_V_FULL_N,
      S_AVGBHEADER_V_WRITE      => S_AVGBHEADER_V_WRITE
    );

  ------------------------------------------------------
  -- AVGB FIFO
  ------------------------------------------------------
  mpd_avgb_fifo_inst: entity work.mpd_avgb_fifo
    port map(
      CLK                 => CLK,
      RESET               => RESET_ARRAY(7),
      SAMPLES_IN          => S_AVGBSAMPLES_V_DIN,
      SAMPLES_IN_WR       => S_AVGBSAMPLES_V_WRITE,
      SAMPLES_IN_FULL     => S_AVGBSAMPLES_V_FULL,
      SAMPLES_OUT         => S_AVGBSAMPLES_V_DOUT,
      SAMPLES_OUT_RD      => S_AVGBSAMPLES_V_READ,
      SAMPLES_OUT_EMPTY   => S_AVGBSAMPLES_V_EMPTY,
      DO0                 => RAM_AVGB_DO0,
      DO1                 => RAM_AVGB_DO1,
      WRADDR0             => RAM_AVGB_WRADDR0,
      WRADDR1             => RAM_AVGB_WRADDR1,
      WREN0               => RAM_AVGB_WREN0,
      WREN1               => RAM_AVGB_WREN1,
      RDEN0               => RAM_AVGB_RDEN0,
      RDEN1               => RAM_AVGB_RDEN1,
      RDADDR0             => RAM_AVGB_RDADDR0,
      RDADDR1             => RAM_AVGB_RDADDR1,
      DI                  => RAM_AVGB_DI,
      WE                  => RAM_AVGB_WE
    );

  ------------------------------------------------------
  -- Block RAM/FIFO
  ------------------------------------------------------
  mpd_parser_ram_altera_inst: entity work.mpd_parser_ram_altera
    port map(
      CLK                             => CLK,
      APV_OFFSET                      => APV_OFFSET,
      APV_OFFSET_WR                   => APV_OFFSET_WR,
      APV_OFFSET_ADDR                 => APV_OFFSET_ADDR,
      APV_THR                         => APV_THR,
      APV_THR_WR                      => APV_THR_WR,
      APV_THR_ADDR                    => APV_THR_ADDR,
      EVT_ENABLE                      => EVT_ENABLE,
      EVT_DATA_CLK                    => EVT_DATA_CLK,
      EVT_DATA_BUSY                   => EVT_DATA_BUSY,
      EVT_DATA_VALID                  => EVT_DATA_VALID,
      EVT_DATA                        => EVT_DATA,
      EVT_DATA_END                    => EVT_DATA_END,
      EVT_FIFO_RD                     => EVT_FIFO_RD,
      EVT_FIFO_DOUT                   => EVT_FIFO_DOUT,
      EVT_FIFO_EMPTY                  => EVT_FIFO_EMPTY,
      M_OFFSET_V_ADDRESS0             => M_OFFSET_V_ADDRESS0,
      M_OFFSET_V_CE0                  => M_OFFSET_V_CE0,
      M_OFFSET_V_Q0                   => M_OFFSET_V_Q0,
      M_APVTHR_V_ADDRESS0             => M_APVTHR_V_ADDRESS0,
      M_APVTHR_V_CE0                  => M_APVTHR_V_CE0,
      M_APVTHR_V_Q0                   => M_APVTHR_V_Q0,
      M_APVTHRB_V_ADDRESS0            => M_APVTHRB_V_ADDRESS0,
      M_APVTHRB_V_CE0                 => M_APVTHRB_V_CE0,
      M_APVTHRB_V_Q0                  => M_APVTHRB_V_Q0,
      S_EVIN_V_RESET                  => S_EVIN_V_RESET,
      S_EVIN_V_DOUT                   => S_EVIN_V_DOUT,
      S_EVIN_V_EMPTY                  => S_EVIN_V_EMPTY,
      S_EVIN_V_READ                   => S_EVIN_V_READ,
      S_EVOUT_V_RESET                 => S_EVOUT_V_RESET,
      S_EVOUT_V_DIN                   => S_EVOUT_V_DIN,
      S_EVOUT_V_FULL                  => S_EVOUT_V_FULL,
      S_EVOUT_V_WRITE                 => S_EVOUT_V_WRITE,
      RAM_AVGB_DO0                    => RAM_AVGB_DO0,
      RAM_AVGB_DO1                    => RAM_AVGB_DO1,
      RAM_AVGB_WRADDR0                => RAM_AVGB_WRADDR0,
      RAM_AVGB_WRADDR1                => RAM_AVGB_WRADDR1,
      RAM_AVGB_WREN0                  => RAM_AVGB_WREN0,
      RAM_AVGB_WREN1                  => RAM_AVGB_WREN1,
      RAM_AVGB_RDEN0                  => RAM_AVGB_RDEN0,
      RAM_AVGB_RDEN1                  => RAM_AVGB_RDEN1,
      RAM_AVGB_RDADDR0                => RAM_AVGB_RDADDR0,
      RAM_AVGB_RDADDR1                => RAM_AVGB_RDADDR1,
      RAM_AVGB_DI                     => RAM_AVGB_DI,
      RAM_AVGB_WE                     => RAM_AVGB_WE,
      S_AVGASAMPLESOUT_V_DATA_V_RESET => S_AVGASAMPLESOUT_V_DATA_V_RESET,
      S_AVGASAMPLESOUT_V_DATA_V_DIN   => S_AVGASAMPLESOUT_V_DATA_V_DIN,
      S_AVGASAMPLESOUT_V_DATA_V_FULL  => S_AVGASAMPLESOUT_V_DATA_V_FULL,
      S_AVGASAMPLESOUT_V_DATA_V_WRITE => S_AVGASAMPLESOUT_V_DATA_V_WRITE,
      S_AVGASAMPLESIN_V_DATA_V_DOUT   => S_AVGASAMPLESIN_V_DATA_V_DOUT,
      S_AVGASAMPLESIN_V_DATA_V_EMPTY  => S_AVGASAMPLESIN_V_DATA_V_EMPTY,
      S_AVGASAMPLESIN_V_DATA_V_READ   => S_AVGASAMPLESIN_V_DATA_V_READ
    );

end synthesis;
