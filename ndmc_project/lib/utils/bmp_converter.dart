import 'dart:typed_data';
import 'package:camera/camera.dart';

class BmpConverter {
  static Uint8List convertGrayscaleToBmp(CameraImage image) {
    // Dynamically calculate downsample step to lock network width at ~240 pixels
    // 240p width is highly optimized for lightweight websocket streams
    final int origWidth = image.width;
    final int origHeight = image.height;
    int step = origWidth ~/ 240;
    if (step < 1) step = 1;
    
    final int width = origWidth ~/ step;
    final int height = origHeight ~/ step;
    
    final Uint8List yPlane = image.planes[0].bytes;
    final int bytesPerRow = image.planes[0].bytesPerRow;
    
    // 8-bit BMP lines must be padded to a multiple of 4 bytes
    final int rowSize = ((width + 3) ~/ 4) * 4;
    final int imageSize = rowSize * height;
    final int fileSize = 1078 + imageSize; // 54 header + 1024 palette + image
    
    final Uint8List bmp = Uint8List(fileSize);
    final ByteData bd = ByteData.view(bmp.buffer);
    
    // BMP Header (14 bytes)
    bd.setUint8(0, 0x42); // 'B'
    bd.setUint8(1, 0x4D); // 'M'
    bd.setUint32(2, fileSize, Endian.little);
    bd.setUint32(10, 1078, Endian.little); // Pixel data offset
    
    // DIB Header (40 bytes)
    bd.setUint32(14, 40, Endian.little); 
    bd.setUint32(18, width, Endian.little);
    bd.setInt32(22, -height, Endian.little); // Top-down format
    bd.setUint16(26, 1, Endian.little); // Planes
    bd.setUint16(28, 8, Endian.little); // 8-bit grayscale
    bd.setUint32(30, 0, Endian.little); // No compression
    bd.setUint32(34, imageSize, Endian.little);
    bd.setUint32(46, 256, Endian.little); // Colors in palette
    bd.setUint32(50, 256, Endian.little); // Important colors
    
    // Grayscale Color Table (1024 bytes)
    int paletteOffset = 54;
    for (int i = 0; i < 256; i++) {
      bmp[paletteOffset++] = i; // B
      bmp[paletteOffset++] = i; // G
      bmp[paletteOffset++] = i; // R
      bmp[paletteOffset++] = 0; // Reserved
    }
    
    // Pixel Data (Dynamically Downsampled)
    int offset = 1078;
    for (int y = 0; y < height; y++) {
      int rowOffset = offset + y * rowSize;
      int origY = y * step;
      for (int x = 0; x < width; x++) {
        int origX = x * step;
        int index = origY * bytesPerRow + origX;
        bmp[rowOffset + x] = (index < yPlane.length) ? yPlane[index] : 0;
      }
    }
    
    return bmp;
  }
}
