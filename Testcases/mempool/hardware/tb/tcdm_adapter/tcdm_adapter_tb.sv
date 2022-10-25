// Copyright 2021 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

// Author: Marc Gantenbein, ETH Zurich

module tcdm_adapter_tb;

  /*****************
   *  Definitions  *
   *****************/

  timeunit      1ns;
  timeprecision 1ps;

  import mempool_pkg::*;
  import cf_math_pkg::idx_width;

  localparam ClockPeriod = 1ns;
  localparam TA          = 0.2ns;
  localparam TT          = 0.8ns;

  // set number of cores sending requests
  localparam int NumActiveCores = 256;
  // set number of rounds where each core can send a request if he is active
  localparam int NumIterations = 10;
  // randomize address and payloads for TCDM
  localparam logic FULL_RANDOM_TEST = 1;
  // print requests sent and received
  localparam logic VERBOSE = 0;
  // if valid, delay raising of ready flag at output of TCDM adapter
  // by a random duration
  localparam logic STALL_OUTPUT = 1;

  // overrides param from mempool_pkg
  localparam int   LrWaitQueueSize = 1;

 /********************************
   *  Clock and Reset Generation  *
   ********************************/

  logic clk;
  logic rst_n;

  /****************
  * CLOCK
  ****************/
  always #(ClockPeriod/2) clk = !clk;

  /****************
  * RESET
  ****************/
  // Controlling the reset
  initial begin
    clk   = 1'b1;
    rst_n = 1'b0;
    repeat (5)
      #(ClockPeriod);
    rst_n = 1'b1;
  end

  localparam int unsigned IniAddrWidth = idx_width(NumCoresPerTile + NumGroups);
  typedef logic [IniAddrWidth-1:0] local_req_interco_addr_t;
  // Bank metadata
  typedef struct packed {
    local_req_interco_addr_t ini_addr;
    meta_id_t meta_id;
    tile_group_id_t tile_id;
    tile_core_id_t core_id;
  } bank_metadata_t;

  // match signals to mempool_tile
  // Memory interfaces
  logic                     bank_req_valid;
  logic                     bank_req_ready;
  local_req_interco_addr_t  bank_req_ini_addr;
  tcdm_slave_req_t          bank_req_payload;

  bank_addr_t in_address_i;

  logic                     bank_resp_valid;
  logic                     bank_resp_ready;
  tcdm_slave_resp_t         bank_resp_payload;
  local_req_interco_addr_t  bank_resp_ini_addr;

  bank_metadata_t meta_in;
  bank_metadata_t meta_out;
  logic                     req_valid;
  logic                     req_write;
  bank_addr_t req_addr;
  data_t req_wdata;
  data_t resp_rdata;
  strb_t req_be;

  data_t tcdm_resp_payload;
  bank_metadata_t tcdm_resp_meta_out;


  // Un/Pack metadata
  assign bank_resp_ini_addr              = meta_out.ini_addr;
  assign bank_resp_payload.rdata.meta_id = meta_out.meta_id;
  assign bank_resp_payload.ini_addr      = meta_out.tile_id;
  assign bank_resp_payload.rdata.core_id = meta_out.core_id;
//  assign bank_resp_payload.rdata.amo     = '0; // Don't care

  /*********
   *  DUT  *
   *********/
  tcdm_adapter #(
      .AddrWidth  (TCDMAddrMemWidth),
      .DataWidth  (DataWidth       ),
      .metadata_t (bank_metadata_t ),
      .LrScEnable (LrScEnable      ),
      .RegisterAmo(1'b0            )
  ) dut (
      .clk_i       (clk                          ),
      .rst_ni      (rst_n                        ),
      .in_valid_i  (bank_req_valid               ),
      .in_ready_o  (bank_req_ready               ),
      .in_address_i(in_address_i                 ),
      .in_amo_i    (bank_req_payload.wdata.amo   ),
      .in_write_i  (bank_req_payload.wen         ),
      .in_wdata_i  (bank_req_payload.wdata.data  ),
      .in_meta_i   (meta_in                      ),
      .in_be_i     (bank_req_payload.be          ),
      .in_valid_o  (bank_resp_valid              ),
      .in_ready_i  (bank_resp_ready              ),
      .in_rdata_o  (bank_resp_payload.rdata.data ),
      .in_meta_o   (meta_out                     ),
      .out_req_o   (req_valid                    ),
      .out_add_o   (req_addr                     ),
      .out_write_o (req_write                    ),
      .out_wdata_o (req_wdata                    ),
      .out_be_o    (req_be                       ),
      .out_rdata_i (resp_rdata                   )
  );

  // Bank
  tc_sram #(
    .DataWidth(DataWidth          ),
    .NumWords (2**TCDMAddrMemWidth),
    .NumPorts (1                  ),
    .SimInit  ("ones"             )
  ) mem_bank (
    .clk_i  (clk        ),
    .rst_ni (rst_n      ),
    .req_i  (req_valid  ),
    .we_i   (req_write  ),
    .addr_i (req_addr   ),
    .wdata_i(req_wdata  ),
    .be_i   (req_be     ),
    .rdata_o(resp_rdata )
  );

