onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate -divider {VME BUS}
add wave -noupdate -label VME_A -radix hexadecimal /_a_TestBench/Dut/VME_A
add wave -noupdate -label VME_D -radix hexadecimal /_a_TestBench/Dut/VME_D
add wave -noupdate -label WRITEb /_a_TestBench/Dut/VME_WRITEb
add wave -noupdate -label DS0b /_a_TestBench/Dut/VME_DS0b
add wave -noupdate -label DS1b /_a_TestBench/Dut/VME_DS1b
add wave -noupdate -label ASb /_a_TestBench/Dut/VME_ASb
add wave -noupdate -label DTACKb /_a_TestBench/Dut/VME_DTACKb
add wave -noupdate -label BERRb /_a_TestBench/Dut/VME_BERRb
add wave -noupdate -label RETRYb /_a_TestBench/Dut/VME_RETRYb
add wave -noupdate -divider {User Signals}
add wave -noupdate -label SdramInitialized /_a_TestBench/Dut/SdramInitialized
add wave -noupdate -label Vme_Fiber_Disable /_a_TestBench/Dut/Vme_Fiber_disable
add wave -noupdate -label Vme_ConfigReg_ceB /_a_TestBench/Dut/Vme_ConfigReg_ceB
add wave -noupdate -label ConfigReg_ceB /_a_TestBench/Dut/ConfigReg_ceB
add wave -noupdate -label internal_detect /_a_TestBench/Dut/VmeIf/internal_detect
add wave -noupdate -label internal_data -radix hexadecimal /_a_TestBench/Dut/VmeIf/internal_data
add wave -noupdate -label we_ped_ram -radix hexadecimal /_a_TestBench/Dut/we_ped_ram
add wave -noupdate -label re_ped_ram -radix hexadecimal /_a_TestBench/Dut/re_ped_ram
add wave -noupdate -label we_thr_ram -radix hexadecimal /_a_TestBench/Dut/we_thr_ram
add wave -noupdate -label scl /_a_TestBench/i2c_scl
add wave -noupdate -label sda /_a_TestBench/i2c_sda
add wave -noupdate -label a24_cycle /_a_TestBench/Dut/VmeIf/a24_cycle
add wave -noupdate -label a32_cycle /_a_TestBench/Dut/VmeIf/a32_cycle
add wave -noupdate -label bar -radix hexadecimal /_a_TestBench/Dut/VmeIf/bar
add wave -noupdate -label module_selected /_a_TestBench/Dut/VmeIf/module_selected
add wave -noupdate -label SDRAM_CEb /_a_TestBench/Dut/VmeIf/SDRAM_CEb
add wave -noupdate -label user_addr -radix hexadecimal /_a_TestBench/Dut/user_addr
add wave -noupdate -label user_ceB -radix hexadecimal /_a_TestBench/Dut/user_ceB
add wave -noupdate -label user_weB /_a_TestBench/Dut/user_weB
add wave -noupdate -label user_oeB /_a_TestBench/Dut/user_oeB
add wave -noupdate -label user_reB /_a_TestBench/Dut/user_reB
add wave -noupdate -label user_waitB /_a_TestBench/Dut/Vme_user_waitB
add wave -noupdate -label LdBeatCounter /_a_TestBench/Dut/VmeIf/DataCycleController/ld_beat_counter
add wave -noupdate -label BeatCounter -radix hexadecimal /_a_TestBench/Dut/VmeIf/DataCycleController/beat_counter
add wave -noupdate -label RateCode -radix hexadecimal /_a_TestBench/Dut/VmeIf/DataCycleController/rate_code
add wave -noupdate -label VmeStatus -radix unsigned /_a_TestBench/Dut/VmeIf/DataCycleController/status
add wave -noupdate -divider ADC
add wave -noupdate -label CONV_CK1 /_a_TestBench/Dut/ADC_CONV_CK1
add wave -noupdate -label ADC_DATA -radix hexadecimal /_a_TestBench/Dut/ADC_DATA
add wave -noupdate -label LCLK1 /_a_TestBench/Dut/ADC_LCLK1
add wave -noupdate -label ADC_FRAME_CK1 /_a_TestBench/Dut/ADC_FRAME_CK1
add wave -noupdate -label {Pdata 0} -radix hexadecimal /_a_TestBench/Dut/AdcDeser0/Deser0/PDATA
add wave -noupdate -divider APV
add wave -noupdate -label CLOCK /_a_TestBench/Dut/APV_CLOCK
add wave -noupdate -label TRIGGER /_a_TestBench/Dut/APV_TRIGGER
add wave -noupdate -label BusyOut /_a_TestBench/Dut/BUSY_OUT
add wave -noupdate -divider {APVDecoder 0}
add wave -noupdate -label FIFO_DATA_OUT -radix hexadecimal /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/ApvFrameDecoder/FIFO_DATA_OUT
add wave -noupdate -label FIFO_RD /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/ApvFrameDecoder/FIFO_RD
add wave -noupdate -label FIFO_EMPTY /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/FIFO_EMPTY
add wave -noupdate -label FIFO_FULL /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/FIFO_FULL
add wave -noupdate -label FIFO_USED_WORDS -radix unsigned /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/FIFO_USED_WORDS
add wave -noupdate -label fifo_data_in -radix hexadecimal /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/ApvFrameDecoder/fifo_data_in
add wave -noupdate -label fifo_write /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/ApvFrameDecoder/fifo_write
add wave -noupdate -label end_processing /_a_TestBench/Dut/ApvProcessor_0_7/Ch0/end_processing
add wave -noupdate -divider EventBuilder
add wave -noupdate -label FsmStatus -radix unsigned /_a_TestBench/Dut/TheBuilder/fsm_status
add wave -noupdate -label TmeCounterRd /_a_TestBench/Dut/TheBuilder/TimeCounterFifo_Read
add wave -noupdate -label EventCounterRd /_a_TestBench/Dut/TheBuilder/EventCounterFifo_Read
add wave -noupdate -label DataRd -radix hexadecimal /_a_TestBench/Dut/TheBuilder/DATA_RD
add wave -noupdate -label ChCounter -radix hexadecimal /_a_TestBench/Dut/TheBuilder/ChCounter
add wave -noupdate -label dataIn -radix hexadecimal /_a_TestBench/Dut/TheBuilder/CH_DATA8
add wave -noupdate -label FifoDataIn -radix hexadecimal /_a_TestBench/Dut/TheBuilder/data_bus
add wave -noupdate -label FifoWr /_a_TestBench/Dut/TheBuilder/OutputFifo_Write
add wave -noupdate -label FifoDataOut -radix hexadecimal /_a_TestBench/Dut/EvBuilderDataOut
add wave -noupdate -label LoopSampleCounter -radix unsigned /_a_TestBench/Dut/TheBuilder/LoopSampleCounter
add wave -noupdate -label LoopEventCounter -radix unsigned /_a_TestBench/Dut/TheBuilder/LoopEventCounter
add wave -noupdate -label DataWordCounter -radix hexadecimal /_a_TestBench/Dut/TheBuilder/DataWordCount
add wave -noupdate -divider {Sdram FIFO}
add wave -noupdate -label EventBuilder_Read /_a_TestBench/Dut/EventBuilder_Read
add wave -noupdate -label ReqFsmStatus -radix decimal /_a_TestBench/Dut/SdramFifoHandler/ReadHandler/fsm_req_status
add wave -noupdate -label RdFsmStatus -radix decimal /_a_TestBench/Dut/SdramFifoHandler/ReadHandler/fsm_rd_status
add wave -noupdate -label SdramBurstCount -radix hexadecimal /_a_TestBench/Dut/SdramFifoHandler/ReadHandler/SdramBurstCount
add wave -noupdate -label OddData /_a_TestBench/Dut/SdramFifoHandler/ReadHandler/odd_data
add wave -noupdate -label OutFifoWrite /_a_TestBench/Dut/SdramFifoHandler/OutputFifoWr
add wave -noupdate -label Data64Bit -radix hexadecimal /_a_TestBench/Dut/SdramFifoHandler/Data64Bit
add wave -noupdate -label WrFsmIdle /_a_TestBench/Dut/SdramFifoHandler/WriteFsmIdle
add wave -noupdate -label RdFsmIdle /_a_TestBench/Dut/SdramFifoHandler/ReadFsmIdle
add wave -noupdate -label SdramWriteAddr -radix hexadecimal /_a_TestBench/Dut/SdramFifoHandler/SDRAM_WRITE_ADDRESS
add wave -noupdate -label Wr_fsm_status -radix decimal /_a_TestBench/Dut/SdramFifoHandler/WriteHandler/fsm_status
add wave -noupdate -label SdramReadAddr -radix hexadecimal /_a_TestBench/Dut/SdramFifoHandler/SDRAM_READ_ADDRESS
add wave -noupdate -label Sdram_Wdata -radix hexadecimal /_a_TestBench/Dut/mem_local_wdata
add wave -noupdate -label mem_wr_req /_a_TestBench/Dut/mem_local_write_req
add wave -noupdate -label mem_ready /_a_TestBench/Dut/mem_local_ready
add wave -noupdate -label mem_rd_req /_a_TestBench/Dut/mem_local_read_req
add wave -noupdate -label mem_rdata_valid /_a_TestBench/Dut/mem_local_rdata_valid
add wave -noupdate -label mem_addr -radix hexadecimal /_a_TestBench/Dut/mem_local_addr
add wave -noupdate -divider DEBUG
add wave -noupdate -label ApvFifo_ceB /_a_TestBench/Dut/ApvFifo_ceB
add wave -noupdate -label ThrRam_ceB /_a_TestBench/Dut/ThrRam_ceB
add wave -noupdate -label PedRam_ceB /_a_TestBench/Dut/PedRam_ceB
add wave -noupdate -label we_ped_ram -radix hexadecimal /_a_TestBench/Dut/we_ped_ram
add wave -noupdate -label we_thr_ram -radix hexadecimal /_a_TestBench/Dut/we_thr_ram
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {499826526 ps} 0} {{Cursor 2} {239713121 ps} 0}
quietly wave cursor active 2
configure wave -namecolwidth 150
configure wave -valuecolwidth 102
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits ns
update
WaveRestoreZoom {239588855 ps} {241421124 ps}
