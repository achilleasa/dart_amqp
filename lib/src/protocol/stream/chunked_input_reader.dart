part of dart_amqp.protocol;

class ChunkedInputReader {
  final _bufferedChunks = ListQueue<List<int>>();
  int _usedHeadBytes = 0;

  /// Add a [chunk] to the buffer queue

  void add(List<int> chunk) => _bufferedChunks.add(chunk);

  /// Get the total available bytes in all chunk buffers (excluding bytes already de-queued from head buffer).

  int get length => _bufferedChunks.fold(
      -_usedHeadBytes, (int count, List<int> el) => count + el.length);

  /// Return the next byte in the buffer without modifying the read pointer.
  /// Returns the [int] value of the next byte or null if no data is available

  int peekNextByte() {
    // No data available
    if (_bufferedChunks.isEmpty || length < 1) {
      return null;
    }

    return _bufferedChunks.first[_usedHeadBytes];
  }

  /// Try to read [count] bytes into [destination] at the specified [offset].
  /// This method will automatically de-queue exhausted head buffers from the queue
  /// and will return the total number of bytes written

  int read(List<int> destination, int count, [int offset = 0]) {
    int writeOffset = offset;
    while (count > 0) {
      // If we ran out of buffers we are done
      if (_bufferedChunks.isEmpty) {
        break;
      }

      // If we ran out of bytes to copy we are also done
      int remainingHeadBytes = _bufferedChunks.first.length - _usedHeadBytes;
      if (remainingHeadBytes == 0) {
        break;
      }

      // If the remaining head buffer can fill the destination entirely, copy it and de-queue head
      if (remainingHeadBytes <= count) {
        destination.setRange(writeOffset, writeOffset + remainingHeadBytes,
            _bufferedChunks.removeFirst(), _usedHeadBytes);
        _usedHeadBytes = 0;
        count -= remainingHeadBytes;
        writeOffset += remainingHeadBytes;
      } else {
        // Copy as much as we can skipping any already dequeued bytes
        destination.setRange(writeOffset, writeOffset + count,
            _bufferedChunks.first, _usedHeadBytes);
        _usedHeadBytes += count;
        writeOffset += count;
        count = 0;
      }
    }

    return writeOffset - offset;
  }
}