class TcdmRequest;
  bank_addr_t       addr;
  tcdm_slave_req_t  payload;
  tile_core_id_t    core_id;
  bank_metadata_t   metadata;


  function new(input bank_addr_t req_addr,
               input       data_t req_data,
               input       amo_t req_amo,
               input logic req_wen,
               input       strb_t req_be,
               input int   abs_core_id);
    addr = req_addr;
    payload = '0;
    payload.wdata.data = req_data;
    payload.wen = req_wen;
    payload.wdata.amo = req_amo;
    payload.be = req_be;
    metadata = this.get_metadata_from_core_id(.abs_core_id(abs_core_id));

    if (VERBOSE) begin
      this.display();
    end
  endfunction; // new

  function bank_metadata_t get_metadata_from_core_id(input int abs_core_id);
    bank_metadata_t meta;

    meta = '0;

    if (abs_core_id < 4) begin
      // define those cores as being in the local tile
      meta.ini_addr = abs_core_id;
      meta.ini_addr[IniAddrWidth-1] = 1'b0;
    end else begin
      meta = abs_core_id;
      meta.ini_addr[IniAddrWidth-1] = 1'b1;
    end
    return meta;
  endfunction

  function void display();
    $display( "Send request");
    $display( "%-30s %h","TCDM address:", this.addr);
    $display( "%-30s %h","Payload data:", this.payload.wdata.data);
    $display( "%-30s %h","write_en:", this.payload.wen);
    $display( "%-30s %h","be:", this.payload.be);
    $display( "%-30s %h","AMO:", this.payload.wdata.amo);
    $display( "%-30s %b","meta:", this.metadata);
  endfunction
endclass : TcdmRequest // TcdmRequest

class Generator;
  logic [NumActiveCores-1:0]         is_core_active;
  int                                num_iterations;
  bank_metadata_t                    core_metadata[NumActiveCores-1:0];
  int                                random_draw;
  logic                              random_test;

  rand bank_addr_t rand_addr;
  rand data_t rand_data;

  constraint c_generator {
    if (random_test) {
      rand_addr > 0;
      rand_addr < 256;
      rand_data > 0;
      rand_data < 32000;
    }
    else {
      rand_addr == 42;
      rand_data == 32'hCAFECAFE;
    }
  }

  function new(input int num_iter, input logic random_test);
    for (int i = 0; i < NumActiveCores; i++) begin
      this.is_core_active[i] = 1'b1;
    end
    this.num_iterations = num_iter;
    this.random_test = random_test;

  endfunction; // new

  // generate random requests
  task generate_requests();
    for (int j = 0; j < num_iterations; j++) begin
      for (int i = 0; i < NumActiveCores; i++) begin
        if (is_core_active[i]) begin

          // get random address and random number
          if(!this.randomize()) begin
            $display("Failed to randomize Generator class.");
            $finish(1);
          end

          // set core to wait for response
          this.is_core_active[i] = 1'b0;

          // get index for random instruction
          random_draw = $urandom_range(3);
          unique case (random_draw)
            0: load_reserved(.addr(rand_addr),.data(rand_data),.core_id(i));
            1: store_conditional(.addr(rand_addr),.data(rand_data),.core_id(i));
            2: begin
              write_memory(.addr(rand_addr),.data(rand_data),.core_id(i));
              // do not expect a response from write
              this.is_core_active[i] = 1'b1;
            end
            3: read_memory(.addr(rand_addr),.data(rand_data),.core_id(i));
            default: $display("invalid number drawn");
          endcase // case (random_draw)
        end // if (is_core_active[i])
      end // for (int i = 0; i < NumActiveCores; i++)

      // wait for at least one core to have received his response

      #(50*ClockPeriod);
    end
  endtask; // generate_requests


