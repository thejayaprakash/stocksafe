import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Parsed metadata extracted from a product label via OCR.
class ParsedLabelData {
  const ParsedLabelData({
    this.suggestedName,
    this.mrp,
    this.batchNumber,
    this.expiryDate,
    this.netQuantity,
    this.rawText = '',
  });

  final String? suggestedName;
  final double? mrp;
  final String? batchNumber;
  final String? expiryDate;
  final String? netQuantity;
  final String rawText;

  bool get hasAnyExtractedField =>
      suggestedName != null ||
      mrp != null ||
      batchNumber != null ||
      expiryDate != null ||
      netQuantity != null;
}

/// Service that performs on-device OCR using ML Kit and parses key
/// packaging fields (MRP, Expiry, Batch, Net Qty).
class LabelOcrService {
  LabelOcrService({TextRecognizer? recognizer})
      : _recognizer = recognizer ?? TextRecognizer(script: TextRecognitionScript.latin);

  final TextRecognizer _recognizer;

  /// Process an image file and return extracted label fields.
  Future<ParsedLabelData> extractFromImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);
    return parseText(recognizedText.text);
  }

  /// Parse raw recognized text into structured label attributes.
  ParsedLabelData parseText(String fullText) {
    if (fullText.trim().isEmpty) {
      return const ParsedLabelData();
    }

    final lines = fullText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    double? extractedMrp;
    String? extractedBatch;
    String? extractedExpiry;
    String? extractedQuantity;
    String? candidateName;

    // 1. MRP / Price Regex
    final mrpRegex = RegExp(
      r'(?:MRP|M\.R\.P|PRICE|MAX\.?\s*RETAIL\s*PRICE)?\s*(?:RS\.?|INR|₹)?\s*([0-9]+(?:\.[0-9]{1,2})?)',
      caseSensitive: false,
    );

    // 2. Expiry / Best Before Regex (3-part date before 2-part date)
    final expRegex = RegExp(
      r'(?:EXP(?:IRY)?|USE\s*BY|BEST\s*BEFORE|BB|B\.B)\s*[:\.\-]?\s*([0-9]{1,2}[\/\-\.][0-9]{1,2}[\/\-\.][0-9]{2,4}|[0-9]{1,2}[\/\-\.][0-9]{2,4}|[A-Za-z]{3}[\s\/\-][0-9]{2,4})',
      caseSensitive: false,
    );

    // 3. Batch / Lot Regex
    final batchRegex = RegExp(
      r'(?:BATCH(?:\s*NO)?|B\.?\s*NO|LOT(?:\s*NO)?)\s*[:\.\-]?\s*([A-Za-z0-9\-\/]{3,15})',
      caseSensitive: false,
    );

    // 4. Net Quantity Regex
    final qtyRegex = RegExp(
      r'(?:NET\s*(?:QTY|WT|WEIGHT|VOLUME|CONTENT)?)\s*[:\.\-]?\s*([0-9]+(?:\.[0-9]+)?\s*(?:g|kg|ml|l|ltr|pcs|pack|gm))',
      caseSensitive: false,
    );

    final standaloneQtyRegex = RegExp(
      r'\b([0-9]+(?:\.[0-9]+)?\s*(?:g|kg|ml|l|ltr|pcs|gm))\b',
      caseSensitive: false,
    );

    for (final line in lines) {
      // Check MRP
      if (extractedMrp == null && (line.toUpperCase().contains('MRP') || line.contains('₹') || line.toUpperCase().contains('RS'))) {
        final match = mrpRegex.firstMatch(line);
        if (match != null && match.group(1) != null) {
          final val = double.tryParse(match.group(1)!);
          if (val != null && val > 0 && val < 100000) {
            extractedMrp = val;
          }
        }
      }

      // Check Expiry
      if (extractedExpiry == null) {
        final match = expRegex.firstMatch(line);
        if (match != null && match.group(1) != null) {
          extractedExpiry = match.group(1)!.trim();
        }
      }

      // Check Batch
      if (extractedBatch == null) {
        final match = batchRegex.firstMatch(line);
        if (match != null && match.group(1) != null) {
          extractedBatch = match.group(1)!.trim();
        }
      }

      // Check Net Quantity
      if (extractedQuantity == null) {
        final match = qtyRegex.firstMatch(line) ?? standaloneQtyRegex.firstMatch(line);
        if (match != null && match.group(1) != null) {
          extractedQuantity = match.group(1)!.trim();
        }
      }
    }

    // Try finding candidate name from early line that isn't a date, batch, or price
    for (final line in lines.take(4)) {
      if (!line.toUpperCase().contains('MRP') &&
          !line.toUpperCase().contains('BATCH') &&
          !line.toUpperCase().contains('EXP') &&
          !line.toUpperCase().contains('MFG') &&
          line.length > 3 &&
          line.length < 50) {
        candidateName = line;
        break;
      }
    }

    return ParsedLabelData(
      suggestedName: candidateName,
      mrp: extractedMrp,
      batchNumber: extractedBatch,
      expiryDate: extractedExpiry,
      netQuantity: extractedQuantity,
      rawText: fullText,
    );
  }

  void dispose() {
    _recognizer.close();
  }
}
