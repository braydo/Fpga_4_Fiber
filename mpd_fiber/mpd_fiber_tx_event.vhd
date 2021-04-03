library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library altera_mf;
use altera_mf.altera_mf_components.all;

entity mpd_fiber_tx_event is
	port(
		CLK						: in std_logic;

		-- Transceiver Interface
		APVENABLE				: in std_logic_vector(15 downto 0);
		CHANNEL_UP				: in std_logic;
		TX_D						: out std_logic_vector(0 to 15);
		TX_SRC_RDY_N			: out std_logic;
		TX_SOF_N					: out std_logic;
		TX_EOF_N					: out std_logic;
		TX_DST_RDY_N			: in std_logic;

		-- Event builder output
		EVT_FIFO_CLK			: in std_logic;
		EVT_FIFO_FULL			: out std_logic;
		EVT_FIFO_WR				: in std_logic;
		EVT_FIFO_DATA			: in std_logic_vector(31 downto 0);
		EVT_FIFO_END			: in std_logic;

		-- Event flow control
		EVT_FIFO_BUSY			: in std_logic
	);
end mpd_fiber_tx_event;

architecture synthesis of mpd_fiber_tx_event is
	constant SER_TYPE_EVENT			: std_logic_vector(15 downto 0) := x"0002";
	constant SER_TYPE_EVENT_END	: std_logic_vector(15 downto 0) := x"0003";

	type TX_STATE_TYPE is (TX_RESET, TX_IDLE, TX_EVENT_L, TX_EVENT_H);

	signal TX_STATE				: TX_STATE_TYPE;
	signal TX_STATE_NEXT			: TX_STATE_TYPE;

	signal ACLR						: std_logic;
	signal EVT_FIFO_RD			: std_logic;
	signal EVT_FIFO_EMPTY		: std_logic;
	signal EVT_FIFO_DOUT			: std_logic_vector(32 downto 0);
	signal EVT_FIFO_DOUT_H		: std_logic_vector(15 downto 0);
	signal EVT_FIFO_DOUT_END	: std_logic;
	signal TX_TYPE_EVENT			: std_logic;
	signal TX_TYPE_EVENT_END	: std_logic;
	signal TX_FIFO_L				: std_logic;
	signal TX_FIFO_H				: std_logic;
	signal CNT						: std_logic_vector(8 downto 0);
	signal CNT_RST					: std_logic;
	signal CNT_INC					: std_logic;
	signal CNT_DONE				: std_logic;