endclass : Generator



class InputDriver;
  // class to drive input of
  function new();
    // initialize tcdm interface
    bank_req_valid = 'b0;
    in_address_i = '0;
    bank_req_payload.wdata.amo = '0;
    bank_req_payload.wen = 1'b0;
    bank_req_payload.wdata.data = '0;
    bank_req_payload.be = 1'b0;

    // metadata
    //   ini_addr
    bank_req_ini_addr = '0;
    //   meta_id
    bank_req_payload.wdata.meta_id = '0;
    //   core_id
    bank_req_payload.wdata.core_id = '0;
    //   tile_id
    bank_req_payload.ini_addr = '0;
    // indicate to TCDM that you are ready
    bank_resp_ready = 1'b0;
  endfunction

  task send_request(input TcdmRequest req);
    @(posedge clk);
    in_address_i = req.addr;

    // contains request and metadata
    bank_req_payload = req.payload;

    meta_in = req.metadata;
    bank_req_valid = 1'b1;

    wait(bank_req_ready);
    pass_request_to_monitor(.addr(req.addr),
                            .amo(bank_req_payload.wdata.amo),
                            .data(bank_req_payload.wdata.data),
                            .wen(bank_req_payload.wen),
                            .metadata(meta_in));
    @(posedge clk);

    // set values back to 0
    bank_req_valid = 1'b0;
    in_address_i = '0;
    meta_in = '0;

    bank_req_payload = '0;
    bank_req_ini_addr = '0;
    bank_req_valid = 1'b0;
  endtask // send_request

  task pass_request_to_monitor(input bank_addr_t addr,
                               input       amo_t amo,
                               input data_t data,
                               input logic wen,
                               input       bank_metadata_t metadata);
    if (VERBOSE) begin
      $display( "%s %h  %s %b","request:",amo,"metadata:", metadata);
    end
    unique case (amo)
      4'hA: monitor.load_reserved(.addr(addr), .metadata(metadata));
      4'hB: monitor.store_conditional(.addr(addr), .metadata(metadata), .data(data));
      4'h0: begin
        if (wen) begin
          monitor.write_access(.addr(addr), .data(data));
        end else begin
          monitor.read_access(.addr(addr), .metadata(metadata));
        end
      end
      default: $display("Unknown request");
    endcase; // unique case (amo)
  endtask // pass_request_to_monitor

endclass : InputDriver;

/***********
 * RespDriver *
 ***********/
class RespDriver;
  // listen as long as generator is producing
  logic finished_generator;
  int   curr_resp_index;

  function new();
    curr_resp_index = 0;
    finished_generator = 1'b0;
  endfunction; // new

  task listen();
    wait (rst_n);
    @(posedge clk);

    while (!finished_generator) begin
      wait(bank_resp_valid || finished_generator);

      if (STALL_OUTPUT) begin
        #($urandom_range(0,10)*ClockPeriod);
        @(posedge clk);
      end

      if(bank_resp_valid) begin
        bank_resp_ready = 1'b1;

        #(TA);
        scrbrd.actual_data_resp.push_back(bank_resp_payload.rdata.data);
        scrbrd.actual_metadata_resp.push_back(meta_out);

        // activate core again
        generator.is_core_active[meta_out[7:0]] = 1'b1;

        curr_resp_index+=1;

        @(posedge clk);
        bank_resp_ready = 1'b0;
        #(TA);
      end
    end
  endtask
endclass : RespDriver;


  typedef struct packed {
    meta_id_t meta_id;
    bank_addr_t addr;
  } reservation_t;

 typedef meta_id_t reservation_queue_t[$:LrWaitQueueSize];

