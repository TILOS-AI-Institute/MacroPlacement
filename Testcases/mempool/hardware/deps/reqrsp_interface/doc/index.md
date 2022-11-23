# Reqrsp Interface

The `reqrsp_interface` (request and response) is a custom interface based on
common principles found in other interconnects such as AXI or TileLink. It has
only two channels (request and response) which are handshaked according to the
AMBA standard:

- The initiator asserts `valid`. The assertion of `valid` must not depend on
  `ready`.
- Once `valid` has been asserted all data must remain stable.
- The receiver asserts `ready` whenever it is ready to receive the transaction.
- When both `valid` and `ready` are high the transaction is successful.

The bus is little endian.

## Channels

The two channels are:

- Request (`q`): The initiator requests a memory transaction. Supported are
  read, write, atomic memory operations, load-linked and store-conditional
  pairs.
- Response (`p`): _Every_ transaction which was requested ultimately returns a
  response. For reads the response channel returns the read response, for writes
  the response acknowledges that the data is committed and subsequent reads will
  return the last written value, for atomic operations the data _before_ the
  memory operations has happened is being returned. For load-linked the the read
  response is returned, for store-conditionals the the success code is returned.
  Additionally, the response channel carries error information.

## Sizes

Data bus size of 32, 64, 128, 256, 512, 1024-bit are supported. Atomic memory
operations are 32 bit or 64 bit for bus sizes greater than 32.

## Data Alignment

The data is always bus-aligned. similar to AXI. For reads the address and size
fields indicate which data is valid. Similarly for writes the address and size
fields in addition to the write strobe field indicate valid bytes (8 bit of
data). Atomics and LR/SCs addresses are always naturally aligned to their size.

## Ordering

Transactions on the request channel are always strongly ordered (as if they
would all use the same ID in AXI terms). Reads and writes are ordered with
respect to each other (that needs to be maintained when translating to AXI).

## Atomic Memory Operations

Atomic memory operations supported are:

| Operation          | Description                                                               |
| ------------------ | ------------------------------------------------------------------------- |
| `Swap`             | Swaps the values.                                                         |
| `Add`              | Signed addition.                                                          |
| `And`, `Or`, `Xor` | Bitwise `and`, `or`, and `xor` operation.                                 |
| `Max`, `Maxu`      | Signed and unsigned maximum operation.                                    |
| `Min`, `Minu`      | Signed and unsigned minimum operation.                                    |
| `Lr`               | Places a reservation on the given memory address                          |
| `Sc`               | Conditional store, returns `0` on `q.data` if successful, `1` otherwise.  |


The operation reads the value at the given address and returns the read value on
the `p` channel. The same memory location is updated with the data and operation
supplied on the `q.amo` and `q.data` signals. The `q.write` signal must be set to `1'b0`.

## Load-Reserved/Store-conditional

The `q.amo` field carries the information on whether the transaction encodes an
LR/SC.

| Operation    | Description                                                               |
| ------------ | ------------------------------------------------------------------------- |
| Lr           | Places a reservation on the given memory address                          |
| Sc           | Conditional store, returns `0` on `q.data` if successful, `1` otherwise.  |

For `Sc` and `LR` the `q.write` signal must be set to `0`.

## Error

The `p` channel carries additional error information:

- `0`: The access is ok.
- `1`: The access has encountered an error.
