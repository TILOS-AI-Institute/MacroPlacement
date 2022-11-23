// Copyright 2018 ETH Zurich and University of Bologna.
// Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51
//
// Author: Florian Zaruba <zarubaf@iis.ee.ethz.ch>
// Date:   17.8.2018
//
// Description: Contains Snitch's AXI ports, does not contain user ports

package snitch_axi_pkg;

    localparam UserWidth = 1;
    localparam AddrWidth = 32;
    localparam DataWidth = 32;
    localparam StrbWidth = DataWidth / 8;

    typedef logic [snitch_pkg::IdWidth-1:0]      id_t;
    typedef logic [snitch_pkg::IdWidthSlave-1:0] id_slv_t;
    typedef logic [AddrWidth-1:0] addr_t;
    typedef logic [DataWidth-1:0] data_t;
    typedef logic [StrbWidth-1:0] strb_t;
    typedef logic [UserWidth-1:0] user_t;

    // AW Channel
    typedef struct packed {
        id_t              id;
        addr_t            addr;
        axi_pkg::len_t    len;
        axi_pkg::size_t   size;
        axi_pkg::burst_t  burst;
        logic             lock;
        axi_pkg::cache_t  cache;
        axi_pkg::prot_t   prot;
        axi_pkg::qos_t    qos;
        axi_pkg::region_t region;
        axi_pkg::atop_t   atop;
    } aw_chan_t;

    // AW Channel - Slave
    typedef struct packed {
        id_slv_t          id;
        addr_t            addr;
        axi_pkg::len_t    len;
        axi_pkg::size_t   size;
        axi_pkg::burst_t  burst;
        logic             lock;
        axi_pkg::cache_t  cache;
        axi_pkg::prot_t   prot;
        axi_pkg::qos_t    qos;
        axi_pkg::region_t region;
        axi_pkg::atop_t   atop;
    } aw_chan_slv_t;

    // W Channel - AXI4 doesn't define a wid
    typedef struct packed {
        data_t data;
        strb_t strb;
        logic  last;
    } w_chan_t;

    // B Channel
    typedef struct packed {
        id_t            id;
        axi_pkg::resp_t resp;
    } b_chan_t;

    // B Channel - Slave
    typedef struct packed {
        id_slv_t        id;
        axi_pkg::resp_t resp;
    } b_chan_slv_t;

    // AR Channel
    typedef struct packed {
        id_t             id;
        addr_t            addr;
        axi_pkg::len_t    len;
        axi_pkg::size_t   size;
        axi_pkg::burst_t  burst;
        logic             lock;
        axi_pkg::cache_t  cache;
        axi_pkg::prot_t   prot;
        axi_pkg::qos_t    qos;
        axi_pkg::region_t region;
    } ar_chan_t;

    // AR Channel - Slave
    typedef struct packed {
        id_slv_t          id;
        addr_t            addr;
        axi_pkg::len_t    len;
        axi_pkg::size_t   size;
        axi_pkg::burst_t  burst;
        logic             lock;
        axi_pkg::cache_t  cache;
        axi_pkg::prot_t   prot;
        axi_pkg::qos_t    qos;
        axi_pkg::region_t region;
    } ar_chan_slv_t;

    // R Channel
    typedef struct packed {
        id_t            id;
        data_t          data;
        axi_pkg::resp_t resp;
        logic           last;
    } r_chan_t;

    // R Channel - Slave
    typedef struct packed {
        id_slv_t        id;
        data_t          data;
        axi_pkg::resp_t resp;
        logic           last;
    } r_chan_slv_t;

    // Request/Response structs
    typedef struct packed {
        aw_chan_t aw;
        logic     aw_valid;
        w_chan_t  w;
        logic     w_valid;
        logic     b_ready;
        ar_chan_t ar;
        logic     ar_valid;
        logic     r_ready;
    } req_t;

    typedef struct packed {
        logic     aw_ready;
        logic     ar_ready;
        logic     w_ready;
        logic     b_valid;
        b_chan_t  b;
        logic     r_valid;
        r_chan_t  r;
    } resp_t;

    typedef struct packed {
        aw_chan_slv_t aw;
        logic         aw_valid;
        w_chan_t      w;
        logic         w_valid;
        logic         b_ready;
        ar_chan_slv_t ar;
        logic         ar_valid;
        logic         r_ready;
    } req_slv_t;

    typedef struct packed {
        logic         aw_ready;
        logic         ar_ready;
        logic         w_ready;
        logic         b_valid;
        b_chan_slv_t  b;
        logic         r_valid;
        r_chan_slv_t  r;
    } resp_slv_t;

endpackage
