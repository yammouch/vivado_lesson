//-----------------------------------------------------------------------------
//
// (c) Copyright 2012-2012 Xilinx, Inc. All rights reserved.
//
// This file contains confidential and proprietary information
// of Xilinx, Inc. and is protected under U.S. and
// international copyright and other intellectual property
// laws.
//
// DISCLAIMER
// This disclaimer is not a license and does not grant any
// rights to the materials distributed herewith. Except as
// otherwise provided in a valid license issued to you by
// Xilinx, and to the maximum extent permitted by applicable
// law: (1) THESE MATERIALS ARE MADE AVAILABLE "AS IS" AND
// WITH ALL FAULTS, AND XILINX HEREBY DISCLAIMS ALL WARRANTIES
// AND CONDITIONS, EXPRESS, IMPLIED, OR STATUTORY, INCLUDING
// BUT NOT LIMITED TO WARRANTIES OF MERCHANTABILITY, NON-
// INFRINGEMENT, OR FITNESS FOR ANY PARTICULAR PURPOSE; and
// (2) Xilinx shall not be liable (whether in contract or tort,
// including negligence, or under any other theory of
// liability) for any loss or damage of any kind or nature
// related to, arising under or in connection with these
// materials, including for any direct, or any indirect,
// special, incidental, or consequential loss or damage
// (including loss of data, profits, goodwill, or any type of
// loss or damage suffered as a result of any action brought
// by a third party) even if such damage or loss was
// reasonably foreseeable or Xilinx had been advised of the
// possibility of the same.
//
// CRITICAL APPLICATIONS
// Xilinx products are not designed or intended to be fail-
// safe, or for use in any application requiring fail-safe
// performance, such as life-support or safety devices or
// systems, Class III medical devices, nuclear facilities,
// applications related to the deployment of airbags, or any
// other applications that could lead to death, personal
// injury, or severe property or environmental damage
// (individually and collectively, "Critical
// Applications"). Customer assumes the sole risk and
// liability of any use of Xilinx products in Critical
// Applications, subject only to applicable laws and
// regulations governing limitations on product liability.
//
// THIS COPYRIGHT NOTICE AND DISCLAIMER MUST BE RETAINED AS
// PART OF THIS FILE AT ALL TIMES.
//
//-----------------------------------------------------------------------------
//
// Project    : UltraScale+ FPGA PCI Express v4.0 Integrated Block
// File       : pci_exp_expect_tasks.vh
// Version    : 1.3 
//-----------------------------------------------------------------------------
//--------------------------------------------------------------------------------

