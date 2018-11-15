`include "board_common.vh"

module pci_exp_usrapp_tx #(
  parameter       AXISTEN_IF_CC_PARITY_CHECK        = 0,
  parameter       AXISTEN_IF_RQ_ALIGNMENT_MODE      = "FALSE",
  parameter       AXISTEN_IF_CC_ALIGNMENT_MODE      = "FALSE",
  parameter       AXISTEN_IF_CQ_ALIGNMENT_MODE      = "FALSE",
  parameter       AXISTEN_IF_RC_ALIGNMENT_MODE      = "FALSE",
  parameter       DEV_CAP_MAX_PAYLOAD_SUPPORTED     = 3,
  parameter       C_DATA_WIDTH                      = 512,
  parameter       KEEP_WIDTH                        = C_DATA_WIDTH / 32,
  parameter       STRB_WIDTH                        = C_DATA_WIDTH / 8,
  parameter       EP_DEV_ID                         = 16'h7700,
  parameter       REM_WIDTH                         = C_DATA_WIDTH == 512,
  parameter [5:0] RP_BAR_SIZE                       = 6'd11
  // ^--- Number of RP BAR's Address Bit - 1
)
(
  output reg                    s_axis_rq_tlast,
  output reg [C_DATA_WIDTH-1:0] s_axis_rq_tdata,
  output     [           136:0] s_axis_rq_tuser,
  output reg [  KEEP_WIDTH-1:0] s_axis_rq_tkeep,
  input                         s_axis_rq_tready,
  output reg                    s_axis_rq_tvalid,

  output reg [C_DATA_WIDTH-1:0] s_axis_cc_tdata,
  output reg [            82:0] s_axis_cc_tuser,
  output reg                    s_axis_cc_tlast,
  output reg [  KEEP_WIDTH-1:0] s_axis_cc_tkeep,
  output reg                    s_axis_cc_tvalid,
  input                         s_axis_cc_tready,

  input      [             3:0] pcie_rq_seq_num,
  input                         pcie_rq_seq_num_vld,
  input      [             5:0] pcie_rq_tag,
  input                         pcie_rq_tag_vld,
  input      [             1:0] pcie_tfc_nph_av,
  input      [             1:0] pcie_tfc_npd_av,
  input                         speed_change_done_n,
  input                         user_clk,
  input                         reset,
  input                         user_lnk_up
);

parameter    Tcq = 1;

localparam [ 4:0] LINK_CAP_MAX_LINK_WIDTH = 5'h1;
localparam [ 3:0] LINK_CAP_MAX_LINK_SPEED = 4'h1;
localparam [ 3:0] MAX_LINK_SPEED         
                = (LINK_CAP_MAX_LINK_SPEED==4'h8) ? 4'h4
                : (LINK_CAP_MAX_LINK_SPEED==3'h4) ? 4'h3
                : (LINK_CAP_MAX_LINK_SPEED==3'h2) ? 4'h2
                :                                   4'h1;
localparam [ 5:0] BAR_ENABLED             = 6'b000001 ;
localparam [11:0] DEV_CTRL_REG_ADDR       = 12'h078;

reg [C_DATA_WIDTH-1:0] pcie_tlp_data;
reg [   REM_WIDTH-1:0] pcie_tlp_rem;


/* Local Variables */
integer     i, j, k;
reg [  7:0] DATA_STORE   [4095:0]; // For Downstream Direction Data Storage
reg [  7:0] DATA_STORE_2 [(2**(RP_BAR_SIZE+1))-1:0];
 // ^-- For Upstream Direction Data Storage
reg [ 15:0] EP_BUS_DEV_FNS;
reg [ 15:0] RP_BUS_DEV_FNS;
reg [  2:0] DEFAULT_TC;
reg [  1:0] DEFAULT_ATTR;
reg [  7:0] DEFAULT_TAG;
reg         TD;
reg         EP;

event       test_begin;

reg [ 31:0] P_ADDRESS_MASK;
reg [ 31:0] P_READ_DATA;
 // ^-- will store the 1st DW (lo) of a PCIE read completion
reg [ 31:0] P_READ_DATA_2;
 // ^-- will store the 2nd DW (hi) of a PCIE read completion
reg         P_READ_DATA_VALID;
reg [ 31:0] data;

// BAR Init variables
reg [ 32:0] BAR_INIT_P_BAR[6:0]; // 6 corresponds to Expansion ROM
                                 // note that bit 32 is for overflow checking
reg [ 31:0] BAR_INIT_P_BAR_RANGE[6:0];   // 6 corresponds to Expansion ROM
reg [  1:0] BAR_INIT_P_BAR_ENABLED[6:0]; // 6 corresponds to Expansion ROM
// ^-- 0 = disabled;  1 = io mapped;  2 = mem32 mapped;  3 = mem64 mapped

reg [ 31:0] BAR_INIT_P_MEM64_HI_START; // start address for hi memory space
reg [ 31:0] BAR_INIT_P_MEM64_LO_START; // start address for hi memory space
reg [ 32:0] BAR_INIT_P_MEM32_START;    // start address for low memory space
                                       // top bit used for overflow indicator
reg [ 32:0] BAR_INIT_P_IO_START;       // start address for io space
reg [100:0] BAR_INIT_MESSAGE[3:0];     // to be used to display info to user

reg [ 32:0] BAR_INIT_TEMP;

reg         OUT_OF_LO_MEM; // flags to indicate out of mem, mem64, and io
reg         OUT_OF_IO;

integer     NUMBER_OF_IO_BARS;
integer     NUMBER_OF_MEM32_BARS; // Not counting the Mem32 EROM space
integer     NUMBER_OF_MEM64_BARS;

reg [  3:0] ii;
integer     jj;

integer     PIO_MAX_NUM_BLOCK_RAMS; // holds the max number of block RAMS

reg         cpld_to;
// ^-- boolean value to indicate if time out has occured while waiting for cpld

wire        user_lnk_up_n;
wire [63:0] s_axis_cc_tparity;
wire [63:0] s_axis_rq_tparity;

integer     test_vars [31:0];
reg [  7:0] exp_tag;
reg [136:0] s_axis_rq_tuser_wo_parity;

assign s_axis_rq_tuser = {64'b0, s_axis_rq_tuser_wo_parity[72:0]};
assign user_lnk_up_n = ~user_lnk_up;

/************************************************************
 Initial Statements
*************************************************************/
initial begin
  s_axis_rq_tlast           = 0;
  s_axis_rq_tdata           = 0;
  s_axis_rq_tuser_wo_parity = 0;
  s_axis_rq_tkeep           = 0;
  s_axis_rq_tvalid          = 0;
  s_axis_cc_tdata           = 0;
  s_axis_cc_tuser           = 0;
  s_axis_cc_tlast           = 0;
  s_axis_cc_tkeep           = 0;
  s_axis_cc_tvalid          = 0;

  EP_BUS_DEV_FNS = 16'b0000_0001_0000_0000;
  RP_BUS_DEV_FNS = 16'b0000_0000_0000_0000;
  DEFAULT_TC     = 3'b000;
  DEFAULT_ATTR   = 2'b01;
  DEFAULT_TAG    = 8'h00;
  TD             = 0;
  EP             = 0;

  //-----------------------------------------------------------------------\\
  // Pre-BAR initialization
  BAR_INIT_MESSAGE[0] = "DISABLED";
  BAR_INIT_MESSAGE[1] = "IO MAPPED";
  BAR_INIT_MESSAGE[2] = "MEM32 MAPPED";
  BAR_INIT_MESSAGE[3] = "MEM64 MAPPED";

  OUT_OF_LO_MEM = 1'b0;
  OUT_OF_IO     = 1'b0;

  // Disable variables to start
  for (ii = 0; ii <= 6; ii = ii + 1) begin
    BAR_INIT_P_BAR[ii]         = 33'h00000_0000;
    BAR_INIT_P_BAR_RANGE[ii]   = 32'h0000_0000;
    BAR_INIT_P_BAR_ENABLED[ii] = 2'b00;
  end

  BAR_INIT_P_MEM64_HI_START = 32'h0000_0001;
  // ^-- hi 32 bit start of 64bit memory
  BAR_INIT_P_MEM64_LO_START = 32'h0000_0000;
  // ^-- low 32 bit start of 64bit memory
  BAR_INIT_P_MEM32_START    = 33'h00000_0000; // start of 32bit memory
  BAR_INIT_P_IO_START       = 33'h00000_0000; // start of 32bit io

  PIO_MAX_NUM_BLOCK_RAMS    = 4; // PIO has four block RAMS to test
  cpld_to                   = 0; // By default time out has not occured

  NUMBER_OF_IO_BARS         = 0;
  NUMBER_OF_MEM32_BARS      = 0;
  NUMBER_OF_MEM64_BARS      = 0;
end
//-----------------------------------------------------------------------\\

function [31:0] data_store_4(
 input [11:0] i3, input [11:0] i2, input [11:0] i1, input [11:0] i0);
begin
  data_store_4[31:24] = DATA_STORE[i3];
  data_store_4[23:16] = DATA_STORE[i2];
  data_store_4[15: 8] = DATA_STORE[i1];
  data_store_4[ 7: 0] = DATA_STORE[i0];
end
endfunction

function cmp_rddata_32(input [31:0] expc);
reg testError;
begin
  testError = 1'b0;
  if ( P_READ_DATA != expc ) begin
    testError=1'b1;
    $display("[%t] : Test FAILED --- Data Error Mismatch, Write Data %x != Read Data %x",
     $realtime, expc, P_READ_DATA);
  end else begin
    $display("[%t] : Test PASS --- 1DW Write Data: %x successfully received",
     $realtime, P_READ_DATA);
  end
  cmp_rddata_32 = testError;
end
endfunction

function cmp_rddata_64(input [63:0] expc);
reg testError;
begin
  testError = 1'b0;
  if ( {P_READ_DATA, P_READ_DATA_2} != expc ) begin
    testError=1'b1;
    $display("[%t] : Test FAILED --- Data Error Mismatch, Write Data %x != Read Data %x",
     $realtime, expc, {P_READ_DATA, P_READ_DATA_2});
  end else begin
    $display("[%t] : Test PASS --- 2DW Write Data: %x successfully received",
     $realtime, {P_READ_DATA, P_READ_DATA_2});
  end
  cmp_rddata_64 = testError;
end
endfunction

task test1_io(input [3:0] ii, output testError);
begin
  testError = 1'b0;

  $display("[%t] : Transmitting TLPs to IO Space BAR %x", $realtime, ii);

  //----------------------------------------
  // Event : IO Write bit TLP
  //----------------------------------------
  TSK_TX_IO_WRITE(DEFAULT_TAG, BAR_INIT_P_BAR[ii][31:0], 4'hF,
   32'hdead_beef);
  @(posedge pcie_rq_tag_vld);
  exp_tag = pcie_rq_tag;

  board.RP.com_usrapp.TSK_EXPECT_CPL(3'h0, 1'b0, 1'b0, 2'b0,
   EP_BUS_DEV_FNS, 3'h0, 1'b0, 12'h4,
   RP_BUS_DEV_FNS, exp_tag, BAR_INIT_P_BAR[ii][31:0], test_vars[0]);

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  //----------------------------------------
  // Event : IO Read bit TLP
  //----------------------------------------

  // make sure P_READ_DATA has known initial value
  P_READ_DATA = 32'hffff_ffff;
  fork
    TSK_TX_IO_READ(DEFAULT_TAG, BAR_INIT_P_BAR[ii][31:0], 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError | cmp_rddata_32(32'hdead_beef);

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;
end
endtask

task test1_mem32(input [3:0] ii, output testError);
begin
  testError = 1'b0;
  // PIO_READWRITE_TEST CASE for C_AXIS_WIDTH == 64 
  $display("[%t] : Transmitting TLPs to Memory 32 Space BAR %x",
   $realtime, ii);

  //----------------------------------------
  // Event : Memory Write 32 bit TLP
  //----------------------------------------
  DATA_STORE[0] = {ii,4'h4};
  DATA_STORE[1] = {ii,4'h3};
  DATA_STORE[2] = {ii,4'h2};
  DATA_STORE[3] = {ii,4'h1};
                          
  // Default 1DW PIO
  TSK_TX_MEMORY_WRITE_32(DEFAULT_TAG, DEFAULT_TC, 11'd1,
   BAR_INIT_P_BAR[ii][31:0]+8'h10+(ii*8'h40), 4'h0, 4'hF, 1'b0);
  TSK_TX_CLK_EAT(100);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  //----------------------------------------
  // Event : Memory Read 32 bit TLP
  //----------------------------------------

  // make sure P_READ_DATA has known initial value
  P_READ_DATA = 32'hffff_ffff;
                         
  // Default 1DW PIO
  fork
    TSK_TX_MEMORY_READ_32(DEFAULT_TAG, DEFAULT_TC, 11'd1,
     BAR_INIT_P_BAR[ii][31:0]+8'h10+(ii*8'h40), 4'h0, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError | cmp_rddata_32(data_store_4(3, 2, 1, 0));

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  // Optional 2DW PIO
  DATA_STORE[0] = {ii+4'hA,4'h4};
  DATA_STORE[1] = {ii+4'hA,4'h3};
  DATA_STORE[2] = {ii+4'hA,4'h2};
  DATA_STORE[3] = {ii+4'hA,4'h1};
                                                   
  TSK_TX_MEMORY_WRITE_32(DEFAULT_TAG, DEFAULT_TC, 11'd2,
     BAR_INIT_P_BAR[ii][31:0]+8'h14+(ii*8'h40), 4'hF, 4'hF, 1'b0);
  TSK_TX_CLK_EAT(100);
  DEFAULT_TAG = DEFAULT_TAG + 1;                   
  fork
    TSK_TX_MEMORY_READ_32(DEFAULT_TAG, DEFAULT_TC, 11'd2,
     BAR_INIT_P_BAR[ii][31:0]+8'h14+(ii*8'h40), 4'hF, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError | cmp_rddata_64({2{data_store_4(3, 2, 1, 0)}});

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  // Optional 192 DW PIO
  DATA_STORE[0] = {ii+4'hB,4'h4};
  DATA_STORE[1] = {ii+4'hB,4'h3};
  DATA_STORE[2] = {ii+4'hB,4'h2};
  DATA_STORE[3] = {ii+4'hB,4'h1};
                                                 
  TSK_TX_MEMORY_WRITE_32(DEFAULT_TAG, DEFAULT_TC, 11'd100,
   BAR_INIT_P_BAR[ii][31:0]+8'h20+(ii*8'h40), 4'hF, 4'hF, 1'b0);
  TSK_TX_CLK_EAT(100);
  DEFAULT_TAG = DEFAULT_TAG + 1;
 
  fork
    TSK_TX_MEMORY_READ_32(DEFAULT_TAG, DEFAULT_TC, 11'd100,
     BAR_INIT_P_BAR[ii][31:0]+8'h20+(ii*8'h40), 4'hF, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError | cmp_rddata_64({2{data_store_4(3, 2, 1, 0)}});

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1; 
end
endtask

task test1_mem64(input [3:0] ii, output testError);
begin
  testError = 1'b0;
  $display("[%t] : Transmitting TLPs to Memory 64 Space BAR %x",
   $realtime, ii);

  //----------------------------------------
  // Event : Memory Write 64 bit TLP
  //----------------------------------------
  DATA_STORE[0] = {ii+6,4'h4};
  DATA_STORE[1] = {ii+6,4'h3};
  DATA_STORE[2] = {ii+6,4'h2};
  DATA_STORE[3] = {ii+6,4'h1};
  DATA_STORE[4] = {ii+6,4'h8};
  DATA_STORE[5] = {ii+6,4'h7};
  DATA_STORE[6] = {ii+6,4'h6};
  DATA_STORE[7] = {ii+6,4'h5};

  // Default 1DW PIO
  TSK_TX_MEMORY_WRITE_64(DEFAULT_TAG, DEFAULT_TC, 10'd1,
   {BAR_INIT_P_BAR[ii+1][31:0] ,
    BAR_INIT_P_BAR[ii][31:0]+8'h20+(ii*8'h20)},
   4'h0, 4'hF, 1'b0);
  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  //----------------------------------------
  // Event : Memory Read 64 bit TLP
  //----------------------------------------

  // make sure P_READ_DATA has known initial value
  P_READ_DATA = 32'hffff_ffff;

  // Default 1DW PIO
  fork
    TSK_TX_MEMORY_READ_64(DEFAULT_TAG, DEFAULT_TC, 10'd1,
     {BAR_INIT_P_BAR[ii+1][31:0],
      BAR_INIT_P_BAR[ii][31:0]+8'h20+(ii*8'h20)},
     4'h0, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError | cmp_rddata_32(data_store_4(3, 2, 1, 0));

  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;

  // Optional 2DW PIO
  DATA_STORE[0] = {ii+4'hA,4'h4};
  DATA_STORE[1] = {ii+4'hA,4'h3};
  DATA_STORE[2] = {ii+4'hA,4'h2};
  DATA_STORE[3] = {ii+4'hA,4'h1};
  DATA_STORE[4] = {ii+4'hA,4'h8};
  DATA_STORE[5] = {ii+4'hA,4'h7};
  DATA_STORE[6] = {ii+4'hA,4'h6};
  DATA_STORE[7] = {ii+4'hA,4'h5};
 
  TSK_TX_MEMORY_WRITE_64(DEFAULT_TAG, DEFAULT_TC, 10'd2,
   {BAR_INIT_P_BAR[ii+1][31:0],
    BAR_INIT_P_BAR[ii][31:0]+8'h24+(ii*8'h20)},
   4'hF, 4'hF, 1'b0);
  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;
 
  fork
    TSK_TX_MEMORY_READ_64(DEFAULT_TAG, DEFAULT_TC, 10'd2,
     {BAR_INIT_P_BAR[ii+1][31:0],
      BAR_INIT_P_BAR[ii][31:0]+8'h24+(ii*8'h20)},
     4'hF, 4'hF);
    TSK_WAIT_FOR_READ_DATA;
  join
  testError = testError
            | cmp_rddata_64( { data_store_4(7, 6, 5, 4)
                             , data_store_4(3, 2, 1, 0) } );
  TSK_TX_CLK_EAT(10);
  DEFAULT_TAG = DEFAULT_TAG + 1;
end
endtask

task test_main;
reg testError, te_tmp;
begin
  testError = 1'b0;
  //--------------------------------------------------------------------------
  // Event : Testing BARs
  //--------------------------------------------------------------------------
  for (ii = 0; ii <= 6; ii = ii + 1) begin
    if (BAR_INIT_P_BAR_ENABLED[ii] > 2'b00) begin
      case (BAR_INIT_P_BAR_ENABLED[ii])
      2'b01  : test1_io(ii, te_tmp);
      2'b10  : test1_mem32(ii, te_tmp);
      2'b11  : test1_mem64(ii, te_tmp);
      default: $display("Error case in usrapp_tx\n");
      endcase
      testError = testError | te_tmp;
    end
  end

  if(testError==1'b0)
  $display("[%t] : PASS - Test Completed Successfully",$realtime);

  if(testError==1'b1)
  $display("[%t] : FAIL - Test FAILED due to previous error ",$realtime);

  $display("[%t] : Finished transmission of PCI-Express TLPs", $realtime);
end
endtask

initial begin
  // Tx transaction interface signal initialization.
  pcie_tlp_data = 0;
  pcie_tlp_rem  = 0;

  // Payload data initialization.
  TSK_USR_DATA_SETUP_SEQ;

  //Test starts here
  // This test performs a 32 bit write to a 32 bit Memory space and performs a read back
  TSK_SYSTEM_INITIALIZATION;
  TSK_BAR_INIT;
        
  //--------------------------------------------------------------------------
  // Direct Root Port to allow upstream traffic by enabling Mem, I/O and
  // BusMstr in the command register
  //--------------------------------------------------------------------------

  board.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);
  board.RP.cfg_usrapp.TSK_WRITE_CFG_DW(32'h00000001, 32'h00000007, 4'b1110);
  board.RP.cfg_usrapp.TSK_READ_CFG_DW(32'h00000001);

  test_main;

  $finish;
end
//-----------------------------------------------------------------------\\

/************************************************************
Task : TSK_SYSTEM_INITIALIZATION
Inputs : None
Outputs : None
Description : Waits for Transaction Interface Reset and Link-Up
*************************************************************/
task TSK_SYSTEM_INITIALIZATION;
begin
  //--------------------------------------------------------------------------
  // Event # 1: Wait for Transaction reset to be de-asserted...
  //--------------------------------------------------------------------------
  wait (reset == 0);
  $display("[%t] : Transaction Reset Is De-asserted...", $realtime);

  //--------------------------------------------------------------------------
  // Event # 2: Wait for Transaction link to be asserted...
  //--------------------------------------------------------------------------
  board.RP.cfg_usrapp.TSK_WRITE_CFG_DW(32'h01, 32'h00000007, 4'h1);
		
  // RP -- Program PCIe Device Control Register for max payload size == 1024 bytes
  $display("[%t] : Reading RP DEV CTL REG 0x78", $realtime);
  board.RP.cfg_usrapp.TSK_READ_CFG_DW(DEV_CTRL_REG_ADDR/4);	
  $display("[%t] : RP DEV CTL REG is %x", $realtime,
   board.RP.cfg_usrapp.cfg_mgmt_read_data);
        
  board.RP.cfg_usrapp.TSK_WRITE_CFG_DW
  ( DEV_CTRL_REG_ADDR/4
  , ( board.RP.cfg_usrapp.cfg_mgmt_read_data
    | (DEV_CAP_MAX_PAYLOAD_SUPPORTED * 32) )
  , 4'h1);
        
  $display("[%t] : Reading RP DEV CTL REG 0x78", $realtime);
  board.RP.cfg_usrapp.TSK_READ_CFG_DW(DEV_CTRL_REG_ADDR/4);    
  $display("[%t] : RP DEV CTL REG is %x", $realtime,
   board.RP.cfg_usrapp.cfg_mgmt_read_data);

  TSK_TX_CLK_EAT(100);
  wait (board.RP.pcie_4_0_rport.user_lnk_up == 1);
  TSK_TX_CLK_EAT(100);
  $display("[%t] : Transaction Link Is Up...", $realtime);
        
  // EP -- Program PCIe Device Control Register for max payload size == 1024 bytes
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h78, 4'hF);
  TSK_WAIT_FOR_READ_DATA;

  TSK_TX_TYPE0_CONFIGURATION_WRITE
  ( DEFAULT_TAG, 12'h78
  , (P_READ_DATA | (DEV_CAP_MAX_PAYLOAD_SUPPORTED * 32))
  , 4'h1);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_TX_CLK_EAT(1000);
       
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h78, 4'hF);
  TSK_WAIT_FOR_READ_DATA;
  $display("[%t] : EP DEV CTRL REG Read data %x", $realtime,  P_READ_DATA);

  TSK_SYSTEM_CONFIGURATION_CHECK;
end
endtask

/************************************************************
Task : TSK_SYSTEM_CONFIGURATION_CHECK
Inputs : None
Outputs : None
Description : Check that options selected from Coregen GUI are
              set correctly.
              Checks - Max Link Speed/Width, Device/Vendor ID, CMPS
*************************************************************/
task TSK_SYSTEM_CONFIGURATION_CHECK;
real datarate;
begin
  // Check Link Speed/Width
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h80, 4'hF);
  TSK_WAIT_FOR_READ_DATA;

  if  (P_READ_DATA[19:16] == MAX_LINK_SPEED) begin
    case (P_READ_DATA[19:16])
    1: datarate =  2.5;
    2: datarate =  5.0;
    3: datarate =  8.0;
    4: datarate = 16.0;
    endcase
    $display("[%t] : TEST PASS -- Check Max Link Speed = %fGT/s - PASSED",
     $realtime, datarate);
  end else begin
    $display("[%t] : TEST FAIL -- Check Max Link Speed - FAILED", $realtime);
    $display
    ( "[%t] : Data Error Mismatch, Parameter Data %x != Read Data %x"
    , $realtime, MAX_LINK_SPEED, P_READ_DATA[19:16] );
  end

  if (P_READ_DATA[24:20] == LINK_CAP_MAX_LINK_WIDTH)
    $display
    ( "[%t] : TEST PASS -- Check Negotiated Link Width = 5'h%x - PASSED"
    , $realtime, LINK_CAP_MAX_LINK_WIDTH );
  else
    $display
    ( "[%t] : TEST FAIL -- Data Error Mismatch, Parameter Data %x != Read Data %x"
    , $realtime, LINK_CAP_MAX_LINK_WIDTH, P_READ_DATA[23:20] );

  // Check Device/Vendor ID
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h0, 4'hF);
  TSK_WAIT_FOR_READ_DATA;

  if (P_READ_DATA[31:16] != EP_DEV_ID) begin
    $display
    ( "[%t] : TEST FAIL -- Check Device/Vendor ID - FAILED"
    , $realtime );
    $display
    ( "[%t] : Data Error Mismatch, Parameter Data %x != Read Data %x"
    , $realtime, EP_DEV_ID, P_READ_DATA );
  end else begin
    $display("[%t] : TEST PASS -- Check Device/Vendor ID - PASSED", $realtime);
  end

  // Check CMPS
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h78, 4'hF);
  TSK_WAIT_FOR_READ_DATA;

  if (P_READ_DATA[7:5] != DEV_CAP_MAX_PAYLOAD_SUPPORTED) begin
    $display("[%t] : TEST FAIL -- Check CMPS ID - FAILED", $realtime);
    $display
    ( "[%t] : Data Error Mismatch, Parameter Data %x != Read data %x"
    , $realtime, DEV_CAP_MAX_PAYLOAD_SUPPORTED, P_READ_DATA );
  end else begin
    $display
    ( "[%t] : TEST PASS -- Check CMPS ID == %x - PASSED"
    , $realtime, DEV_CAP_MAX_PAYLOAD_SUPPORTED );
  end

  $display("[%t] :    SYSTEM CHECK PASSED", $realtime);
end
endtask

/************************************************************
Task : TSK_TX_TYPE0_CONFIGURATION_READ
Inputs : Tag, PCI/PCI-Express Reg Address, First BypeEn
Outputs : Transaction Tx Interface Signaling
Description : Generates a Type 0 Configuration Read TLP
*************************************************************/
task TSK_TX_TYPE0_CONFIGURATION_READ;
input [ 7:0] tag_;
input [11:0] reg_addr_;
input [ 3:0] first_dw_be_; // First DW Byte Enable
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //--------- CFG TYPE-0 Read Transaction :                     -----------\\
  s_axis_rq_tvalid <= #(Tcq) 1'b1;
  s_axis_rq_tlast  <= #(Tcq) 1'b1;
  s_axis_rq_tkeep  <= #(Tcq) 8'h0F; // 2DW Descriptor
  s_axis_rq_tuser_wo_parity <= #(Tcq) {
   64'b0,                   // Parity Bit slot - 64bit
   6'b101010,               // Seq Number - 6bit
   6'b101010,               // Seq Number - 6bit
   16'h0000,                // TPH Steering Tag - 16 bit
   2'b00,                   // TPH indirect Tag Enable - 2bit
   4'b0000,                 // TPH Type - 4 bit
   2'b00,                   // TPH Present - 2 bit
   1'b0,                    // Discontinue                                   
   4'b0000,                 // is_eop1_ptr
   4'b0000,                 // is_eop0_ptr
   2'b01,                   // is_eop[1:0]
   2'b10,                   // is_sop1_ptr[1:0]
   2'b00,                   // is_sop0_ptr[1:0]
   2'b01,                   // is_sop[1:0]
   2'b00,2'b00,
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,4'b0000,         // Last BE of the Write Data -  8 bit
   4'b0000, first_dw_be_ }; // First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   256'b0,128'b0,   // 4DW unused             //256
   1'b0,            // Force ECRC             //128
   3'b000,
   // ^-- Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   3'b000,          // Traffic Class
   1'b1,            // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS,  // Completer ID
   tag_,            // Tag
   RP_BUS_DEV_FNS,  // Requester ID  //96
   1'b0,            // Poisoned Req
   4'b1000,         // Req Type for TYPE0 CFG READ Req
   11'b00000000001, // DWORD Count
   32'b0,           // Address *unused*       // 64
   16'b0,           // Address *unused*       // 32
   4'b0,            // Address *unused*
   reg_addr_[11:2], // Extended + Base Register Number
   2'b00 };         // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b000,          // Fmt for Type 0 Configuration Read Req 
   5'b00100,        // Type for Type 0 Configuration Read Req
   1'b0,            // *reserved*
   3'b000,          // Traffic Class
   1'b0,            // *reserved*
   1'b0,            // Attributes {ID Based Ordering}
   1'b0,            // *reserved*
   1'b0,            // TLP Processing Hints
   1'b0,            // TLP Digest Present
   1'b0,            // Poisoned Req
   2'b00,           // Attributes {Relaxed Ordering, No Snoop}
   2'b00,           // Address Translation
   10'b0000000001,  // DWORD Count            //32
   RP_BUS_DEV_FNS,  // Requester ID
   tag_,            // Tag
   4'b0000,         // Last DW Byte Enable
   first_dw_be_,    // First DW Byte Enable   //64
   EP_BUS_DEV_FNS,  // Completer ID
   4'b0000,         // *reserved*
   reg_addr_[11:2], // Extended + Base Register Number
   2'b00,           // *reserved*             //96
   32'b0 ,          // *unused*               //128
   128'b0 };        // *unused*               //256
  pcie_tlp_rem <= #(Tcq) 3'b101;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_TYPE0_CONFIGURATION_READ

/************************************************************
Task : TSK_TX_TYPE0_CONFIGURATION_WRITE
Inputs : Tag, PCI/PCI-Express Reg Address, First BypeEn
Outputs : Transaction Tx Interface Signaling
Description : Generates a Type 0 Configuration Write TLP
*************************************************************/
task TSK_TX_TYPE0_CONFIGURATION_WRITE;
input [ 7:0] tag_;
input [11:0] reg_addr_;
input [31:0] reg_data_;
input [ 3:0] first_dw_be_; // First DW Byte Enable
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //--------- TYPE-0 CFG Write Transaction :                     -----------\\
  s_axis_rq_tvalid <= #(Tcq) 1'b1;
  s_axis_rq_tlast  <= #(Tcq)
   (AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") ? 1'b0 : 1'b1;
  s_axis_rq_tkeep  <= #(Tcq)
   (AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") ? 8'hFF : 8'h1F; // 2DW Descriptor
  s_axis_rq_tuser_wo_parity <= #(Tcq) {
   64'b0,                  // Parity Bit slot - 64bit
   6'b101010,              // Seq Number - 6bit
   6'b101010,              // Seq Number - 6bit
   16'h0000,               // TPH Steering Tag - 16 bit
   2'b00,                  // TPH indirect Tag Enable - 2bit
   4'b0000,                // TPH Type - 4 bit
   2'b00,                  // TPH Present - 2 bit
   1'b0,                   // Discontinue                                   
   4'b0000,                // is_eop1_ptr
   4'b0000,                // is_eop0_ptr
   2'b01,                  // is_eop[1:0]
   2'b10,                  // is_sop1_ptr[1:0]
   2'b00,                  // is_sop0_ptr[1:0]
   2'b01,                  // is_sop[1:0]
   2'b00,2'b00,
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,4'b0000,        // Last BE of the Write Data -  8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   256'b0,96'b0,           // 3 DW unused            //256
   ( (AXISTEN_IF_RQ_ALIGNMENT_MODE=="FALSE")
   ? {reg_data_[31:24], reg_data_[23:16], reg_data_[15:8], reg_data_[7:0]}
   : 32'h0), // Data
   1'b0,            // Force ECRC             //128
   3'b000,
   // ^-- Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   3'b000,          // Traffic Class
   1'b1,            // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS,  // Completer ID
   tag_,            // Tag
   RP_BUS_DEV_FNS,  // Requester ID           //96
   1'b0,            // Poisoned Req
   4'b1010,         // Req Type for TYPE0 CFG Write Req
   11'b00000000001, // DWORD Count
   32'b0,           // Address *unused*       //64
   16'b0,           // Address *unused*       //32
   4'b0,            // Address *unused*
   reg_addr_[11:2], // Extended + Base Register Number
   2'b00};          // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b010,           // Fmt for Type 0 Configuration Write Req
   5'b00100,         // Type for Type 0 Configuration Write Req
   1'b0,             // *reserved*
   3'b000,           // Traffic Class
   1'b0,             // *reserved*
   1'b0,             // Attributes {ID Based Ordering}
   1'b0,             // *reserved*
   1'b0,             // TLP Processing Hints
   1'b0,             // TLP Digest Present
   1'b0,             // Poisoned Req
   2'b00,            // Attributes {Relaxed Ordering, No Snoop}
   2'b00,            // Address Translation
   10'b0000000001,   // DWORD Count           //32
   RP_BUS_DEV_FNS,   // Requester ID
   tag_,             // Tag
   4'b0000,          // Last DW Byte Enable
   first_dw_be_,     // First DW Byte Enable  //64
   EP_BUS_DEV_FNS,   // Completer ID
   4'b0000,          // *reserved*
   reg_addr_[11:2],  // Extended + Base Register Number
   2'b00,            // *reserved*            //96
   reg_data_[7:0],   // Data
   reg_data_[15:8],  // Data
   reg_data_[23:16], // Data
   reg_data_[31:24], // Data                  //128
   128'b0 };         // *unused*              //256
  pcie_tlp_rem <= #(Tcq)  3'b100;
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  if(AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") begin
   s_axis_rq_tvalid <= #(Tcq) 1'b1;
   s_axis_rq_tlast  <= #(Tcq) 1'b1;
   s_axis_rq_tkeep  <= #(Tcq) 8'h01;             // 2DW Descriptor
   s_axis_rq_tdata <= #(Tcq) {
    256'b0,128'b0,
    32'b0,            // *unused* //128
    32'b0,            // *unused* //96
    32'b0,            // *unused* //64
    reg_data_[31:24],             //32
    reg_data_[23:16],
    reg_data_[15:8],
    reg_data_[7:0] };

    // Just call TSK_TX_SYNCHRONIZE to wait for tready but don't log anything,
    // because the pcie_tlp_data has complete in the previous clock cycle
    TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  end
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b0;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_TYPE0_CONFIGURATION_WRITE

/************************************************************
Task : TSK_TX_MEMORY_READ_32
Inputs : Tag, Length, Address, Last Byte En, First Byte En
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Read 32 TLP
*************************************************************/
task TSK_TX_MEMORY_READ_32;
input [ 7:0] tag_;
input [ 2:0] tc_;          // Traffic Class
input [10:0] len_;         // Length (in DW)
input [31:0] addr_;        // Address
input [ 3:0] last_dw_be_;  // Last DW Byte Enable
input [ 3:0] first_dw_be_; // First DW Byte Enable
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
      $display("[%t] :  interface is MIA", $realtime);
      $finish(1);
  end
  $display("[%t] : Mem32 Read Req @address %x", $realtime,addr_);
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b1;
  s_axis_rq_tlast          <= #(Tcq) 1'b1;
  s_axis_rq_tkeep          <= #(Tcq) 8'h0F;             // 2DW Descriptor for Memory Transactions alone
  s_axis_rq_tuser_wo_parity<= #(Tcq) {
   64'b0,                   // Parity Bit slot - 64bit
   6'b101010,               // Seq Number - 6bit
   6'b101010,               // Seq Number - 6bit
   16'h0000,                // TPH Steering Tag - 16 bit
   2'b00,                   // TPH indirect Tag Enable - 2bit
   4'b0000,                 // TPH Type - 4 bit
   2'b00,                   // TPH Present - 2 bit
   1'b0,                    // Discontinue                                   
   4'b0000,                 // is_eop1_ptr
   4'b0000,                 // is_eop0_ptr
   2'b01,                   // is_eop[1:0]
   2'b10,                   // is_sop1_ptr[1:0]
   2'b00,                   // is_sop0_ptr[1:0]
   2'b01,                   // is_sop[1:0]
   2'b00,2'b00,
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,last_dw_be_,     // Last BE of the Write Data -  8 bit
   4'b0000,first_dw_be_ };  // First BE of the Write Data - 8 bit
         
  s_axis_rq_tdata          <= #(Tcq) {
   256'b0,128'b0,    // 4 DW unused                                    //256
   1'b0,             // Force ECRC                                     //128
   3'b000,
   // ^-- Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,              // Traffic Class
   1'b1,             // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS,   // Completer ID
   tag_,             // Tag
   RP_BUS_DEV_FNS,   // Requester ID -- Used only when RID enable = 1  //96
   1'b0,             // Poisoned Req
   4'b0000,          // Req Type for MRd Req
   len_ ,            // DWORD Count
   32'b0,            // 32-bit Addressing. So, bits[63:32] = 0         //64
   addr_[31:2],      // Memory read address 32-bits                    //32
   2'b00};           // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data            <= #(Tcq) {
   3'b000,         // Fmt for 32-bit MRd Req
   5'b00000,       // Type for 32-bit Mrd Req
   1'b0,           // *reserved*
   tc_,            // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   1'b0,           // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   len_[9:0],      // DWORD Count                                    //32
   RP_BUS_DEV_FNS, // Requester ID
   tag_,           // Tag
   last_dw_be_,    // Last DW Byte Enable
   first_dw_be_,   // First DW Byte Enable                           //64
   addr_[31:2],    // Address
   2'b00,          // *reserved*                                     //96
   32'b0,          // *unused*                                       //128
   128'b0 };       // *unused*                                       //256
  pcie_tlp_rem             <= #(Tcq)  3'b100;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b0;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_MEMORY_READ_32

/************************************************************
Task : TSK_TX_MEMORY_READ_64
Inputs : Tag, Length, Address, Last Byte En, First Byte En
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Read 64 TLP
*************************************************************/
task TSK_TX_MEMORY_READ_64;
input [ 7:0] tag_;
input [ 2:0] tc_;          // Traffic Class
input [10:0] len_;         // Length (in DW)
input [63:0] addr_;        // Address
input [ 3:0] last_dw_be_;  // Last DW Byte Enable
input [ 3:0] first_dw_be_; // First DW Byte Enable
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
      $display("[%t] :  interface is MIA", $realtime);
      $finish(1);
  end
  $display("[%t] : Mem64 Read Req @address %x", $realtime,addr_[31:0]);
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b1;
  s_axis_rq_tlast          <= #(Tcq) 1'b1;
  s_axis_rq_tkeep          <= #(Tcq) 8'h0F;
  // ^-- 2DW Descriptor for Memory Transactions alone
  s_axis_rq_tuser_wo_parity<= #(Tcq) {
   64'b0,                  // Parity Bit slot - 64bit
   6'b101010,              // Seq Number - 6bit
   6'b101010,              // Seq Number - 6bit
   16'h0000,               // TPH Steering Tag - 16 bit
   2'b00,                  // TPH indirect Tag Enable - 2bit
   4'b0000,                // TPH Type - 4 bit
   2'b00,                  // TPH Present - 2 bit
   1'b0,                   // Discontinue                                   
   4'b0000,                // is_eop1_ptr
   4'b0000,                // is_eop0_ptr
   2'b01,                  //is_eop[1:0]
   2'b10,                  //is_sop1_ptr[1:0]
   2'b00,                  //is_sop0_ptr[1:0]
   2'b01,                  //is_sop[1:0]
   2'b00,2'b00,
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,last_dw_be_,    // Last BE of the Write Data -  8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   256'b0,128'b0,  // 4 DW unused                                    //256
   1'b0,           // Force ECRC                                     //128
   3'b000,         // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,            // Traffic Class
   1'b1,           // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS, // Completer ID
   tag_,           // Tag
   RP_BUS_DEV_FNS, // Requester ID -- Used only when RID enable = 1  //96
   1'b0,           // Poisoned Req
   4'b0000,        // Req Type for MRd Req
   len_ ,          // DWORD Count
   addr_[63:2],    // Memory read address 64-bits                    //64
   2'b00 };        // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b001,         // Fmt for 64-bit MRd Req
   5'b00000,       // Type for 64-bit Mrd Req
   1'b0,           // *reserved*
   tc_,            // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   1'b0,           // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   len_[9:0],      // DWORD Count                                    //32
   RP_BUS_DEV_FNS, // Requester ID
   tag_,           // Tag
   last_dw_be_,    // Last DW Byte Enable
   first_dw_be_,   // First DW Byte Enable                           //64
   addr_[63:2],    // Address
   2'b00,          // *reserved*                                     //128
   128'b0 };       // *unused*                                       //256
  pcie_tlp_rem              <= #(Tcq)  3'b100;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid          <= #(Tcq) 1'b0;
  s_axis_rq_tlast           <= #(Tcq) 1'b0;
  s_axis_rq_tkeep           <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity <= #(Tcq) 137'b0;
  s_axis_rq_tdata           <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem              <= #(Tcq) 3'b0;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_MEMORY_READ_64

/************************************************************
Task : TSK_TX_MEMORY_WRITE_32
Inputs : Tag, Length, Address, Last Byte En, First Byte En
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Write 32 TLP
*************************************************************/
task TSK_TX_MEMORY_WRITE_32;
input [  7:0] tag_;         // Tag
input [  2:0] tc_;          // Traffic Class
input [ 10:0] len_;         // Length (in DW)
input [ 31:0] addr_;        // Address
input [  3:0] last_dw_be_;  // Last DW Byte Enable
input [  3:0] first_dw_be_; // First DW Byte Enable
input         ep_;          // Poisoned Data: Payload is invalid if set
reg   [ 10:0] _len;
// ^-- Length Info on pcie_tlp_data -- Used to count how many times to loop
reg   [ 10:0] len_i;
// ^-- Length Info on s_axis_rq_tdata -- Used to count how many times to loop
reg   [  2:0] aa_dw;        // Adjusted DW Count for Address Aligned Mode
reg   [ 31:0] data_axis_i;
// ^-- Data Info for s_axis_rq_tdata changed from 128 bit to 32 bit
reg   [511:0] subs_dw;      // adjusted for subsequent DW when len >12
reg   [159:0] data_pcie_i;  // Data Info for pcie_tlp_data
reg   [383:0] data_axis_first_beat;
reg   [255:0] tmp;
integer       _j, _k;       // Byte Index
integer       start_addr;   // Start Location for Payload DW0
begin
  //-----------------------------------------------------------------------\\            
  if (AXISTEN_IF_RQ_ALIGNMENT_MODE=="TRUE")begin
    start_addr  = 0;
    aa_dw       = addr_[4:2];
  end else begin
    start_addr  = 48;
    aa_dw       = 3'b000;
  end
            
  len_i = len_ + aa_dw;
  _len  = len_;
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  $display("[%t] : Mem32 Write Req @address %x", $realtime,addr_);
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  // Start of First Data Beat
  data_axis_i = {DATA_STORE[3], DATA_STORE[2], DATA_STORE[1], DATA_STORE[0]};
           
  if (len_i > 12 ) begin
    data_axis_first_beat = {12{data_axis_i}}; 
  end else begin 
    data_axis_first_beat = 0;
    repeat (len_i) begin
      data_axis_first_beat <<= 32;
      data_axis_first_beat |=  data_axis_i;
    end
  end
  s_axis_rq_tuser_wo_parity <= #(Tcq) {
   64'b0,                  // Parity Bit slot - 64bit
   6'b101010,              // Seq Number - 6bit
   6'b101010,              // Seq Number - 6bit
   16'h0000,               // TPH Steering Tag - 16 bit
   2'b00,                  // TPH indirect Tag Enable - 2bit
   4'b0000,                // TPH Type - 4 bit
   2'b00,                  // TPH Present - 2 bit
   1'b0,                   // Discontinue                                   
   4'b0000,                // is_eop1_ptr
   4'b1111,                // is_eop0_ptr
   2'b01,                  // is_eop[1:0]
   2'b00,                  // is_sop1_ptr[1:0]
   2'b00,                  // is_sop0_ptr[1:0]
   2'b01,                  // is_sop[1:0]
   2'b0,aa_dw[1:0],
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,last_dw_be_,    // Last BE of the Write Data 8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data 8 bit
  s_axis_rq_tdata   <= #(Tcq) {
   ( (AXISTEN_IF_RQ_ALIGNMENT_MODE == "FALSE" )
   ? data_axis_first_beat : 384'h0), // 12 DW write data
    //128
   1'b0,           // Force ECRC
   3'b000,         // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,            // Traffic Class
   1'b1,           // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS, // Completer ID
   tag_,           // Tag
    //96
   RP_BUS_DEV_FNS, // Requester ID -- Used only when RID enable = 1
   ep_,            // Poisoned Req
   4'b0001,        // Req Type for MWr Req
   len_,           // DWORD Count - length does not include padded zeros
    //64
   32'b0,          // High Address *unused*
   addr_[31:2],    // Memory Write address 32-bits
   2'b00 };        // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  for (data_pcie_i = 0, _j = 0; _j < 20; _j += 1) begin
    data_pcie_i <<= 8; data_pcie[7:0] = DATA_STORE[_j];
  end
  pcie_tlp_data <= #(Tcq) {
   3'b010,        // Fmt for 32-bit MWr Req
   5'b00000,      // Type for 32-bit MWr Req
   1'b0,          // *reserved*
   tc_,           // 3-bit Traffic Class
   1'b0,          // *reserved*
   1'b0,          // Attributes {ID Based Ordering}
   1'b0,          // *reserved*
   1'b0,          // TLP Processing Hints
   1'b0,          // TLP Digest Present
   ep_,           // Poisoned Req
   2'b00,         // Attributes {Relaxed Ordering, No Snoop}
   2'b00,         // Address Translation
   len_[9:0],     // DWORD Count
    //32
   RP_BUS_DEV_FNS,   // Requester ID
   tag_,          // Tag
   last_dw_be_,   // Last DW Byte Enable
   first_dw_be_,  // First DW Byte Enable
    //64
   addr_[31:2],   // Memory Write address 32-bits
   2'b00,         // *reserved* or Processing Hint
    //96
   data_pcie_i    // Payload Data
  };//256
  pcie_tlp_rem     <= #(Tcq) (_len > 12) ? 3'b000 : (_len - 12);
  _len              = (_len > 12) ? (_len - 11'hC) : 11'b0;
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid <= #(Tcq) 1'b1;

  if (len_i > 12 || AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") begin
    s_axis_rq_tlast <= #(Tcq) 1'b0;
    s_axis_rq_tkeep <= #(Tcq) 16'hFFFF;

    len_i = (AXISTEN_IF_RQ_ALIGNMENT_MODE == "FALSE") ? (len_i - 12) : len_i;
    // Don't subtract 12 in Address Aligned because
    // it's always padded with zeros on first beat
 
    // pcie_tlp_data doesn't append zero even in Address Aligned mode, so it should mark this cycle as the last beat if it has no more payload to log.
    // The AXIS RQ interface will need to execute the next cycle, but we're just not going to log that data beat in pcie_tlp_data
    if (_len == 0)
      TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
    else
      TSK_TX_SYNCHRONIZE(1, 1, 0, `SYNC_RQ_RDY);

  end else begin
    s_axis_rq_teep  <= #(Tcq) len_i == 0 ? ~16'd0 : ~(~16'd0 << (len_i + 4));
    s_axis_rq_tlast <= #(Tcq) 1'b1;
    len_i            = 0;
    TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  end
  // End of First Data Beat
  //-----------------------------------------------------------------------\\
  // Start of Second and Subsequent Data Beat
  if (len_i != 0 || AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") begin
    fork
      begin // Sequential group 1 - AXIS RQ
        for (_j = start_addr; len_i != 0; _j = _j + 32) begin
          if (1 <= len_i && len_i <= 15) begin
            subs_dw = 0; repeat (len_i) begin
              subs_dw <<= 32;
              subs_dw[31:0] = data_axis_i;
            end
          end else begin
            subs_dw = {16{data_axis_i}}; 
          end

          s_axis_rq_tdata   <= #(Tcq) subs_dw ;
          if (1 <= len_i && len_i <= 15) begin
            s_axis_rq_tkeep <= #(Tcq) ~(~16'd0 << len_i);
            len_i = 0;
          end else begin
            s_axis_rq_tkeep <= #(Tcq) ~16'd0;
            len_i -= 16;
          end

          if (len_i == 0) s_axis_rq_tlast <= #(Tcq) 1'b1;
          else            s_axis_rq_tlast <= #(Tcq) 1'b0;

          // Call this just to check for the tready, but don't log anything. That's the job for pcie_tlp_data
          // The reason for splitting the TSK_TX_SYNCHRONIZE task and distribute them in both sequential group
          // is that in address aligned mode, it's possible that the additional padded zeros cause the AXIS RQ
          // to be one beat longer than the actual PCIe TLP. When it happens do not log the last clock beat
          // but just send the packet on AXIS RQ interface
          TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);

        end // for loop
      end // End sequential group 1 - AXIS RQ

      begin // Sequential group 2 - pcie_tlp
        for (_j = 20; _len != 0; _j = _j + 32) begin
          for (tmp = 0, _k = 0; _k < 32; _k += 1) begin
            tmp <<= 8;
            tmp[7:0] = DATA_STORE[_j + _k];
          end
          pcie_tlp_data <= #(Tcq) tmp;
          if (1 <= _len && _len <= 15) begin
            pcie_tlp_rem <= #(Tcq) ~(_len[3:0]);
            _len          = 0;
          end else begin
            pcie_tlp_rem <= #(Tcq) 4'b0000;
            _len          = _len - 16;
          end

          if (_len == 0) TSK_TX_SYNCHRONIZE(0, 1, 1, `SYNC_RQ_RDY);
          else           TSK_TX_SYNCHRONIZE(0, 1, 0, `SYNC_RQ_RDY);
        end // for loop
      end // End sequential group 2 - pcie_tlp */

    join
  end  // if
  // End of Second and Subsequent Data Beat
  //-----------------------------------------------------------------------\\
  // Packet Complete - Drive 0s
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b0;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_MEMORY_WRITE_32