begin

	TX_D <= SER_TYPE_EVENT              when TX_TYPE_EVENT     = '1' else
	        SER_TYPE_EVENT_END          when TX_TYPE_EVENT_END = '1' else
			  EVT_FIFO_DOUT(15 downto 0)  when TX_FIFO_L = '1' else
			  EVT_FIFO_DOUT_H; -- when TX_FIFO_H = '1'

	EVT_FIFO_DOUT_END <= EVT_FIFO_DOUT(32);

	ACLR <= not CHANNEL_UP;

	CNT_DONE <= '1' when unsigned(CNT) >= 65 else '0';
	
	----------------------------------------
	-- Event Data Buffer
	----------------------------------------
	dcfifo_inst: dcfifo
		generic map(
			intended_device_family	=> "Arria GX",
			lpm_hint						=> "MAXIMIZE_SPEED=5,RAM_BLOCK_TYPE=AUTO",
			lpm_numwords				=> 128,
			lpm_showahead				=> "ON",
			lpm_type						=> "dcfifo",
			lpm_width					=> 33,
			lpm_widthu					=> 7,
			overflow_checking			=> "ON",
			rdsync_delaypipe			=> 5,
			underflow_checking		=> "ON",
			use_eab						=> "ON",
			write_aclr_synch			=> "ON",
			wrsync_delaypipe			=> 5
		)
		port map(
			rdclk						=> CLK,
			wrclk						=> EVT_FIFO_CLK,
			wrreq						=> EVT_FIFO_WR,
			aclr						=> ACLR,
			data(31 downto 0)		=> EVT_FIFO_DATA,
			data(32)					=> EVT_FIFO_END,
			rdreq						=> EVT_FIFO_RD,
			wrfull					=> EVT_FIFO_FULL,
			q							=> EVT_FIFO_DOUT,
			rdempty					=> EVT_FIFO_EMPTY
		);

	----------------------------------------
	-- Event Transmitter State Machine
	----------------------------------------
	process(CLK)
	begin
		if rising_edge(CLK) then
			if CHANNEL_UP = '0' then
				TX_STATE <= TX_RESET;
			else
				TX_STATE <= TX_STATE_NEXT;
			end if;
			
			if EVT_FIFO_RD = '1' then
				EVT_FIFO_DOUT_H <= EVT_FIFO_DOUT(31 downto 16);
			end if;
			
			if CNT_RST = '1' then
				CNT <= (others=>'0');
			elsif CNT_INC = '1' then
				CNT <= std_logic_vector(unsigned(CNT)+1);
			end if;
		end if;
	end process;

	process(TX_STATE, EVT_FIFO_EMPTY, TX_DST_RDY_N, EVT_FIFO_DOUT_END, EVT_FIFO_BUSY, CNT_DONE)
	begin
		TX_STATE_NEXT <= TX_STATE;
		TX_SRC_RDY_N <= '1';
		TX_SOF_N <= '1';
		TX_EOF_N <= '1';
		EVT_FIFO_RD <= '0';
		TX_TYPE_EVENT <= '0';
		TX_TYPE_EVENT_END <= '0';
		TX_FIFO_L <= '0';
		TX_FIFO_H <= '0';
		CNT_INC <= '0';
		CNT_RST <= '0';
	
		case TX_STATE is
			when TX_RESET =>
				TX_STATE_NEXT <= TX_IDLE;

			when TX_IDLE =>
				if (EVT_FIFO_EMPTY = '0') and (EVT_FIFO_BUSY = '0') and (EVT_FIFO_DOUT_END = '1') then
					TX_SRC_RDY_N <= '0';
					TX_SOF_N <= '0';
					TX_EOF_N <= '0';
					if TX_DST_RDY_N = '0' then
						TX_TYPE_EVENT_END <= '1';
						EVT_FIFO_RD <= '1';
					end if;
				elsif (EVT_FIFO_EMPTY = '0') and (EVT_FIFO_BUSY = '0') and (EVT_FIFO_DOUT_END = '0') then
					TX_SRC_RDY_N <= '0';
					TX_SOF_N <= '0';
					TX_TYPE_EVENT <= '1';
					if TX_DST_RDY_N = '0' then
						CNT_RST <= '1';
						TX_STATE_NEXT <= TX_EVENT_L;
					end if;
				end if;
				
			when TX_EVENT_L =>
				TX_FIFO_L <= '1';
				TX_SRC_RDY_N <= '0';
				if TX_DST_RDY_N = '0' then
					CNT_INC <= '1';
					EVT_FIFO_RD <= '1';
					TX_STATE_NEXT <= TX_EVENT_H;
				end if;
				
			when TX_EVENT_H =>
				TX_FIFO_H <= '1';
				TX_SRC_RDY_N <= '0';
				if TX_DST_RDY_N = '0' then
					if (EVT_FIFO_EMPTY = '1') or (EVT_FIFO_EMPTY = '0' and EVT_FIFO_DOUT_END = '1') or (CNT_DONE = '1') then
						TX_EOF_N <= '0';
						TX_STATE_NEXT <= TX_IDLE;
					else
						TX_STATE_NEXT <= TX_EVENT_L;
					end if;
				end if;

			when others =>
				TX_STATE_NEXT <= TX_IDLE;
		end case;
	end process;

end synthesis;