`define EXPECT_CPLD_PAYLOAD board.RP.tx_usrapp.expect_cpld_payload
`define EXPECT_MEMWR_PAYLOAD board.RP.tx_usrapp.expect_memwr_payload
`define EXPECT_MEMWR64_PAYLOAD board.RP.tx_usrapp.expect_memwr64_payload

reg [31:0] error_file_ptr;

initial
begin
  error_file_ptr = $fopen("error.dat");
  if (!error_file_ptr) begin
    $write("ERROR: Could not open error.dat.\n");
    $finish;
  end
end

/************************************************************
Task : TSK_EXPECT_CPL
Inputs : traffic_class, td, ep, attr, length, payload
Outputs : status 0-Failed 1-Successful
Description : Expecting a TLP from Rx side with matching
              traffic_class, td, ep, attr and length
*************************************************************/
task TSK_EXPECT_CPL;

  input   [2:0]  traffic_class;
  input          td;
  input          ep;
  input   [1:0]  attr;
  input   [15:0] completer_id;
  input   [2:0]  completion_status;
  input          bcm;
  input   [11:0] byte_count;
  input   [15:0] requester_id;
  input   [7:0]  tag;
  input   [6:0]  address_low;

  output         expect_status;

  reg   [2:0]  traffic_class_;
  reg          td_;
  reg          ep_;
  reg   [1:0]  attr_;
  reg   [15:0] completer_id_;
  reg   [2:0]  completion_status_;
  reg          bcm_;
  reg   [11:0] byte_count_;
  reg   [15:0] requester_id_;
  reg   [7:0]  tag_;
  reg   [6:0]  address_low_;

  integer      i_;
  reg          wait_for_next;

  begin
    wait_for_next = 1'b1; //haven't found any matching tag yet
    while(wait_for_next)
    begin
      @ rcvd_cpl; //wait for a rcvd_cpl event
      traffic_class_ = frame_store_rx[1] >> 4;
      td_ = frame_store_rx[2] >> 7;
      ep_ = frame_store_rx[2] >> 6;
      attr_ = frame_store_rx[2] >> 4;
      bcm_ = frame_store_rx[6] >> 4;
      completion_status_= frame_store_rx[6] >> 5;
      byte_count_ = (frame_store_rx[6]);
      byte_count_ = (byte_count_ << 8) | frame_store_rx[7];
      completer_id_ = {frame_store_rx[4], frame_store_rx[5]};
      requester_id_= {frame_store_rx[8], frame_store_rx[9]};
      tag_= frame_store_rx[10];
      address_low_ = frame_store_rx[11];

      $display("[%t] : Received CPL --- Tag 0x%h", $realtime, tag_);
      if(tag == tag_) //find matching tag
      begin
        wait_for_next = 1'b0;
        if((traffic_class == traffic_class_) &&
           (td === td_) && (ep == ep_) && (attr == attr_) &&
           (bcm == bcm_) && (completion_status == completion_status_) &&
           (byte_count == byte_count_) &&
           (completer_id == completer_id_) &&
           (requester_id == requester_id_) &&
           (address_low == address_low_))
        begin
          // header matches
          expect_status = 1'b1;
        end
        else // header mismatches, error out
        begin
          $fdisplay(error_file_ptr, "[%t] : Found header mismatch in received CPL - Tag 0x%h: \n", $time, tag_);
          $fdisplay(error_file_ptr, "Expected:");
          $fdisplay(error_file_ptr, "\t Traffic Class: 0x%h", traffic_class);
          $fdisplay(error_file_ptr, "\t TD: %h", td);
          $fdisplay(error_file_ptr, "\t EP: %h", ep);
          $fdisplay(error_file_ptr, "\t Attributes: 0x%h", attr);
          $fdisplay(error_file_ptr, "\t BCM: 0x%h", bcm);
          $fdisplay(error_file_ptr, "\t Completion Status: 0x%h", completion_status);
          $fdisplay(error_file_ptr, "\t Byte Count: 0x%h", byte_count);
          $fdisplay(error_file_ptr, "\t Completer ID: 0x%h", completer_id);
          $fdisplay(error_file_ptr, "\t Requester ID: 0x%h", requester_id);
          $fdisplay(error_file_ptr, "\t Tag: 0x%h", tag);
          $fdisplay(error_file_ptr, "\t Lower Address: 0x%h", address_low);
          $fdisplay(error_file_ptr, "Received:");
          $fdisplay(error_file_ptr, "\t Traffic Class: 0x%h", traffic_class_);
          $fdisplay(error_file_ptr, "\t TD: %h", td_);
          $fdisplay(error_file_ptr, "\t EP: %h", ep_);
          $fdisplay(error_file_ptr, "\t Attributes: 0x%h", attr_);
          $fdisplay(error_file_ptr, "\t BCM: 0x%h", bcm_);
          $fdisplay(error_file_ptr, "\t Completion Status: 0x%h", completion_status_);
          $fdisplay(error_file_ptr, "\t Byte Count: 0x%h", byte_count_);
          $fdisplay(error_file_ptr, "\t Completer ID: 0x%h", completer_id_);
          $fdisplay(error_file_ptr, "\t Requester ID: 0x%h", requester_id_);
          $fdisplay(error_file_ptr, "\t Tag: 0x%h", tag_);
          $fdisplay(error_file_ptr, "\t Lower Address: 0x%h", address_low_);
          $fdisplay(error_file_ptr, "");
          expect_status = 1'b0;
        end
      end
    end
  end
endtask
