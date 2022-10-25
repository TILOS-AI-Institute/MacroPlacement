// Generated register defines for mempool_dma_frontend

// Copyright information found in source file:
// Copyright 2022 ETH Zurich and University of Bologna.

// Licensing information found in source file:
// Licensed under Solderpad Hardware License, Version 0.51, see LICENSE for details.
// SPDX-License-Identifier: SHL-0.51

#ifndef _MEMPOOL_DMA_FRONTEND_REG_DEFS_
#define _MEMPOOL_DMA_FRONTEND_REG_DEFS_

#ifdef __cplusplus
extern "C" {
#endif
// Register width
#define MEMPOOL_DMA_FRONTEND_PARAM_REG_WIDTH 32

// Source Address
#define MEMPOOL_DMA_FRONTEND_SRC_ADDR_REG_OFFSET 0x0

// Destination Address
#define MEMPOOL_DMA_FRONTEND_DST_ADDR_REG_OFFSET 0x4

// Transfer size in bytes
#define MEMPOOL_DMA_FRONTEND_NUM_BYTES_REG_OFFSET 0x8

// Configuration Register for DMA settings
#define MEMPOOL_DMA_FRONTEND_CONF_REG_OFFSET 0xc
#define MEMPOOL_DMA_FRONTEND_CONF_DECOUPLE_BIT 0
#define MEMPOOL_DMA_FRONTEND_CONF_DEBURST_BIT 1
#define MEMPOOL_DMA_FRONTEND_CONF_SERIALIZE_BIT 2

// DMA Status
#define MEMPOOL_DMA_FRONTEND_STATUS_REG_OFFSET 0x10
#define MEMPOOL_DMA_FRONTEND_STATUS_BUSY_BIT 0

// Next ID launches transfer returns 0 if transfer not set up properly.
#define MEMPOOL_DMA_FRONTEND_NEXT_ID_REG_OFFSET 0x14

// Get ID of finished transactions.
#define MEMPOOL_DMA_FRONTEND_DONE_REG_OFFSET 0x18

#ifdef __cplusplus
}  // extern "C"
#endif
#endif  // _MEMPOOL_DMA_FRONTEND_REG_DEFS_
// End generated register defines for mempool_dma_frontend