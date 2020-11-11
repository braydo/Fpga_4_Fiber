library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.all;

entity mpd_parser_ram_altera is
  port(
    CLK                             : in std_logic;

    -- Register interface
    APV_OFFSET                      : in std_logic_vector(12 downto 0);
    APV_OFFSET_WR                   : in std_logic;
    APV_OFFSET_ADDR                 : in std_logic_vector(10 downto 0);

    APV_THR                         : in std_logic_vector(8 downto 0);
    APV_THR_WR                      : in std_logic;
    APV_THR_ADDR                    : in std_logic_vector(10 downto 0);

    -- Event builder interfacing
    EVT_ENABLE                      : in std_logic;
    
    EVT_DATA_CLK                    : in std_logic;
    EVT_DATA_BUSY                   : out std_logic;
    EVT_DATA_VALID                  : in  std_logic;
    EVT_DATA                        : in  std_logic_vector(31 downto 0);
    EVT_DATA_END                    : in  std_logic;

    EVT_FIFO_RD                     : in  std_logic;
    EVT_FIFO_DOUT                   : out std_logic_vector(32 downto 0);
    EVT_FIFO_EMPTY                  : out std_logic;

    -- MPD processing interface
    M_OFFSET_V_ADDRESS0             : in  std_logic_vector(10 downto 0);
    M_OFFSET_V_CE0                  : in  std_logic;
    M_OFFSET_V_Q0                   : out std_logic_vector(12 downto 0);

    M_APVTHR_V_ADDRESS0             : in  std_logic_vector(10 downto 0);
    M_APVTHR_V_CE0                  : in  std_logic;
    M_APVTHR_V_Q0                   : out std_logic_vector(8 downto 0);

    M_APVTHRB_V_ADDRESS0            : in  std_logic_vector(10 downto 0);
    M_APVTHRB_V_CE0                 : in  std_logic;
    M_APVTHRB_V_Q0                  : out std_logic_vector(8 downto 0);

    S_EVIN_V_RESET                  : in  std_logic;
    S_EVIN_V_DOUT                   : out std_logic_vector(32 downto 0);
    S_EVIN_V_EMPTY                  : out std_logic;
    S_EVIN_V_READ                   : in  std_logic;

    S_EVOUT_V_RESET                 : in  std_logic;
    S_EVOUT_V_DIN                   : in  std_logic_vector(32 downto 0);
    S_EVOUT_V_FULL                  : out std_logic;
    S_EVOUT_V_WRITE                 : in  std_logic;
    
    RAM_AVGB_DO0                    : out std_logic_vector(31 downto 0);
    RAM_AVGB_DO1                    : out std_logic_vector(31 downto 0);
    RAM_AVGB_WRADDR0                : in  std_logic_vector(8 downto 0);
    RAM_AVGB_WRADDR1                : in  std_logic_vector(8 downto 0);
    RAM_AVGB_WREN0                  : in  std_logic;
    RAM_AVGB_WREN1                  : in  std_logic;
    RAM_AVGB_RDEN0                  : in  std_logic;
    RAM_AVGB_RDEN1                  : in  std_logic;
    RAM_AVGB_RDADDR0                : in  std_logic_vector(8 downto 0);
    RAM_AVGB_RDADDR1                : in  std_logic_vector(8 downto 0);
    RAM_AVGB_DI                     : in  std_logic_vector(31 downto 0);
    RAM_AVGB_WE                     : in  std_logic_vector(3 downto 0);

    S_AVGASAMPLESOUT_V_DATA_V_RESET : in  std_logic;
    S_AVGASAMPLESOUT_V_DATA_V_DIN   : in  std_logic_vector(12 downto 0);
    S_AVGASAMPLESOUT_V_DATA_V_FULL  : out std_logic;
    S_AVGASAMPLESOUT_V_DATA_V_WRITE : in  std_logic;
    S_AVGASAMPLESIN_V_DATA_V_DOUT   : out std_logic_vector(12 downto 0);
    S_AVGASAMPLESIN_V_DATA_V_EMPTY  : out std_logic;
    S_AVGASAMPLESIN_V_DATA_V_READ   : in  std_logic
  );
end mpd_parser_ram_altera;