/************************************************************
Task : TSK_TX_MEMORY_WRITE_64
Inputs : Tag, Length, Address, Last Byte En, First Byte En
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Write 64 TLP
*************************************************************/
task TSK_TX_MEMORY_WRITE_64;
input [  7:0] tag_;         // Tag
input [  2:0] tc_;          // Traffic Class
input [ 10:0] len_;         // Length (in DW)
input [ 63:0] addr_;        // Address
input [  3:0] last_dw_be_;  // Last DW Byte Enable
input [  3:0] first_dw_be_; // First DW Byte Enable
input         ep_;          // Poisoned Data: Payload is invalid if set
reg   [ 10:0] _len;
// ^-- Length Info on pcie_tlp_data -- Used to count how many times to loop
reg   [ 10:0] len_i;
// ^-- Length Info on s_axis_rq_tdata -- Used to count how many times to loop
reg   [  2:0] aa_dw;        // Adjusted DW Count for Address Aligned Mode
reg   [255:0] aa_data;      // Adjusted Data for Address Aligned Mode
reg   [127:0] data_axis_i;  // Data Info for s_axis_rq_tdata
reg   [127:0] data_pcie_i;  // Data Info for pcie_tlp_data
reg   [255:0] tmp;
integer       _j, _k;       // Byte Index
integer       start_addr;   // Start Location for Payload DW0
begin
  //-----------------------------------------------------------------------\\
  if (AXISTEN_IF_RQ_ALIGNMENT_MODE=="TRUE") begin
    start_addr  = 0;
    aa_dw       = addr_[4:2];
  end else begin
    start_addr = 48;
    aa_dw      = 3'b000;
  end

  len_i = len_ + aa_dw;
  _len  = len_;
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  $display("[%t] : Mem64 Write Req @address %x", $realtime, addr_[31:0]);
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  // Start of First Data Beat
  for (data_axis_i = 0, _j = 15; 0 <= _j; _j -= 1) begin
    data_axis_i    <<= 8;
    data_axis_i[7:0] = DATA_STORE[_j];
  end
  s_axis_rq_tuser_wo_parity <= #(Tcq) {
   64'b0,                  // Parity Bit slot - 64bit
   6'b101010,              // Seq Number - 6bit
   6'b101010,              // Seq Number - 6bit
   16'h0000,               // TPH Steering Tag - 16 bit
   2'b00,                  // TPH indirect Tag Enable - 2bit
   4'b0000,                // TPH Type - 4 bit
   2'b00,                  // TPH Present - 2 bit
   1'b0,                   // Discontinue                                   
   4'b0000,                // is_eop1_ptr
   4'b1111,                // is_eop0_ptr
   2'b01,                  // is_eop[1:0]
   2'b00,                  // is_sop1_ptr[1:0]
   2'b00,                  // is_sop0_ptr[1:0]
   2'b01,                  // is_sop[1:0]
   2'b0,aa_dw[1:0],
   // ^-- Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,last_dw_be_,    // Last BE of the Write Data 8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data 8 bit

  s_axis_rq_tdata   <= #(Tcq) {
   256'b0,//256
   ( (AXISTEN_IF_RQ_ALIGNMENT_MODE == "FALSE" )
   ? data_axis_i : 128'h0), // 128-bit write data
    //128
   1'b0,        // Force ECRC
   3'b000,      // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,         // Traffic Class
   1'b1,        // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS,   // Completer ID
   tag_,        // Tag
    //96
   RP_BUS_DEV_FNS,   // Requester ID -- Used only when RID enable = 1
   ep_,         // Poisoned Req
   4'b0001,     // Req Type for MWr Req
   len_,        // DWORD Count
    //64
   addr_[63:2], // Memory Write address 64-bits
   2'b00 };     // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  for (data_pcie_i = 0, _j = 0; _j < 16; _j += 1) begin
    data_pcie_i    <<= 8;
    data_pcie_i[7:0] = DATA_STORE[_j];
  end
  pcie_tlp_data <= #(Tcq) {
   3'b011,      // Fmt for 64-bit MWr Req
   5'b00000,    // Type for 64-bit MWr Req
   1'b0,        // *reserved*
   tc_,         // 3-bit Traffic Class
   1'b0,        // *reserved*
   1'b0,        // Attributes {ID Based Ordering}
   1'b0,        // *reserved*
   1'b0,        // TLP Processing Hints
   1'b0,        // TLP Digest Present
   ep_,         // Poisoned Req
   2'b00,       // Attributes {Relaxed Ordering, No Snoop}
   2'b00,       // Address Translation
   len_[9:0],   // DWORD Count
   RP_BUS_DEV_FNS,   // Requester ID
   tag_,          // Tag
   last_dw_be_,   // Last DW Byte Enable
   first_dw_be_,  // First DW Byte Enable
    //64
   addr_[63:2],   // Memory Write address 64-bits
   2'b00,         // *reserved*
    //128
   data_pcie_i    // Payload Data
  };//256
                                         
  pcie_tlp_rem     <= #(Tcq) (_len > 3) ? 3'b000 : (4-_len);
  _len              = (_len > 3) ? (_len - 11'h4) : 11'h0;
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid <= #(Tcq) 1'b1;

  if (len_i > 4 || AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") begin
    s_axis_rq_tlast <= #(Tcq) 1'b0;
    s_axis_rq_tkeep <= #(Tcq) 8'hFF;

    len_i = (AXISTEN_IF_RQ_ALIGNMENT_MODE == "FALSE") ? (len_i - 4) : len_i;
    // ^-- Don't subtract 4 in Address Aligned because
    //     it's always padded with zeros on first beat

    // pcie_tlp_data doesn't append zero even in Address Aligned mode, so it should mark this cycle as the last beat if it has no more payload to log.
    // The AXIS RQ interface will need to execute the next cycle, but we're just not going to log that data beat in pcie_tlp_data
    if (_len == 0) TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
    else           TSK_TX_SYNCHRONIZE(1, 1, 0, `SYNC_RQ_RDY);
  end else begin
    if (1 <= len_i) s_axis_rq_tkeep <= #(Tcq) ~(~8'd0 << (1 + len_i));
    s_axis_rq_tlast <= #(Tcq) 1'b1;
    len_i = 0;
    TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  end
  // End of First Data Beat
  //-----------------------------------------------------------------------\\
  // Start of Second and Subsequent Data Beat
  if (len_i != 0 || AXISTEN_IF_RQ_ALIGNMENT_MODE == "TRUE") begin
    fork 
      begin // Sequential group 1 - AXIS RQ
        for (_j = start_addr; len_i != 0; _j = _j + 32) begin
          if(_j == start_addr) begin 
            for (aa_data = 0, _k = 31; 0 <= _k; _k -= 1) begin
              aa_data <<= 8;
              aa_data[7:0] = DATA_STORE[_j + _k];
            end
            aa_data <<= (aa_dw*4*8);
          end else begin 
            for (aa_data = 0, _k = 31; 0 <= _k; _k -= 1) begin
              aa_data <<= 8;
              aa_data[7:0] = DATA_STORE[_j + _k - (aa_dw*4)];
            end
          end
          s_axis_rq_tdata           <= #(Tcq) aa_data;
          if (1 <= len_i && len_i <= 7) begin
            s_axis_rq_tkeep <= #(Tcq) ~(~8'd0 << len_i);
            len_i = 0;
          end else begin
            s_axis_rq_tkeep <= #(Tcq) ~8'd0;
            len_i = len_i - 8;
          end
                        
          if (len_i == 0) s_axis_rq_tlast <= #(Tcq) 1'b1;
          else            s_axis_rq_tlast <= #(Tcq) 1'b0;

          // Call this just to check for the tready, but don't log anything. That's the job for pcie_tlp_data
          // The reason for splitting the TSK_TX_SYNCHRONIZE task and distribute them in both sequential group
          // is that in address aligned mode, it's possible that the additional padded zeros cause the AXIS RQ
          // to be one beat longer than the actual PCIe TLP. When it happens do not log the last clock beat
          // but just send the packet on AXIS RQ interface
          TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
        end // for loop
      end // End sequential group 1 - AXIS RQ
                
      begin // Sequential group 2 - pcie_tlp
        for (_j = 16; _len != 0; _j = _j + 32) begin
          for (_k = 0; _k < 32; _k += 1) begin
            tmp <<= 8;
            tmp[7:0] = DATA_STORE[_j + _k];
          end
          pcie_tlp_data <= #(Tcq) tmp;

          if (1 <= _len && _len <= 7) begin
            pcie_tlp_rem <= #(Tcq) 3'd0 - _len[2:0];
            _len = 0;
          end else begin
            pcie_tlp_rem <= #(Tcq) 3'd0;
            _len = _len - 8;
          end
                        
          if (_len == 0) TSK_TX_SYNCHRONIZE(0, 1, 1, `SYNC_RQ_RDY);
          else           TSK_TX_SYNCHRONIZE(0, 1, 0, `SYNC_RQ_RDY);
        end // for loop
      end // End sequential group 2 - pcie_tlp
    join
  end // if
  // End of Second and Subsequent Data Beat
  //-----------------------------------------------------------------------\\
  // Packet Complete - Drive 0s
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_MEMORY_WRITE_64

/************************************************************
Task : TSK_TX_COMPLETION_DATA
Inputs : Tag, TC, Length, Completion ID
Outputs : Transaction Tx Interface Signaling
Description : Generates a Completion TLP
*************************************************************/
task TSK_TX_COMPLETION_DATA;
input [         15:0] req_id_;     // Requester ID
input [          7:0] tag_;        // Tag
input [          2:0] tc_;         // Traffic Class
input [         10:0] len_;        // Length (in DW)
input [         11:0] byte_count_; // Length (in bytes)
input [          6:0] lower_addr_;
// ^-- Lower 7-bits of Address of first valid data
input [RP_BAR_SIZE:0] ram_ptr;     // RP RAM Read Offset
input [          2:0] comp_status_;// Completion Status.
                                   // 'b000: Success;
                                   // 'b001: Unsupported Request;
                                   // 'b010: Config Request Retry Status;
                                   // 'b100: Completer Abort
input                 ep_;         // Poisoned Data: Payload is invalid if set
reg   [         10:0] _len;
// ^-- Length Info on pcie_tlp_data -- Used to count how many times to loop
reg   [         10:0] len_i;
// ^-- Length Info on s_axis_rq_tdata -- Used to count how many times to loop
reg   [          2:0] aa_dw;       // Adjusted DW Count for Address Aligned Mode
reg   [        511:0] aa_data;     // Adjusted Data for Address Aligned Mode
reg   [        415:0] data_axis_i; // Data Info for s_axis_rq_tdata
reg   [        415:0] data_pcie_i; // Data Info for pcie_tlp_data
reg   [        512:0] tmp;
reg   [RP_BAR_SIZE:0] _j;          // Byte Index for aa_data
reg   [RP_BAR_SIZE:0] _jj;         // Byte Index pcie_tlp_data
integer               start_addr;  // Start Location for Payload DW0
begin
  //-----------------------------------------------------------------------\\
  $display("[%t] : CC Data Completion Task Begin", $realtime);
  if (AXISTEN_IF_CC_ALIGNMENT_MODE=="TRUE") begin
    start_addr  = 0;
    aa_dw       = lower_addr_[4:2];
  end else begin
    start_addr  = 52;
    aa_dw       = 3'b000;
  end
            
  len_i           = len_ + aa_dw;
  _len            = len_;
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_CC_RDY);
  //-----------------------------------------------------------------------\\
  // Start of First Data Beat
  for (data_axis_i = 0, _j = 51; 0 <= _j; _j -= 1) begin
    data_axis_i <<= 8;
    data_axis_i[7:0] = DATA_STORE_2[ram_ptr + _j];
  end
  for (data_pcie_i = 0, _j = 0; _j < 52; _j += 1) begin
    data_pcie_i <<= 8;
    data_pcie_i[7:0] = DATA_STORE_2[ram_ptr + _j];
  end

  s_axis_cc_tuser   <= #(Tcq) {
   (AXISTEN_IF_CC_PARITY_CHECK ? s_axis_cc_tparity : 32'b0), 1'b0 };
  s_axis_cc_tdata   <= #(Tcq) {
   ( (AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE" )
   ? data_axis_i : 416'h0), // 416-bit completion data
   1'b0,        // Force ECRC                                  //96
   3'b0,        // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,         // Traffic Class
   1'b1,        // Completer ID to Control Selection of Client
   RP_BUS_DEV_FNS, // Completer ID
   tag_ ,          // Tag
   req_id_,        // Requester ID                             //64
   1'b0,           // *reserved*
   ep_,            // Poisoned Completion
   comp_status_,   // Completion Status {0= SC, 1= UR, 2= CRS, 4= CA}
   len_,           // DWORD Count
   2'b0,           // *reserved*                               //32
   1'b0,           // Locked Read Completion
   1'b0,           // Byte Count MSB
   byte_count_,    // Byte Count
   6'b0,           // *reserved*
   2'b0,           // Address Type
   1'b0,           // *reserved*
   lower_addr_ };  // Starting Address of the Completion Data Byte
  //-----------------------------------------------------------------------\\
  pcie_tlp_data     <= #(Tcq) {
   3'b010,         // Fmt for Completion with Data
   5'b01010,       // Type for Completion with Data
   1'b0,           // *reserved*
   tc_,            // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   ep_,            // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   len_[9:0],      // DWORD Count                                        //32
   RP_BUS_DEV_FNS, // Completer ID
   comp_status_,   // Completion Status {0= SC, 1= UR, 2= CRS, 4= CA}
   1'b0,           // Byte Count Modified (only used in PCI-X)
   byte_count_,    // Byte Count                                         //64
   req_id_,        // Requester ID
   tag_,           // Tag
   1'b0,           // *reserved
   lower_addr_,    // Starting Address of the Completion Data Byte       //96
   data_pcie_i };  // 416-bit completion data                            //512
                                         
  pcie_tlp_rem <= #(Tcq) (_len > 12) ? 4'b0000 : (13-_len);
  _len          = (_len > 12) ? (_len - 11'hD) : 11'h0;
  //-----------------------------------------------------------------------\\
  s_axis_cc_tvalid  <= #(Tcq) 1'b1;
            
  if (len_i > 13 || AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE") begin
    s_axis_cc_tlast <= #(Tcq) 1'b0;
    s_axis_cc_tkeep <= #(Tcq) 16'hFFFF;
                
    len_i = (AXISTEN_IF_CC_ALIGNMENT_MODE == "FALSE")
          ? (len_i - 11'hD) : len_i;
    // Don't subtract 13 in Address Aligned because
    // it's always padded with zeros on first beat
      
    // pcie_tlp_data doesn't append zero even in Address Aligned mode, so it should mark this cycle as the last beat if it has no more payload to log.
    // The AXIS CC interface will need to execute the next cycle, but we're just not going to log that data beat in pcie_tlp_data
    if (_len == 0) TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_CC_RDY);
    else           TSK_TX_SYNCHRONIZE(1, 1, 0, `SYNC_CC_RDY);
                
  end else begin
    s_axis_cc_tkeep <= #(Tcq) len_i == 0 : ~16'd0 : ~(~16'd0 << (3 + len_i));
    s_axis_cc_tlast <= #(Tcq) 1'b1;
    len_i = 0;
    TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_CC_RDY);
  end
  // End of First Data Beat
  //-----------------------------------------------------------------------\\
  // Start of Second and Subsequent Data Beat
  if (len_i != 0 || AXISTEN_IF_CC_ALIGNMENT_MODE == "TRUE") begin
    fork 
      begin // Sequential group 1 - AXIS CC
        for (_j = start_addr; len_i != 0; _j = _j + 64) begin
          if (_j == start_addr) begin 
            for (aa_data = 0, _k = 63; 0 <= _k; _k -= 1) begin
              aa_data <<= 8;
              aa_data[7:0] = DATA_STORE_2[ram_ptr + _j + _k];
            end
            aa_data <<= (aa_dw*4*8);
          end else begin
            for (aa_data = 0, _k = 63; 0 <= _k; _k -= 1) begin
              aa_data <<= 8;
              aa_data[7:0] = DATA_STORE_2[ram_ptr + _j + _k - (aa_dw*4)];
            end
          end
          s_axis_cc_tdata <= #(Tcq) aa_data;
          if (1 <= len_i && len_i <= 15) begin
            s_axis_cc_tkeep <= #(Tcq) ~(~16'd0 << len_i);
            len_i = 0;
          end else begin
            s_axis_cc_tkeep <= #(Tcq) ~16'd0;
            len_i -= 16;
          end

          if (len_i == 0) s_axis_cc_tlast <= #(Tcq) 1'b1;
          else            s_axis_cc_tlast <= #(Tcq) 1'b0;
                            
          // Call this just to check for the tready, but don't log anything. That's the job for pcie_tlp_data
          // The reason for splitting the TSK_TX_SYNCHRONIZE task and distribute them in both sequential group
          // is that in address aligned mode, it's possible that the additional padded zeros cause the AXIS CC
          // to be one beat longer than the actual PCIe TLP. When it happens do not log the last clock beat
          // but just send the packet on AXIS CC interface
          TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_CC_RDY);
        end // for loop
      end // End sequential group 1 - AXIS CC
                
      begin // Sequential group 2 - pcie_tlp
        for (_jj = 52; _len != 0; _jj = _jj + 64) begin
          for (_k = 0; _k < 64; _k += 1) begin
            tmp <<= 8;
            tmp[7:0] = DATA_STORE_2[ram_ptr + _jj + _k];
          end
          pcie_tlp_data <= #(Tcq) tmp;

          if (1 <= _len && _len <= 15) begin
            pcie_tlp_rem <= #(Tcq) 4'd0 - _len[3:0];
            _len = 0;
          end else begin
            pcie_tlp_rem <= #(Tcq) 4'd0;
            _len -= 16;
          end
                                                   
          if (_len == 0) TSK_TX_SYNCHRONIZE(0, 1, 1, `SYNC_CC_RDY);
          else           TSK_TX_SYNCHRONIZE(0, 1, 0, `SYNC_CC_RDY);
        end // for loop
      end // End sequential group 2 - pcie_tlp
    join
  end  // if
  // End of Second and Subsequent Data Beat
  //-----------------------------------------------------------------------\\
  // Packet Complete - Drive 0s
  s_axis_cc_tvalid         <= #(Tcq) 1'b0;
  s_axis_cc_tlast          <= #(Tcq) 1'b0;
  s_axis_cc_tkeep          <= #(Tcq) 8'h00;
  s_axis_cc_tuser          <= #(Tcq) 60'b0;
  s_axis_cc_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 4'b0000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_COMPLETION_DATA

