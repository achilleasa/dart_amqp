part of dart_amqp.protocol;

class ChunkedOutputWriter {
  final ListQueue<Uint8List> _bufferedChunks = ListQueue<Uint8List>();

  /// Add a [chunk] to the head of the buffer queue

  void addFirst(Uint8List chunk) => _bufferedChunks.addFirst(chunk);

  /// Append a [chunk] to the buffer queue

  void addLast(Uint8List chunk) => _bufferedChunks.add(chunk);

  /// Clear buffer

  void clear() => _bufferedChunks.clear();

  /// Get the total available bytes in all chunk buffers (excluding bytes already de-queued from head buffer).

  int get lengthInBytes =>
      _bufferedChunks.fold(0, (int count, el) => count + el.length);

  /// Pipe all buffered chunks to [destination] and clear the buffer queue

  void pipe(Sink destination) {
    if (destination == null) {
      return;
    }
    destination.add(
        joinChunks()); //_bufferedChunks.forEach((Uint8List block) => destination.add(block));
    clear();
  }

  /// Join all chunk blocks into a contiguous chunk
  Uint8List joinChunks() {
    Uint8List out = Uint8List(lengthInBytes);
    int offset = 0;
    _bufferedChunks.forEach((Uint8List block) {
      int len = block.lengthInBytes;
      out.setRange(offset, offset + len, block);
      offset += len;
    });

    return out;
  }
}