architecture synthesis of mpd_parser_ram_altera is
  component scfifo
    generic(
    	lpm_width : integer := 1;
    	lpm_widthu : integer := 1;
    	lpm_numwords : integer := 2;
    	lpm_showahead : string := "OFF";
    	lpm_type : string := "scfifo";
    	lpm_hint : string := "USE_EAB==ON";
    	intended_device_family : string := "Stratix";
    	underflow_checking : string := "ON";
    	overflow_checking : string := "ON";
    	allow_rwcycle_when_full : string := "OFF";
    	use_eab : string := "ON";
    	add_ram_output_register : string := "OFF";
    	almost_full_value : integer := 0;
    	almost_empty_value : integer := 0;
    	maximum_depth : integer := 0
    );
    port(
    	data : in std_logic_vector(lpm_width-1 downto 0);
    	clock : in std_logic;
    	wrreq : in std_logic;
    	rdreq : in std_logic;
    	aclr : in std_logic;
    	sclr : in std_logic;
    	q : out std_logic_vector(lpm_width-1 downto 0);
    	usedw : out std_logic_vector(lpm_widthu-1 downto 0);
    	full : out std_logic;
    	empty : out std_logic;
    	almost_full : out std_logic;
    	almost_empty : out std_logic
    );
  end component;

  component dcfifo
    generic(
    	lpm_width : integer := 1;
    	lpm_widthu : integer := 1;
    	lpm_numwords : integer := 2;
    	delay_rdusedw : integer := 1;
    	delay_wrusedw : integer := 1;
    	rdsync_delaypipe : integer := 0;
    	wrsync_delaypipe : integer := 0;
    	intended_device_family : string := "Stratix";
    	lpm_showahead : string := "OFF";
    	underflow_checking : string := "ON";
    	overflow_checking : string := "ON";
    	clocks_are_synchronized : string := "FALSE";
    	use_eab : string := "ON";
    	add_ram_output_register : string := "OFF";
    	lpm_hint : string := "USE_EAB==ON";
    	lpm_type : string := "dcfifo";
    	add_usedw_msb_bit : string := "OFF";
    	read_aclr_synch : string := "OFF";
    	write_aclr_synch : string := "OFF";
    	add_width : integer := 1;
    	ram_block_type : string := "AUTO"
    );
    port(
    	data : in std_logic_vector(lpm_width-1 downto 0);
    	rdclk : in std_logic;
    	wrclk : in std_logic;
    	aclr : in std_logic;
    	rdreq : in std_logic;
    	wrreq : in std_logic;
    	rdfull : out std_logic;
    	wrfull : out std_logic;
    	rdempty : out std_logic;
    	wrempty : out std_logic;
    	rdusedw : out std_logic_vector(lpm_widthu-1 downto 0);
    	wrusedw : out std_logic_vector(lpm_widthu-1 downto 0);
    	q : out std_logic_vector(lpm_width-1 downto 0)
    );
  end component;

	component altsyncram
  	generic(
  		address_reg_b		: string;
  		byteena_reg_b		: string;
  		byte_size		: natural;
  		clock_enable_input_a		: string;
  		clock_enable_input_b		: string;
  		clock_enable_output_a		: string;
  		clock_enable_output_b		: string;
  		indata_reg_b		: string;
  		intended_device_family		: string;
  		lpm_type		: string;
  		numwords_a		: natural;
  		numwords_b		: natural;
  		operation_mode		: string;
  		outdata_aclr_a		: string;
  		outdata_aclr_b		: string;
  		outdata_reg_a		: string;
  		outdata_reg_b		: string;
  		power_up_uninitialized		: string;
  		ram_block_type		: string;
  		widthad_a		: natural;
  		widthad_b		: natural;
  		width_a		: natural;
  		width_b		: natural;
  		width_byteena_a		: natural;
  		width_byteena_b		: natural;
  		wrcontrol_wraddress_reg_b		: string
  	);
  	port(
			byteena_a	: in std_logic_vector (width_byteena_a-1 downto 0);
			clock0	    : in std_logic ;
			clocken1	  : in std_logic ;
			wren_a	    : in std_logic ;
			byteena_b	: in std_logic_vector (width_byteena_b-1 downto 0);
			clock1	    : in std_logic ;
			q_a	      : out std_logic_vector (width_a-1 downto 0);
			wren_b    	: in std_logic ;
			address_a : in std_logic_vector (widthad_a-1 downto 0);
			data_a	    : in std_logic_vector (width_a-1 downto 0);
			q_b	      : out std_logic_vector (width_b-1 downto 0);
			address_b	: in std_logic_vector (widthad_b-1 downto 0);
			clocken0	  : in std_logic ;
			data_b	    : in std_logic_vector (width_b-1 downto 0)
	  );
	end component;
  
  signal RD_EN          : std_logic;
  signal EMPTY          : std_logic;
  signal EVTEND         : std_logic;
  signal RAM_THR_ENA    : std_logic;  
  signal RAM_THR_ADDRA  : std_logic_vector(10 downto 0);
