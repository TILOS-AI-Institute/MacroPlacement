#!/bin/bash
# Copyright 2020 ETH Zurich and University of Bologna.
# Solderpad Hardware License, Version 0.51, see LICENSE for details.
# SPDX-License-Identifier: SHL-0.51
#
# Fabian Schuiki <fschuiki@iis.ee.ethz.ch>
# Andreas Kurth  <akurth@iis.ee.ethz.ch>

set -e
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

[ ! -z "$VSIM" ] || VSIM=vsim

call_vsim() {
    echo "log -r /*; run -all" | $VSIM -c -coverage -voptargs='+acc +cover=sbecft' "$@" | tee vsim.log 2>&1
    grep "Errors: 0," vsim.log
}

call_vsim axi_to_reqrsp_tb
call_vsim reqrsp_to_axi_tb
call_vsim reqrsp_mux_tb
call_vsim reqrsp_demux_tb
# Test `reqrsp_cut`
call_vsim reqrsp_idempotent_tb -gCut=1 -gIso=0
# Test `reqrsp_iso`
call_vsim reqrsp_idempotent_tb -gCut=0 -gIso=1