/************************************************************
Task : TSK_TX_MESSAGE
Inputs : Tag, TC, Address, Message Routing, Message Code
Outputs : Transaction Tx Interface Signaling
Description : Generates a Message TLP
*************************************************************/
task TSK_TX_MESSAGE;
input [ 7:0] tag_;
input [ 2:0] tc_;
input [10:0] len_;
input [63:0] data_;
input [ 2:0] message_rtg_;
input [ 7:0] message_code_;
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //--------- Tx Message Transaction :                          -----------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b1;
  s_axis_rq_tlast          <= #(Tcq) 1'b1;
  s_axis_rq_tkeep          <= #(Tcq) 8'h0F;          // 2DW Descriptor
  s_axis_rq_tuser_wo_parity<= #(Tcq) {
   64'b0,            // Parity Bit slot - 64bit
   6'b101010,        // Seq Number - 6bit
   6'b101010,        // Seq Number - 6bit
   16'h0000,         // TPH Steering Tag - 16 bit
   2'b00,            // TPH indirect Tag Enable - 2bit
   4'b0000,          // TPH Type - 4 bit
   2'b00,            // TPH Present - 2 bit
   1'b0,             // Discontinue                                   
   4'b0000,          // is_eop1_ptr
   4'b0000,          // is_eop0_ptr
   2'b01,            // is_eop[1:0]
   2'b10,            // is_sop1_ptr[1:0]
   2'b00,            // is_sop0_ptr[1:0]
   2'b01,            // is_sop[1:0]
   2'b00,2'b00,      // Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,4'b0000,  // Last BE of the Write Data -  8 bit
   4'b0000,4'b0000 };// First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   256'b0,128'b0,        // 4DW unused
   1'b0,          // Force ECRC
   3'b000,        // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   tc_,           // Traffic Class
   1'b1,          // RID Enable to use the Client supplied Bus/Device/Func No
   5'b0,          // *reserved*
   message_rtg_,  // Message Routing
   message_code_, // Message Code
   tag_,          // Tag
   RP_BUS_DEV_FNS, // Requester ID
   1'b0,          // Poisoned Req
   4'b1100,       // Request Type for Message
   len_ ,         // DWORD Count
   data_[63:32],  // Vendor Defined Header Bytes
   data_[15: 0],  // Vendor ID
   data_[31:16] }; // Destination ID
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b001,         // Fmt for Message w/o Data
   {{2'b10}, {message_rtg_}}, // Type for Message w/o Data
   1'b0,           // *reserved*
   tc_,            // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   1'b0,           // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   10'b0,          // DWORD Count                                     //32
   RP_BUS_DEV_FNS, // Requester ID
   tag_,           // Tag
   message_code_,  // Message Code                                    //64
   data_[63:32],   // Vendor Defined Header Bytes
   data_[31:16],   // Destination ID
   data_[15: 0],   // Vendor ID
   128'b0 };       // *unused*

  pcie_tlp_rem             <= #(Tcq)  3'b100;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h0;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 512'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_MESSAGE

/************************************************************
Task : TSK_TX_IO_READ
Inputs : Tag, Address
Outputs : Transaction Tx Interface Signaling
Description : Generates a IO Read TLP
*************************************************************/
task TSK_TX_IO_READ;
input [ 7:0] tag_;
input [31:0] addr_;
input [ 3:0] first_dw_be_;
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid <= #(Tcq) 1'b1;
  s_axis_rq_tlast  <= #(Tcq) 1'b1;
  s_axis_rq_tkeep  <= #(Tcq) 8'h0F;
  s_axis_rq_tuser_wo_parity<= #(Tcq) {
   64'b0,                   // Parity Bit slot - 64bit
   6'b101010,               // Seq Number - 6bit
   6'b101010,               // Seq Number - 6bit
   16'h0000,                // TPH Steering Tag - 16 bit
   2'b00,                   // TPH indirect Tag Enable - 2bit
   4'b0000,                 // TPH Type - 4 bit
   2'b00,                   // TPH Present - 2 bit
   1'b0,                    // Discontinue                                   
   4'b0000,                 // is_eop1_ptr
   4'b0000,                 // is_eop0_ptr
   2'b01,                   // is_eop[1:0]
   2'b10,                   // is_sop1_ptr[1:0]
   2'b00,                   // is_sop0_ptr[1:0]
   2'b01,                   // is_sop[1:0]
   2'b00,2'b00,             // Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,4'b0000,     // Last BE of the Write Data -  8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   128'b0,         // *unused*                                           //256
   1'b0,           // Force ECRC                                         //128
   3'b000,         // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   3'b000,         // Traffic Class
   1'b1,           // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS,   // Completer ID
   tag_,           // Tag
   RP_BUS_DEV_FNS,   // Requester ID -- Used only when RID enable = 1    //96
   1'b0,           // Poisoned Req
   4'b0010,        // Req Type for IORd Req
   11'b1,          // DWORD Count
   32'b0,          // 32-bit Addressing. So, bits[63:32] = 0             //64
   addr_[31:2],    // IO read address 32-bits                            //32
   2'b00};         // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b000,         // Fmt for IO Read Req
   5'b00010,       // Type for IO Read Req
   1'b0,           // *reserved*
   3'b000,         // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   1'b0,           // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   10'b1,          // DWORD Count                                        //32
   RP_BUS_DEV_FNS, // Requester ID
   tag_,           // Tag
   4'b0,           // Last DW Byte Enable
   first_dw_be_,   // First DW Byte Enable                               //64
   addr_[31:2],    // Address
   2'b00,          // *reserved*                                         //96
   32'b0,          // *unused*                                           //128
   128'b0 };       // *unused*                                           //256
                                               
  pcie_tlp_rem             <= #(Tcq)  3'b101;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 256'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_IO_READ

/************************************************************
Task : TSK_TX_IO_WRITE
Inputs : Tag, Address, Data
Outputs : Transaction Tx Interface Signaling
Description : Generates a IO Write TLP
*************************************************************/
task TSK_TX_IO_WRITE;
input [ 7:0] tag_;
input [31:0] addr_;
input [ 3:0] first_dw_be_;
input [31:0] data_;
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(0, 0, 0, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b1;
  s_axis_rq_tlast          <= #(Tcq) 1'b1;
  s_axis_rq_tkeep          <= #(Tcq) 8'h1F;           // 2DW Descriptor for Memory Transactions alone
  s_axis_rq_tuser_wo_parity<= #(Tcq) {
   64'b0,                   // Parity Bit slot - 64bit
   6'b101010,               // Seq Number - 6bit
   6'b101010,               // Seq Number - 6bit
   16'h0000,                // TPH Steering Tag - 16 bit
   2'b00,                   // TPH indirect Tag Enable - 2bit
   4'b0000,                 // TPH Type - 4 bit
   2'b00,                   // TPH Present - 2 bit
   1'b0,                    // Discontinue                                   
   4'b0000,                 // is_eop1_ptr
   4'b0000,                 // is_eop0_ptr
   2'b01,                   // is_eop[1:0]
   2'b10,                   // is_sop1_ptr[1:0]
   2'b00,                   // is_sop0_ptr[1:0]
   2'b01,                   // is_sop[1:0]
   2'b00,2'b00,             // Byte Lane number in case of Address Aligned mode - 4 bit
   4'b0000,4'b0000,     // Last BE of the Write Data -  8 bit
   4'b0000,first_dw_be_ }; // First BE of the Write Data - 8 bit
  s_axis_rq_tdata <= #(Tcq) {
   32'b0,          // *unused*
   32'b0,          // *unused*
   32'b0,          // *unused*
   data_,          // IO Write data on 5th DW
   1'b0,           // Force ECRC                                         //128
   3'b000,         // Attributes {ID Based Ordering, Relaxed Ordering, No Snoop}
   3'b000,         // Traffic Class
   1'b1,           // RID Enable to use the Client supplied Bus/Device/Func No
   EP_BUS_DEV_FNS, // Completer ID
   tag_,           // Tag
   RP_BUS_DEV_FNS, // Requester ID -- Used only when RID enable = 1      //96
   1'b0,           // Poisoned Req
   4'b0011,        // Req Type for IOWr Req
   11'b1 ,         // DWORD Count
   32'b0,          // 32-bit Addressing. So, bits[63:32] = 0             //64
   addr_[31:2],    // IO Write address 32-bits                           //32
   2'b00};         // AT -> 00 : Untranslated Address
  //-----------------------------------------------------------------------\\
  pcie_tlp_data <= #(Tcq) {
   3'b010,         // Fmt for IO Write Req
   5'b00010,       // Type for IO Write Req
   1'b0,           // *reserved*
   3'b000,         // 3-bit Traffic Class
   1'b0,           // *reserved*
   1'b0,           // Attributes {ID Based Ordering}
   1'b0,           // *reserved*
   1'b0,           // TLP Processing Hints
   1'b0,           // TLP Digest Present
   1'b0,           // Poisoned Req
   2'b00,          // Attributes {Relaxed Ordering, No Snoop}
   2'b00,          // Address Translation
   10'b1,          // DWORD Count                                        //32
   RP_BUS_DEV_FNS, // Requester ID
   tag_,           // Tag
   4'b0,           // last DW Byte Enable
   first_dw_be_,   // First DW Byte Enable                               //64
   addr_[31:2],    // Address
   2'b00,          // *reserved*                                         //96
   data_[7:0],     // IO Write Data
   data_[15:8],    // IO Write Data
   data_[23:16],   // IO Write Data
   data_[31:24],   // IO Write Data                                      //128
   128'b0 }; // *unused*                                           //256
  pcie_tlp_rem <= #(Tcq)  3'b100;
  //-----------------------------------------------------------------------\\
  TSK_TX_SYNCHRONIZE(1, 1, 1, `SYNC_RQ_RDY);
  //-----------------------------------------------------------------------\\
  s_axis_rq_tvalid         <= #(Tcq) 1'b0;
  s_axis_rq_tlast          <= #(Tcq) 1'b0;
  s_axis_rq_tkeep          <= #(Tcq) 8'h00;
  s_axis_rq_tuser_wo_parity<= #(Tcq) 137'b0;
  s_axis_rq_tdata          <= #(Tcq) 256'b0;
  //-----------------------------------------------------------------------\\
  pcie_tlp_rem             <= #(Tcq) 3'b000;
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_IO_WRITE

/************************************************************
Task : TSK_TX_SYNCHRONIZE
Inputs : None
Outputs : None
Description : Synchronize with tx clock and handshake signals
*************************************************************/
task TSK_TX_SYNCHRONIZE;
input first_;        // effectively sof
input active_;       // in pkt -- for pcie_tlp_data signaling only
input last_call_;    // eof
input tready_sw_;    // A switch to select CC or RQ tready
begin
  //-----------------------------------------------------------------------\\
  if (user_lnk_up_n) begin
    $display("[%t] :  interface is MIA", $realtime);
    $finish(1);
  end
  //-----------------------------------------------------------------------\\

  @(posedge user_clk);
  if (tready_sw_ == `SYNC_CC_RDY) begin
    while (s_axis_cc_tready == 1'b0) begin
      @(posedge user_clk);
    end
  end else begin // tready_sw_ == `SYNC_RQ_RDY
    while (s_axis_rq_tready == 1'b0) begin
      @(posedge user_clk);
    end
  end
  //-----------------------------------------------------------------------\\
  if (active_ == 1'b1) begin
    // read data driven into memory
    board.RP.com_usrapp.TSK_READ_DATA_512(first_, last_call_,`TX_LOG,pcie_tlp_data,pcie_tlp_rem);
  end
  //-----------------------------------------------------------------------\\
  if (last_call_)
    board.RP.com_usrapp.TSK_PARSE_FRAME(`TX_LOG);
  //-----------------------------------------------------------------------\\
end
endtask // TSK_TX_SYNCHRONIZE

/************************************************************
Task : TSK_TX_BAR_READ
Inputs : Tag, Length, Address, Last Byte En, First Byte En
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Read 32,64 or IO Read TLP
              requesting 1 dword
*************************************************************/
task TSK_TX_BAR_READ;
input [ 2:0] bar_index;
input [31:0] byte_offset;
input [ 7:0] tag_;
input [ 2:0] tc_;
begin
  case(BAR_INIT_P_BAR_ENABLED[bar_index])
  2'b01 : begin // IO SPACE
    TSK_TX_IO_READ(tag_, BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset), 4'hF);
  end
  2'b10 : begin // MEM 32 SPACE
    TSK_TX_MEMORY_READ_32(tag_, tc_, 10'd1,
     BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset), 4'h0, 4'hF);
  end
  2'b11 : begin // MEM 64 SPACE
    TSK_TX_MEMORY_READ_64(tag_, tc_, 10'd1, {BAR_INIT_P_BAR[ii+1][31:0],
     BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset)}, 4'h0, 4'hF);
    end
  default : begin
    $display("Error case in task TSK_TX_BAR_READ");
  end
  endcase
end
endtask // TSK_TX_BAR_READ

/************************************************************
Task : TSK_TX_BAR_WRITE
Inputs : Bar Index, Byte Offset, Tag, Tc, 32 bit Data
Outputs : Transaction Tx Interface Signaling
Description : Generates a Memory Write 32, 64, IO TLP with
              32 bit data
*************************************************************/
task TSK_TX_BAR_WRITE;
input [ 2:0] bar_index;
input [31:0] byte_offset;
input [ 7:0] tag_;
input [ 2:0] tc_;
input [31:0] data_;
begin
  case(BAR_INIT_P_BAR_ENABLED[bar_index])
  2'b01 : begin // IO SPACE
    TSK_TX_IO_WRITE(tag_, BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset),
     4'hF, data_);
  end
  2'b10 : begin // MEM 32 SPACE
    DATA_STORE[0] = data_[7:0];
    DATA_STORE[1] = data_[15:8];
    DATA_STORE[2] = data_[23:16];
    DATA_STORE[3] = data_[31:24];
    TSK_TX_MEMORY_WRITE_32(tag_, tc_, 10'd1,
     BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset), 4'h0, 4'hF, 1'b0);
  end
  2'b11 : begin // MEM 64 SPACE
    DATA_STORE[0] = data_[7:0];
    DATA_STORE[1] = data_[15:8];
    DATA_STORE[2] = data_[23:16];
    DATA_STORE[3] = data_[31:24];
    TSK_TX_MEMORY_WRITE_64(tag_, tc_, 10'd1, {BAR_INIT_P_BAR[bar_index+1][31:0],
    BAR_INIT_P_BAR[bar_index][31:0]+(byte_offset)}, 4'h0, 4'hF, 1'b0);
  end
  default : begin
    $display("Error case in task TSK_TX_BAR_WRITE");
  end
  endcase
end
endtask // TSK_TX_BAR_WRITE

/************************************************************
Task : TSK_USR_DATA_SETUP_SEQ
Inputs : None
Outputs : None
Description : Populates scratch pad data area with known good data.
*************************************************************/
task TSK_USR_DATA_SETUP_SEQ;
integer i_;
begin
  for (i_ = 0; i_ <= 4095; i_ = i_ + 1) begin
    DATA_STORE[i_] = i_;
  end
  for (i_ = 0; i_ <= (2**(RP_BAR_SIZE+1))-1; i_ = i_ + 1) begin
    DATA_STORE_2[i_] = i_;
  end
end
endtask // TSK_USR_DATA_SETUP_SEQ

/************************************************************
Task : TSK_SET_READ_DATA
Inputs : Data
Outputs : None
Description : Called from common app. Common app hands read
              data to usrapp_tx.
*************************************************************/
task TSK_SET_READ_DATA;
input [ 3:0] be_;   // not implementing be's yet
input [63:0] data_; // might need to change this to byte
begin
  P_READ_DATA   = data_[31:0];
  P_READ_DATA_2 = data_[63:32];
  P_READ_DATA_VALID = 1;
end
endtask // TSK_SET_READ_DATA

/************************************************************
Task : TSK_WAIT_FOR_READ_DATA
Inputs : None
Outputs : Read data P_READ_DATA will be valid
Description : Called from tx app. Common app hands read
              data to usrapp_tx. This task must be executed
              immediately following a call to
              TSK_TX_TYPE0_CONFIGURATION_READ in order for the
              read process to function correctly. Otherwise
              there is a potential race condition with
              P_READ_DATA_VALID.
*************************************************************/
task TSK_WAIT_FOR_READ_DATA;
integer j;
begin
  j = 30;
  P_READ_DATA_VALID = 0;
  fork
    while ((!P_READ_DATA_VALID) && (cpld_to == 0)) @(posedge user_clk);
    begin // second process
      while ((j > 0) && (!P_READ_DATA_VALID)) begin
        repeat (500) @(posedge user_clk);
        j = j - 1;
      end
      if (!P_READ_DATA_VALID) begin
        cpld_to = 1;
        $display("TIMEOUT ERROR in usrapp_tx:TSK_WAIT_FOR_READ_DATA. Completion data never received.");
        $finish;
      end
    end
  join
end
endtask // TSK_WAIT_FOR_READ_DATA

/************************************************************
Function : TSK_DISPLAY_PCIE_MAP
Inputs : none
Outputs : none
Description : Displays the Memory Manager's P_MAP calculations
              based on range values read from PCI_E device.
*************************************************************/
task TSK_DISPLAY_PCIE_MAP;
reg [2:0] ii;
begin
  for (ii = 0; ii <= 6; ii = ii + 1) begin
    if (ii !=6) begin
      $display("\tBAR %x: VALUE = %x RANGE = %x TYPE = %s", ii, BAR_INIT_P_BAR[ii][31:0],
       BAR_INIT_P_BAR_RANGE[ii], BAR_INIT_MESSAGE[BAR_INIT_P_BAR_ENABLED[ii]]);
    end else begin
      $display("\tEROM : VALUE = %x RANGE = %x TYPE = %s", BAR_INIT_P_BAR[6][31:0],
       BAR_INIT_P_BAR_RANGE[6], BAR_INIT_MESSAGE[BAR_INIT_P_BAR_ENABLED[6]]);
    end
  end
end
endtask

/************************************************************
Task : TSK_BUILD_PCIE_MAP
Inputs :
Outputs :
Description : Looks at range values read from config space and
              builds corresponding mem/io map
*************************************************************/
task TSK_BUILD_PCIE_MAP;
reg [2:0] ii;
begin
  $display("[%t] PCI EXPRESS BAR MEMORY/IO MAPPING PROCESS BEGUN...",$realtime);

  // handle bars 0-6 (including erom)
  for (ii = 0; ii <= 6; ii = ii + 1) begin
    if (BAR_INIT_P_BAR_RANGE[ii] != 32'h0000_0000) begin
      if ((ii != 6) && (BAR_INIT_P_BAR_RANGE[ii] & 32'h0000_0001)) begin // if not erom and io bit set
        // bar is io mapped
        NUMBER_OF_IO_BARS = NUMBER_OF_IO_BARS + 1;
        if (~BAR_ENABLED[ii]) begin
          $display("[%t] Testbench will disable BAR %x",$realtime, ii);
          BAR_INIT_P_BAR_ENABLED[ii] = 2'h0; // disable BAR
        end else begin
          BAR_INIT_P_BAR_ENABLED[ii] = 2'h1;
          $display("[%t] Testbench is enabling IO BAR %x",$realtime, ii);
        end //BAR_INIT_P_BAR_ENABLED[ii] = 2'h1;

        if (!OUT_OF_IO) begin
          // We need to calculate where the next BAR should start based on the BAR's range
          BAR_INIT_TEMP = BAR_INIT_P_IO_START & {1'b1,(BAR_INIT_P_BAR_RANGE[ii] & 32'hffff_fff0)};

          if (BAR_INIT_TEMP < BAR_INIT_P_IO_START) begin
            // Current BAR_INIT_P_IO_START is NOT correct start for new base
            BAR_INIT_P_BAR[ii] = BAR_INIT_TEMP + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
            BAR_INIT_P_IO_START = BAR_INIT_P_BAR[ii] + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
          end else begin
            // Initial BAR case and Current BAR_INIT_P_IO_START is correct start for new base
            BAR_INIT_P_BAR[ii] = BAR_INIT_P_IO_START;
            BAR_INIT_P_IO_START = BAR_INIT_P_IO_START + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
          end
          OUT_OF_IO = BAR_INIT_P_BAR[ii][32];

          if (OUT_OF_IO) begin
            $display("\tOut of PCI EXPRESS IO SPACE due to BAR %x", ii);
          end
        end else begin
          $display("\tOut of PCI EXPRESS IO SPACE due to BAR %x", ii);
        end
      end else begin // bar is io mapped
        // bar is mem mapped
        if ((ii != 5) && (BAR_INIT_P_BAR_RANGE[ii] & 32'h0000_0004)) begin
          // bar is mem64 mapped - memManager is not handling out of 64bit memory
          NUMBER_OF_MEM64_BARS = NUMBER_OF_MEM64_BARS + 1;
            if (~BAR_ENABLED[ii]) begin
              $display("[%t] Testbench will disable BAR %x",$realtime, ii);
              BAR_INIT_P_BAR_ENABLED[ii] = 2'h0; // disable BAR
            end else begin
              BAR_INIT_P_BAR_ENABLED[ii] = 2'h3; // bar is mem64 mapped
              $display("[%t] Testbench is enabling MEM64 BAR %x",$realtime, ii);
            end 
            if ( (BAR_INIT_P_BAR_RANGE[ii] & 32'hFFFF_FFF0) == 32'h0000_0000) begin
              // Mem64 space has range larger than 2 Gigabytes
              // calculate where the next BAR should start based on the BAR's range
              BAR_INIT_TEMP = BAR_INIT_P_MEM64_HI_START & BAR_INIT_P_BAR_RANGE[ii+1];
              if (BAR_INIT_TEMP < BAR_INIT_P_MEM64_HI_START) begin
                // Current MEM32_START is NOT correct start for new base
                BAR_INIT_P_BAR[ii+1] =      BAR_INIT_TEMP + FNC_CONVERT_RANGE_TO_SIZE_HI32(ii+1);
                BAR_INIT_P_BAR[ii] =        32'h0000_0000;
                BAR_INIT_P_MEM64_HI_START = BAR_INIT_P_BAR[ii+1] + FNC_CONVERT_RANGE_TO_SIZE_HI32(ii+1);
                BAR_INIT_P_MEM64_LO_START = 32'h0000_0000;
              end else begin
                // Initial BAR case and Current MEM32_START is correct start for new base
                BAR_INIT_P_BAR[ii] =        32'h0000_0000;
                BAR_INIT_P_BAR[ii+1] =      BAR_INIT_P_MEM64_HI_START;
                BAR_INIT_P_MEM64_HI_START = BAR_INIT_P_MEM64_HI_START + FNC_CONVERT_RANGE_TO_SIZE_HI32(ii+1);
              end
            end else begin
              // Mem64 space has range less than/equal 2 Gigabytes
              // calculate where the next BAR should start based on the BAR's range
              BAR_INIT_TEMP = BAR_INIT_P_MEM64_LO_START & (BAR_INIT_P_BAR_RANGE[ii] & 32'hffff_fff0);
              if (BAR_INIT_TEMP < BAR_INIT_P_MEM64_LO_START) begin
                // Current MEM32_START is NOT correct start for new base
                BAR_INIT_P_BAR[ii] =        BAR_INIT_TEMP + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
                BAR_INIT_P_BAR[ii+1] =      BAR_INIT_P_MEM64_HI_START;
                BAR_INIT_P_MEM64_LO_START = BAR_INIT_P_BAR[ii] + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
              end else begin
                // Initial BAR case and Current MEM32_START is correct start for new base
                BAR_INIT_P_BAR[ii] =        BAR_INIT_P_MEM64_LO_START;
                BAR_INIT_P_BAR[ii+1] =      BAR_INIT_P_MEM64_HI_START;
                BAR_INIT_P_MEM64_LO_START = BAR_INIT_P_MEM64_LO_START + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
              end
            end
            // skip over the next bar since it is being used by the 64bit bar
            ii = ii + 1;
          end else begin
            if ( (ii != 6) || ((ii == 6) && (BAR_INIT_P_BAR_RANGE[ii] & 32'h0000_0001)) ) begin
            // handling general mem32 case and erom case
            // bar is mem32 mapped
            if (ii != 6) begin
              NUMBER_OF_MEM32_BARS = NUMBER_OF_MEM32_BARS + 1; // not counting erom space
              if (~BAR_ENABLED[ii]) begin
                $display("[%t] Testbench will disable BAR %x",$realtime, ii);
                BAR_INIT_P_BAR_ENABLED[ii] = 2'h0; // disable BAR
              end else begin
                BAR_INIT_P_BAR_ENABLED[ii] = 2'h2; // bar is mem32 mapped
                $display("[%t] Testbench is enabling MEM32 BAR %x",$realtime, ii);
              end
            end else
              BAR_INIT_P_BAR_ENABLED[ii] = 2'h2; // erom bar is mem32 mapped

            if (!OUT_OF_LO_MEM) begin
              // We need to calculate where the next BAR should start based on the BAR's range
              BAR_INIT_TEMP = BAR_INIT_P_MEM32_START & {1'b1,(BAR_INIT_P_BAR_RANGE[ii] & 32'hffff_fff0)};
              if (BAR_INIT_TEMP < BAR_INIT_P_MEM32_START) begin
                // Current MEM32_START is NOT correct start for new base
                BAR_INIT_P_BAR[ii] =     BAR_INIT_TEMP + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
                BAR_INIT_P_MEM32_START = BAR_INIT_P_BAR[ii] + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
              end else begin
                // Initial BAR case and Current MEM32_START is correct start for new base
                BAR_INIT_P_BAR[ii] =     BAR_INIT_P_MEM32_START;
                BAR_INIT_P_MEM32_START = BAR_INIT_P_MEM32_START + FNC_CONVERT_RANGE_TO_SIZE_32(ii);
              end

              if (ii == 6) begin
                // make sure to set enable bit if we are mapping the erom space
                BAR_INIT_P_BAR[ii] = BAR_INIT_P_BAR[ii] | 33'h1;
              end
              OUT_OF_LO_MEM = BAR_INIT_P_BAR[ii][32];
              if (OUT_OF_LO_MEM) begin
                $display("\tOut of PCI EXPRESS MEMORY 32 SPACE due to BAR %x", ii);
              end
            end else begin
              $display("\tOut of PCI EXPRESS MEMORY 32 SPACE due to BAR %x", ii);
            end
          end
        end
      end
    end
  end

  if ( (OUT_OF_IO) | (OUT_OF_LO_MEM)) begin
    TSK_DISPLAY_PCIE_MAP;
    $display("ERROR: Ending simulation: Memory Manager is out of memory/IO to allocate to PCI Express device");
    $finish;
  end
end
endtask // TSK_BUILD_PCIE_MAP


/************************************************************
     Task : TSK_BAR_SCAN
     Inputs : None
     Outputs : None
     Description : Scans PCI core's configuration registers.
*************************************************************/
task TSK_BAR_SCAN;
begin
  //--------------------------------------------------------------------------
  // Write PCI_MASK to bar's space via PCIe fabric interface to find range
  //--------------------------------------------------------------------------
  P_ADDRESS_MASK          = 32'hffff_ffff;
  DEFAULT_TAG         = 0;
  DEFAULT_TC          = 0;

  $display("[%t] : Inspecting Core Configuration Space...", $realtime);

  // Determine Range for BAR0

  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h10, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR0 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h10, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[0] = P_READ_DATA;

  // Determine Range for BAR1
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h14, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR1 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h14, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[1] = P_READ_DATA;

  // Determine Range for BAR2
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h18, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR2 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h18, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[2] = P_READ_DATA;

  // Determine Range for BAR3
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h1C, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR3 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h1C, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[3] = P_READ_DATA;

  // Determine Range for BAR4
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h20, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR4 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h20, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[4] = P_READ_DATA;

  // Determine Range for BAR5
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h24, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read BAR5 Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h24, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[5] = P_READ_DATA;

  // Determine Range for Expansion ROM BAR
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h30, P_ADDRESS_MASK, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Read Expansion ROM BAR Range
  TSK_TX_TYPE0_CONFIGURATION_READ(DEFAULT_TAG, 12'h30, 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  TSK_WAIT_FOR_READ_DATA;
  BAR_INIT_P_BAR_RANGE[6] = P_READ_DATA;
end
endtask // TSK_BAR_SCAN

/************************************************************
     Task : TSK_BAR_PROGRAM
     Inputs : None
     Outputs : None
     Description : Program's PCI core's configuration registers.
*************************************************************/
task TSK_BAR_PROGRAM;
begin
  //--------------------------------------------------------------------------
  // Write core configuration space via PCIe fabric interface
  //--------------------------------------------------------------------------
  DEFAULT_TAG     = 0;
  $display("[%t] : Setting Core Configuration Space...", $realtime);

  // Program BAR0
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h10, BAR_INIT_P_BAR[0][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program BAR1
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h14, BAR_INIT_P_BAR[1][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program BAR2
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h18, BAR_INIT_P_BAR[2][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program BAR3
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h1C, BAR_INIT_P_BAR[3][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program BAR4
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h20, BAR_INIT_P_BAR[4][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program BAR5
 TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h24, BAR_INIT_P_BAR[5][31:0], 4'hF);
 DEFAULT_TAG = DEFAULT_TAG + 1;
 repeat (100) @(posedge user_clk);

  // Program Expansion ROM BAR
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h30, BAR_INIT_P_BAR[6][31:0], 4'hF);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program PCI Command Register
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'h04, 32'h00000003, 4'h1);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (100) @(posedge user_clk);

  // Program PCIe Device Control Register
  TSK_TX_TYPE0_CONFIGURATION_WRITE(DEFAULT_TAG, 12'hC8, 32'h0000005f, 4'h1);
  DEFAULT_TAG = DEFAULT_TAG + 1;
  repeat (1000) @(posedge user_clk);
end
endtask // TSK_BAR_PROGRAM


   /************************************************************
        Task : TSK_BAR_INIT
        Inputs : None
        Outputs : None
        Description : Initialize PCI core based on core's configuration.
   *************************************************************/

    task TSK_BAR_INIT;
       begin

        TSK_BAR_SCAN;

        TSK_BUILD_PCIE_MAP;

        TSK_DISPLAY_PCIE_MAP;

        TSK_BAR_PROGRAM;

       end
    endtask // TSK_BAR_INIT

/************************************************************
        Task : TSK_MEM_TEST_DATA_BUS
        Inputs : bar_index
        Outputs : None
        Description : Test the data bus wiring in a specific memory
               by executing a walking 1's test at a set address
               within that region.
*************************************************************/

task TSK_MEM_TEST_DATA_BUS;
   input [2:0]  bar_index;
   reg [31:0] pattern;
   reg success;
   begin

    $display("[%t] : Performing Memory data test to address %x", $realtime, BAR_INIT_P_BAR[bar_index][31:0]);
    success = 1; // assume success
    // Perform a walking 1's test at the given address.
    for (pattern = 1; pattern != 0; pattern = pattern << 1)
      begin
        // Write the test pattern. *address = pattern;pio_memTestAddrBus_test1

        TSK_TX_BAR_WRITE(bar_index, 32'h0, DEFAULT_TAG, DEFAULT_TC, pattern);
        TSK_TX_CLK_EAT(10);
    DEFAULT_TAG = DEFAULT_TAG + 1;
        TSK_TX_BAR_READ(bar_index, 32'h0, DEFAULT_TAG, DEFAULT_TC);


        TSK_WAIT_FOR_READ_DATA;
        if  (P_READ_DATA != pattern)
           begin
             $display("[%t] : Data Error Mismatch, Address: %x Write Data %x != Read Data %x", $realtime,
                              BAR_INIT_P_BAR[bar_index][31:0], pattern, P_READ_DATA);
             success = 0;
             $finish;
           end
        else
           begin
             $display("[%t] : Address: %x Write Data: %x successfully received", $realtime,
                              BAR_INIT_P_BAR[bar_index][31:0], P_READ_DATA);
           end
        TSK_TX_CLK_EAT(10);
        DEFAULT_TAG = DEFAULT_TAG + 1;

      end  // for loop
    if (success == 1)
        $display("[%t] : TSK_MEM_TEST_DATA_BUS successfully completed", $realtime);
    else
        $display("[%t] : TSK_MEM_TEST_DATA_BUS completed with errors", $realtime);

   end

endtask   // TSK_MEM_TEST_DATA_BUS

        /************************************************************
    Function : FNC_CONVERT_RANGE_TO_SIZE_32
    Inputs : BAR index for 32 bit BAR
    Outputs : 32 bit BAR size
    Description : Called from tx app. Note that the smallest range
                  supported by this function is 16 bytes.
    *************************************************************/

    function [31:0] FNC_CONVERT_RANGE_TO_SIZE_32;
                input [31:0] bar_index;
                reg   [32:0] return_value;
        begin
                  case (BAR_INIT_P_BAR_RANGE[bar_index] & 32'hFFFF_FFF0) // AND off control bits
                    32'hFFFF_FFF0 : return_value = 33'h0000_0010;
                    32'hFFFF_FFE0 : return_value = 33'h0000_0020;
                    32'hFFFF_FFC0 : return_value = 33'h0000_0040;
                    32'hFFFF_FF80 : return_value = 33'h0000_0080;
                    32'hFFFF_FF00 : return_value = 33'h0000_0100;
                    32'hFFFF_FE00 : return_value = 33'h0000_0200;
                    32'hFFFF_FC00 : return_value = 33'h0000_0400;
                    32'hFFFF_F800 : return_value = 33'h0000_0800;
                    32'hFFFF_F000 : return_value = 33'h0000_1000;
                    32'hFFFF_E000 : return_value = 33'h0000_2000;
                    32'hFFFF_C000 : return_value = 33'h0000_4000;
                    32'hFFFF_8000 : return_value = 33'h0000_8000;
                    32'hFFFF_0000 : return_value = 33'h0001_0000;
                    32'hFFFE_0000 : return_value = 33'h0002_0000;
                    32'hFFFC_0000 : return_value = 33'h0004_0000;
                    32'hFFF8_0000 : return_value = 33'h0008_0000;
                    32'hFFF0_0000 : return_value = 33'h0010_0000;
                    32'hFFE0_0000 : return_value = 33'h0020_0000;
                    32'hFFC0_0000 : return_value = 33'h0040_0000;
                    32'hFF80_0000 : return_value = 33'h0080_0000;
                    32'hFF00_0000 : return_value = 33'h0100_0000;
                    32'hFE00_0000 : return_value = 33'h0200_0000;
                    32'hFC00_0000 : return_value = 33'h0400_0000;
                    32'hF800_0000 : return_value = 33'h0800_0000;
                    32'hF000_0000 : return_value = 33'h1000_0000;
                    32'hE000_0000 : return_value = 33'h2000_0000;
                    32'hC000_0000 : return_value = 33'h4000_0000;
                    32'h8000_0000 : return_value = 33'h8000_0000;
                    default :      return_value = 33'h0000_0000;
                  endcase

                  FNC_CONVERT_RANGE_TO_SIZE_32 = return_value;
        end
    endfunction // FNC_CONVERT_RANGE_TO_SIZE_32



    /************************************************************
    Function : FNC_CONVERT_RANGE_TO_SIZE_HI32
    Inputs : BAR index for upper 32 bit BAR of 64 bit address
    Outputs : upper 32 bit BAR size
    Description : Called from tx app.
    *************************************************************/

    function [31:0] FNC_CONVERT_RANGE_TO_SIZE_HI32;
                input [31:0] bar_index;
                reg   [32:0] return_value;
        begin
                  case (BAR_INIT_P_BAR_RANGE[bar_index])
                    32'hFFFF_FFFF : return_value = 33'h00000_0001;
                    32'hFFFF_FFFE : return_value = 33'h00000_0002;
                    32'hFFFF_FFFC : return_value = 33'h00000_0004;
                    32'hFFFF_FFF8 : return_value = 33'h00000_0008;
                    32'hFFFF_FFF0 : return_value = 33'h00000_0010;
                    32'hFFFF_FFE0 : return_value = 33'h00000_0020;
                    32'hFFFF_FFC0 : return_value = 33'h00000_0040;
                    32'hFFFF_FF80 : return_value = 33'h00000_0080;
                    32'hFFFF_FF00 : return_value = 33'h00000_0100;
                    32'hFFFF_FE00 : return_value = 33'h00000_0200;
                    32'hFFFF_FC00 : return_value = 33'h00000_0400;
                    32'hFFFF_F800 : return_value = 33'h00000_0800;
                    32'hFFFF_F000 : return_value = 33'h00000_1000;
                    32'hFFFF_E000 : return_value = 33'h00000_2000;
                    32'hFFFF_C000 : return_value = 33'h00000_4000;
                    32'hFFFF_8000 : return_value = 33'h00000_8000;
                    32'hFFFF_0000 : return_value = 33'h00001_0000;
                    32'hFFFE_0000 : return_value = 33'h00002_0000;
                    32'hFFFC_0000 : return_value = 33'h00004_0000;
                    32'hFFF8_0000 : return_value = 33'h00008_0000;
                    32'hFFF0_0000 : return_value = 33'h00010_0000;
                    32'hFFE0_0000 : return_value = 33'h00020_0000;
                    32'hFFC0_0000 : return_value = 33'h00040_0000;
                    32'hFF80_0000 : return_value = 33'h00080_0000;
                    32'hFF00_0000 : return_value = 33'h00100_0000;
                    32'hFE00_0000 : return_value = 33'h00200_0000;
                    32'hFC00_0000 : return_value = 33'h00400_0000;
                    32'hF800_0000 : return_value = 33'h00800_0000;
                    32'hF000_0000 : return_value = 33'h01000_0000;
                    32'hE000_0000 : return_value = 33'h02000_0000;
                    32'hC000_0000 : return_value = 33'h04000_0000;
                    32'h8000_0000 : return_value = 33'h08000_0000;
                    default :      return_value = 33'h00000_0000;
                  endcase

                  FNC_CONVERT_RANGE_TO_SIZE_HI32 = return_value;
        end
    endfunction // FNC_CONVERT_RANGE_TO_SIZE_HI32

endmodule // pci_exp_usrapp_tx