begin

  ------------------------------------------------------
  -- S_EVIN FIFO
  ------------------------------------------------------
  dcfifo_inst0: dcfifo
    generic map(
      intended_device_family  => "Arria GX",
      lpm_hint                => "MAXIMIZE_SPEED=5,RAM_BLOCK_TYPE=M4K",
      lpm_numwords            => 128,
      lpm_showahead           => "ON",
      lpm_type                => "dcfifo",
      lpm_width               => 33,
      lpm_widthu              => 8,
      overflow_checking       => "ON",
      rdsync_delaypipe        => 5,
      underflow_checking      => "ON",
      use_eab                 => "ON",
      write_aclr_synch        => "ON",
      wrsync_delaypipe        => 5
    )
    port map(
      rdclk             => CLK,
      wrclk             => EVT_DATA_CLK,
      wrreq             => EVT_DATA_VALID,
      aclr              => S_EVIN_V_RESET,
      data(31 downto 0) => EVT_DATA,
      data(32)          => EVT_DATA_END,
      rdreq             => S_EVIN_V_READ,
      wrfull            => EVT_DATA_BUSY,
      q(31 downto 0)    => S_EVIN_V_DOUT(31 downto 0),
      q(32)             => S_EVIN_V_DOUT(32),
      rdempty           => S_EVIN_V_EMPTY,
      rdfull            => open,
      wrusedw           => open,
    	wrempty           => open,
    	rdusedw           => open
    );

  ------------------------------------------------------
  -- S_EVOUT FIFO
  ------------------------------------------------------
  RD_EN             <= EVT_FIFO_RD when EVT_ENABLE = '1' else '0';
  EVT_FIFO_EMPTY    <= EMPTY       when EVT_ENABLE = '1' else '0';
  EVT_FIFO_DOUT(32) <= EVTEND      when EVT_ENABLE = '1' else '1';

  dcfifo_inst1: dcfifo
    generic map(
      intended_device_family  => "Arria GX",
      lpm_hint                => "MAXIMIZE_SPEED=5,RAM_BLOCK_TYPE=M4K",
      lpm_numwords            => 128,
      lpm_showahead           => "ON",
      lpm_type                => "dcfifo",
      lpm_width               => 33,
      lpm_widthu              => 7,
      overflow_checking       => "ON",
      rdsync_delaypipe        => 5,
      underflow_checking      => "ON",
      use_eab                 => "ON",
      write_aclr_synch        => "ON",
      wrsync_delaypipe        => 5
    )
    port map(
      rdclk             => CLK,
      wrclk             => CLK,
      wrreq             => S_EVOUT_V_WRITE,
      aclr              => S_EVOUT_V_RESET,
      data(31 downto 0) => S_EVOUT_V_DIN(31 downto 0),
      data(32)          => S_EVOUT_V_DIN(32),
      rdreq             => RD_EN,
      wrfull            => S_EVOUT_V_FULL,
      q(31 downto 0)    => EVT_FIFO_DOUT(31 downto 0),
      q(32)             => EVTEND,
      rdempty           => EMPTY,
      rdfull            => open,
      wrusedw           => open,
    	wrempty           => open,
    	rdusedw           => open
    );

  ------------------------------------------------------
  -- AVGA FIFO
  ------------------------------------------------------
  scfifo_inst0: scfifo
    generic map(
      add_ram_output_register   => "OFF",
      intended_device_family    => "Arria GX",
      lpm_hint                  => "RAM_BLOCK_TYPE=M4K",
      lpm_numwords              => 256,
      lpm_showahead             => "ON",
      lpm_type                  => "scfifo",
      lpm_width                 => 13,
      lpm_widthu                => 8,
      overflow_checking         => "ON",
      underflow_checking        => "ON",
      use_eab                   => "ON"
    )
    port map(
      clock         => CLK,
      data          => S_AVGASAMPLESOUT_V_DATA_V_DIN,
      rdreq         => S_AVGASAMPLESIN_V_DATA_V_READ,
      sclr          => S_AVGASAMPLESOUT_V_DATA_V_RESET,
      wrreq         => S_AVGASAMPLESOUT_V_DATA_V_WRITE,
      empty         => S_AVGASAMPLESIN_V_DATA_V_EMPTY,
      full          => S_AVGASAMPLESOUT_V_DATA_V_FULL,
      q             => S_AVGASAMPLESIN_V_DATA_V_DOUT,
    	aclr          => '0',
    	usedw         => open,
    	almost_full   => open,
    	almost_empty  => open
    );
      
  ------------------------------------------------------
  -- RAM
  ------------------------------------------------------
  
  -- Offset
  altsyncram_component0: altsyncram
    generic map(
      address_reg_b             => "CLOCK1",
      byteena_reg_b             => "CLOCK1",
      byte_size                 => 13,
      clock_enable_input_a      => "NORMAL",
      clock_enable_input_b      => "NORMAL",
      clock_enable_output_a     => "BYPASS",
      clock_enable_output_b     => "BYPASS",
      indata_reg_b              => "CLOCK1",
      intended_device_family    => "Arria GX",
      lpm_type                  => "altsyncram",
      numwords_a                => 2048,
      numwords_b                => 2048,
      operation_mode            => "BIDIR_DUAL_PORT",
      outdata_aclr_a            => "NONE",
      outdata_aclr_b            => "NONE",
      outdata_reg_a             => "UNREGISTERED",
      outdata_reg_b             => "UNREGISTERED",
      power_up_uninitialized    => "FALSE",
      ram_block_type            => "M4K",
      widthad_a                 => 11,
      widthad_b                 => 11,
      width_a                   => 13,
      width_b                   => 13,
      width_byteena_a           => 1,
      width_byteena_b           => 1,
      wrcontrol_wraddress_reg_b => "CLOCK1"
    )
    port map(
      byteena_a => "1",
      clock0    => CLK,
      clocken1  => M_OFFSET_V_CE0,
      wren_a    => APV_OFFSET_WR,
      byteena_b => "1",
      clock1    => CLK,
      wren_b    => '0',
      address_a => APV_OFFSET_ADDR,
      data_a    => APV_OFFSET,
      address_b => M_OFFSET_V_ADDRESS0,
      clocken0  => '1',
      data_b    => (others=>'0'),
      q_a       => open,
      q_b       => M_OFFSET_V_Q0
    );
  
  --Threshold
  RAM_THR_ADDRA <= APV_THR_ADDR when APV_THR_WR = '1' else M_APVTHR_V_ADDRESS0;

  altsyncram_component1: altsyncram
    generic map(
      address_reg_b             => "CLOCK1",
      byteena_reg_b             => "CLOCK1",
      byte_size                 => 9,
      clock_enable_input_a      => "NORMAL",
      clock_enable_input_b      => "NORMAL",
      clock_enable_output_a     => "BYPASS",
      clock_enable_output_b     => "BYPASS",
      indata_reg_b              => "CLOCK1",
      intended_device_family    => "Arria GX",
      lpm_type                  => "altsyncram",
      numwords_a                => 512,
      numwords_b                => 512,
      operation_mode            => "BIDIR_DUAL_PORT",
      outdata_aclr_a            => "NONE",
      outdata_aclr_b            => "NONE",
      outdata_reg_a             => "UNREGISTERED",
      outdata_reg_b             => "UNREGISTERED",
      power_up_uninitialized    => "FALSE",
      ram_block_type            => "M4K",
      widthad_a                 => 11,
      widthad_b                 => 11,
      width_a                   => 9,
      width_b                   => 9,
      width_byteena_a           => 1,
      width_byteena_b           => 1,
      wrcontrol_wraddress_reg_b => "CLOCK1"
    )
    port map(
      byteena_a => "1",
      clock0    => CLK,
      clocken1  => M_APVTHRB_V_CE0,
      wren_a    => APV_THR_WR,
      byteena_b => "1",
      clock1    => CLK,
      wren_b    => '0',
      address_a => RAM_THR_ADDRA,
      data_a    => APV_THR,
      address_b => M_APVTHRB_V_ADDRESS0,
      clocken0  => M_APVTHR_V_CE0,
      data_b    => (others=>'0'),
      q_a       => M_APVTHR_V_Q0,
      q_b       => M_APVTHRB_V_Q0
    );

  --AVGB
  altsyncram_component2: altsyncram
    generic map(
      address_reg_b             => "CLOCK1",
      byteena_reg_b             => "CLOCK1",
      byte_size                 => 8,
      clock_enable_input_a      => "NORMAL",
      clock_enable_input_b      => "NORMAL",
      clock_enable_output_a     => "BYPASS",
      clock_enable_output_b     => "BYPASS",
      indata_reg_b              => "CLOCK1",
      intended_device_family    => "Arria GX",
      lpm_type                  => "altsyncram",
      numwords_a                => 512,
      numwords_b                => 512,
      operation_mode            => "BIDIR_DUAL_PORT",
      outdata_aclr_a            => "NONE",
      outdata_aclr_b            => "NONE",
      outdata_reg_a             => "UNREGISTERED",
      outdata_reg_b             => "UNREGISTERED",
      power_up_uninitialized    => "FALSE",
      ram_block_type            => "M4K",
      widthad_a                 => 9,
      widthad_b                 => 9,
      width_a                   => 32,
      width_b                   => 32,
      width_byteena_a           => 4,
      width_byteena_b           => 4,
      wrcontrol_wraddress_reg_b => "CLOCK1"
    )
    port map(
      byteena_a => "1111",
      clock0    => CLK,
      clocken1  => RAM_AVGB_RDEN0,
      wren_a    => '0',
      byteena_b => RAM_AVGB_WE,
      clock1    => CLK,
      wren_b    => RAM_AVGB_WREN0,
      address_a => RAM_AVGB_RDADDR0,
      data_a    => (others=>'0'),
      address_b => RAM_AVGB_WRADDR0,
      clocken0  => '1',
      data_b    => RAM_AVGB_DI,
      q_a       => RAM_AVGB_DO0,
      q_b       => open
    );

  altsyncram_component3: altsyncram
    generic map(
      address_reg_b             => "CLOCK1",
      byteena_reg_b             => "CLOCK1",
      byte_size                 => 8,
      clock_enable_input_a      => "NORMAL",
      clock_enable_input_b      => "NORMAL",
      clock_enable_output_a     => "BYPASS",
      clock_enable_output_b     => "BYPASS",
      indata_reg_b              => "CLOCK1",
      intended_device_family    => "Arria GX",
      lpm_type                  => "altsyncram",
      numwords_a                => 512,
      numwords_b                => 512,
      operation_mode            => "BIDIR_DUAL_PORT",
      outdata_aclr_a            => "NONE",
      outdata_aclr_b            => "NONE",
      outdata_reg_a             => "UNREGISTERED",
      outdata_reg_b             => "UNREGISTERED",
      power_up_uninitialized    => "FALSE",
      ram_block_type            => "M4K",
      widthad_a                 => 9,
      widthad_b                 => 9,
      width_a                   => 32,
      width_b                   => 32,
      width_byteena_a           => 4,
      width_byteena_b           => 4,
      wrcontrol_wraddress_reg_b => "CLOCK1"
    )
    port map(
      byteena_a => "1111",
      clock0    => CLK,
      clocken1  => RAM_AVGB_RDEN1,
      wren_a    => '0',
      byteena_b => RAM_AVGB_WE,
      clock1    => CLK,
      wren_b    => RAM_AVGB_WREN1,
      address_a => RAM_AVGB_RDADDR1,
      data_a    => (others=>'0'),
      address_b => RAM_AVGB_WRADDR1,
      clocken0  => '1',
      data_b    => RAM_AVGB_DI,
      q_a       => RAM_AVGB_DO1,
      q_b       => open
    );
    
end synthesis;
