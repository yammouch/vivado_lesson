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
