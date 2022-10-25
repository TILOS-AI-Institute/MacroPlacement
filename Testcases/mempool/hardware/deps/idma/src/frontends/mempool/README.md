# MemPool Front-end

This front-end implements a 'distributed' DMA with a single front-end but multiple back-ends. Each back-end is responsible for one area of the memory, which is interleaved. This means that a mid-end will split up single one-dimensional DMA requests into multiple DMA requests going to the corresponding back-ends.