class Monitor;
  // Observe req and resp lines and compare stimuli
  // to golden model built up of associative array of queues for reservations

  // create a queue for each adress that is reserved
  reservation_queue_t reservation_queues[bank_addr_t];

  data_t resp_data;
  bank_metadata_t resp_metadata;

  // store data in a mock memory to compare to responses obtained from SRAM
  data_t mock_memory[bank_addr_t];

  // check size of queue before inserting a new reservation
  bank_addr_t check_size;
  int            current_queue_size;

  task write_access(input bank_addr_t addr, input data_t data);
    if (VERBOSE) begin
      $display("write access");
    end
    // add write access to mock memory
    mock_memory[addr] = data;

    // pop reservation from queue if reservation existed
    // for same address
    if (reservation_queues.exists(addr) &&
        reservation_queues[addr].size() != 0) begin
      if (VERBOSE) begin
        $display("pop reservation");
      end
      void'(reservation_queues[addr].pop_front());
    end
  endtask; // write_access

  task read_access(input bank_addr_t addr, input bank_metadata_t metadata);
    if (VERBOSE) begin
      $display("read access");
    end
    if (mock_memory.exists(addr)) begin
      resp_data = mock_memory[addr];
    end else begin
      resp_data = 32'hffffffff;
    end
    scrbrd.expected_data_resp.push_back(resp_data);
    scrbrd.expected_metadata_resp.push_back(metadata);
  endtask; // read_access

  task load_reserved(input bank_addr_t addr, input bank_metadata_t metadata);
    if (VERBOSE) begin
      $display("load reserved");
    end
    if (mock_memory.exists(addr)) begin
      resp_data = mock_memory[addr];
    end else begin
      resp_data = 32'hffffffff;
    end

    // check queue size by adding sizes of all queues in associative array
    if (reservation_queues.first(check_size)) begin
      current_queue_size = 0;

      do begin
        current_queue_size += reservation_queues[check_size].size();
      end while (reservation_queues.next(check_size));
      if (VERBOSE) begin
        $display("Current size of reservation queue %d ", current_queue_size);
      end
    end

    // Check if queue is full, else ignore reservation and send out response directly
    if (current_queue_size < LrWaitQueueSize) begin
      // place reservation in queue
      if (reservation_queues.exists(addr)) begin
        if (reservation_queues[addr].size() == 0) begin
          if (VERBOSE) begin
            $display("reservation queue empty, response sending");
          end

          // response can be sent
          scrbrd.expected_data_resp.push_back(resp_data);
          scrbrd.expected_metadata_resp.push_back(metadata);

          // push reservation onto LRWait queue
          reservation_queues[addr].push_back(metadata);

          // check if core issuing LR already holds a reservation
        end else if (reservation_queues[addr][0] == metadata) begin
          if (VERBOSE) begin
            $display("Same core issued another reservation.");
          end
          // core at head of queue issued another reservation
          scrbrd.expected_data_resp.push_back(resp_data);
          scrbrd.expected_metadata_resp.push_back(metadata);
        end
      end else begin // if (reservation_queues.exists(addr))
        if (VERBOSE) begin
          $display("first reservation");
        end
        // the adress does not exist in the queue, thus it is the first reservation
        scrbrd.expected_data_resp.push_back(resp_data);
        scrbrd.expected_metadata_resp.push_back(metadata);

        // push reservation onto LRWait queue
        reservation_queues[addr].push_back(metadata);
      end // else: !if(reservation_queues.exists(addr))
    end else begin
      // queue is full, we sent the LR response directly
      scrbrd.expected_data_resp.push_back(resp_data);
      scrbrd.expected_metadata_resp.push_back(metadata);
    end

  endtask // load_reserved

  task store_conditional(input bank_addr_t addr, input bank_metadata_t metadata, input data_t data);
    if (VERBOSE) begin
      $display("store conditional");
    end
    // check if reservation is valid
    // take head of LR queue
    if (reservation_queues.exists(addr)) begin
      if (metadata == reservation_queues[addr][0]) begin
        // metadata matches, issue SC
        mock_memory[addr] = data;
        scrbrd.expected_data_resp.push_back(1'b0);
        scrbrd.expected_metadata_resp.push_back(metadata);

        // pop reservation
        void'(reservation_queues[addr].pop_front());
        if (reservation_queues[addr].size() != 0) begin
          if (VERBOSE) begin
            $display("Send out load reserved");
          end
          resp_metadata = reservation_queues[addr][0];
          scrbrd.expected_data_resp.push_back(mock_memory[addr]);
          scrbrd.expected_metadata_resp.push_back(resp_metadata);
        end
      end else begin // if (metadata == reservation_queues[addr][0])
        // SC failed
        scrbrd.expected_data_resp.push_back(1'b1);
        scrbrd.expected_metadata_resp.push_back(metadata);
      end // else: !if(metadata == reservation_queues[addr][0])
    end else begin // if (reservation_queues[addr].exists())
      // sc failed
      scrbrd.expected_data_resp.push_back(1'b1);
      scrbrd.expected_metadata_resp.push_back(metadata);
    end
  endtask; // store_conditional

endclass : Monitor;


/**************
 * Scoreboard *
 **************/
class Scoreboard;
  data_t expected_data_resp[$];
  data_t actual_data_resp[$];

  bank_metadata_t expected_metadata_resp[$];
  bank_metadata_t actual_metadata_resp[$];

  int success_counter;
  int number_of_resp;

  function void compare_responses();
    success_counter = 0;
    number_of_resp = expected_data_resp.size();
    if (number_of_resp > actual_data_resp.size()) begin
      $display("NUMBER OF EXPECTED RESPONSES DOES NOT MATCH RECEIVED RESPONSES!");
      number_of_resp = actual_data_resp.size();
    end
    $display("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
    $display("+                        RESULTS                           +");
    $display("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");

    for (int i=0; i < number_of_resp; i++) begin
      if (expected_data_resp[i] == actual_data_resp[i] &&
          expected_metadata_resp[i] == actual_metadata_resp[i]) begin
        success_counter += 1;
        if (VERBOSE) begin
          $display("PASS");
        end
      end else begin
        $display("FAIL");
        $display( "%-30s %h != %h","Data", expected_data_resp[i], actual_data_resp[i]);
        $display( "%-30s %h != %b","Metadata", expected_metadata_resp[i], actual_metadata_resp[i]);
        $display("++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++");
      end
    end
    $display("[%2d/%2d] responses match", success_counter, number_of_resp);
    if (success_counter != number_of_resp) begin
      $display("[EOC] Simulation ended at %t (retval = %0d).", $time, 1);
      $finish(1);
    end
  endfunction // compare
endclass // Scoreboard

  InputDriver inpdriver;

  TcdmRequest req;

  RespDriver respdriver;
  Generator generator;
  Monitor monitor;

  Scoreboard scrbrd;

  task store_conditional(input addr_t addr,
                         input     data_t data,
                         input int core_id);

    req = new(.req_addr(addr), .req_data(data),
                 .req_amo(4'hB),
                 .req_wen(1'b0),
                 .req_be(4'hF),
                 .abs_core_id(core_id));
    inpdriver.send_request(req);
  endtask // store_conditional

  task load_reserved(input addr_t addr,
                     input data_t data,
                     input int core_id);

    req = new(.req_addr(addr), .req_data(data),
                 .req_amo(4'hA),
                 .req_wen(1'b0),
                 .req_be(4'h0),
                 .abs_core_id(core_id));
    inpdriver.send_request(req);
  endtask // load_reserved

  task write_memory( input addr_t addr,
                     input data_t data,
                     input int core_id);
    req = new(.req_addr(addr), .req_data(data),
              .req_amo(4'h0),
              .req_wen(1'b1),
              .req_be(4'hF),
              .abs_core_id(core_id));
    inpdriver.send_request(req);
  endtask // write_memory

  task read_memory( input addr_t addr,
                     input data_t data,
                     input int core_id);
    req = new(.req_addr(addr), .req_data(data),
              .req_amo(4'h0),
              .req_wen(1'b0),
              .req_be(4'h0),
              .abs_core_id(core_id));
    inpdriver.send_request(req);
  endtask // read_memory


  /**************
   * Simulation *
   **************/

  initial begin : req_driver
    // Wait for reset.
    wait (rst_n);
    @(posedge clk);

    inpdriver = new();
    respdriver = new();
    scrbrd = new();
    generator = new(.num_iter(NumIterations), .random_test(FULL_RANDOM_TEST));
    monitor = new();

    fork : Listener
      respdriver.listen();
    join_none
    #(10*ClockPeriod);

    if(!generator.randomize()) begin
      $display("Failed to randomize Generator class.");
      $display("[EOC] Simulation ended at %t (retval = %0d).", $time, 1);
      $finish(1);
    end
    generator.generate_requests();
    #(10*ClockPeriod);

    //    respdriver.display_responses();

    respdriver.finished_generator = 1'b1;
    scrbrd.compare_responses();

    $display("[EOC] Simulation ended at %t (retval = %0d).", $time, 0);
    $finish(0);
  end // req_driver

endmodule : tcdm_adapter_tb
