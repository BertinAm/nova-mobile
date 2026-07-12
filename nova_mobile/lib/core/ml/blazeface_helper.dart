import 'dart:math';

class BlazeFaceHelper {
  static List<List<double>>? _anchors;

  static List<List<double>> get anchors {
    if (_anchors != null) return _anchors!;
    _anchors = [];
    for (int y = 0; y < 16; y++) {
      for (int x = 0; x < 16; x++) {
        _anchors!.add([(x + 0.5) / 16.0, (y + 0.5) / 16.0]);
        _anchors!.add([(x + 0.5) / 16.0, (y + 0.5) / 16.0]);
      }
    }
    for (int y = 0; y < 8; y++) {
      for (int x = 0; x < 8; x++) {
        for (int i = 0; i < 6; i++) {
          _anchors!.add([(x + 0.5) / 8.0, (y + 0.5) / 8.0]);
        }
      }
    }
    return _anchors!;
  }

  static double _sigmoid(double x) {
    return 1.0 / (1.0 + exp(-x));
  }

  /// Returns the bounding box of the most prominent face found, or null if none.
  static Rectangle<int>? getBestFace(List<List<List<double>>> boxes, List<List<List<double>>> scores, int imageWidth, int imageHeight) {
    double bestScore = 0.0;
    int bestIdx = -1;

    for (int i = 0; i < 896; i++) {
      double rawScore = scores[0][i][0];
      // BlazeFace often outputs raw logits. Convert to probability.
      // If it's already a probability (0-1), sigmoid will be > 0.5 but that's safe.
      // It's usually logits, so we check rawScore > 0 or sigmoid(rawScore) > 0.6.
      double score = rawScore > 1.0 || rawScore < 0.0 ? _sigmoid(rawScore) : rawScore;
      
      if (score > bestScore) {
        bestScore = score;
        bestIdx = i;
      }
    }

    if (bestIdx == -1 || bestScore < 0.65) return null;

    final anc = anchors[bestIdx];
    // BlazeFace outputs offsets relative to the 128x128 input.
    double cx = anc[0] + (boxes[0][bestIdx][0] / 128.0);
    double cy = anc[1] + (boxes[0][bestIdx][1] / 128.0);
    double w = boxes[0][bestIdx][2] / 128.0;
    double h = boxes[0][bestIdx][3] / 128.0;

    int x = ((cx - w / 2) * imageWidth).round();
    int y = ((cy - h / 2) * imageHeight).round();
    int width = (w * imageWidth).round();
    int height = (h * imageHeight).round();

    // Add 20% padding around the face for a better crop (helps embeddings)
    int padX = (width * 0.2).round();
    int padY = (height * 0.2).round();

    return Rectangle<int>(
      max(0, x - padX),
      max(0, y - padY),
      width + padX * 2,
      height + padY * 2
    );
  }

  /// Returns all faces above a threshold.
  static List<Rectangle<int>> getAllFaces(List<List<List<double>>> boxes, List<List<List<double>>> scores, int imageWidth, int imageHeight) {
    List<Rectangle<int>> results = [];
    
    for (int i = 0; i < 896; i++) {
      double rawScore = scores[0][i][0];
      double score = rawScore > 1.0 || rawScore < 0.0 ? _sigmoid(rawScore) : rawScore;
      
      if (score > 0.65) {
        final anc = anchors[i];
        double cx = anc[0] + (boxes[0][i][0] / 128.0);
        double cy = anc[1] + (boxes[0][i][1] / 128.0);
        double w = boxes[0][i][2] / 128.0;
        double h = boxes[0][i][3] / 128.0;

        int x = ((cx - w / 2) * imageWidth).round();
        int y = ((cy - h / 2) * imageHeight).round();
        int width = (w * imageWidth).round();
        int height = (h * imageHeight).round();

        int padX = (width * 0.2).round();
        int padY = (height * 0.2).round();

        results.add(Rectangle<int>(
          max(0, x - padX),
          max(0, y - padY),
          width + padX * 2,
          height + padY * 2
        ));
      }
    }
    return results;
  }
}
