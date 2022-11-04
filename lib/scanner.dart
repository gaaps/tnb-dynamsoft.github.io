import 'dart:typed_data';

import 'package:dynamsoft_web_test/web_camera_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_barcode_sdk/dynamsoft_barcode.dart';
import 'package:flutter_barcode_sdk/flutter_barcode_sdk.dart';

class ScannerWidget extends StatefulWidget {
  const ScannerWidget({Key? key, required this.onScannedCodes})
      : super(key: key);

  final Function(List<String>) onScannedCodes;

  @override
  State<ScannerWidget> createState() => _ScannerWidgetState();
}

class _ScannerWidgetState extends State<ScannerWidget> {
  final WebCameraController _controller = WebCameraController();
  final FlutterBarcodeSdk _dynamsoft = FlutterBarcodeSdk();

  final String _dynamsoftParameters =
      r'{"ImageParameter": {"BarcodeFormatIds": ["BF_ALL"],"BarcodeFormatIds_2": ["BF2_NULL"],"DeblurLevel": 9,"DeblurModes": [{"Mode": "DM_DEEP_ANALYSIS"}],"Description": "","ExpectedBarcodesCount": 2,"LocalizationModes": [{"IsOneDStacked": 0,"LibraryFileName": "","LibraryParameters": "","Mode": "LM_SCAN_DIRECTLY","ScanDirection": 0, "ScanStride": 0},{"LibraryFileName": "","LibraryParameters": "","Mode": "LM_CONNECTED_BLOCKS"}],"ImagePreprocessingModes": [{"LibraryFileName": "","LibraryParameters": "","Mode": "IPM_GRAY_SMOOTH"},{"LibraryFileName": "","LibraryParameters": "","Mode": "IPM_GENERAL"}    ],"MaxAlgorithmThreadCount": 1,"Name": "Settings","Timeout": 1000000},"Version": "3.0"}';

  List<String> scannedCodes = [];

  bool _isScanning = false;

  //
  // Lifecycle
  //

  @override
  void initState() {
    super.initState();
    _setup();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  //
  // Actions
  //

  Future<void> _setup() async {
    await _dynamsoft
        .setLicense(
            "DLS2eyJoYW5kc2hha2VDb2RlIjoiMTAxMzcxNzgyLVRYbFhaV0pRY205cVgyUmljZyIsIm9yZ2FuaXphdGlvbklEIjoiMTAxMzcxNzgyIiwiY2hlY2tDb2RlIjo2NjY5NjI1MDF9")
        .catchError((e) {});
    await _dynamsoft.init();
    await _dynamsoft.setParameters(_dynamsoftParameters);
    await _controller.init(
        facing: WebCameraFacing.back,
        streamImages: true,
        format: WebCameraOutputFormat.bytes,
        onImage: _onWebScannerImage);
    setState(() {});
  }

  Future<void> _onWebScannerImage(List<int>? imageData) async {
    if (_isScanning ||
        imageData == null ||
        _controller.webviewVideoSize == null) return;

    print("WEBVIEW VIDEO SIZE : ${_controller.webviewVideoSize}");

    int appliedWidth = _controller.webviewVideoSize!.width.toInt();
    int appliedHeight = _controller.webviewVideoSize!.height.toInt();

    // int appliedHeight;
    // int appliedWidth;
    // if (_controller.webviewVideoSize!.width >
    //     _controller.webviewVideoSize!.height) {
    //   appliedWidth = _controller.webviewVideoSize!.width.toInt();
    //   appliedHeight = _controller.webviewVideoSize!.height.toInt();
    // } else {
    //   appliedWidth = _controller.webviewVideoSize!.height.toInt();
    //   appliedHeight = _controller.webviewVideoSize!.width.toInt();
    // }

    print("Applied dimensions : $appliedWidth x $appliedHeight");

    _isScanning = true;
    final List<BarcodeResult> results = await _dynamsoft.decodeImageBuffer(
      Uint8List.fromList(imageData),
      appliedWidth,
      appliedHeight,
      appliedWidth * 4,
      10, // TODO: replace with Dynamsoft Capture Vision when it's out
    );
    print("Barcodes found : ${results.map((res) => res.text).toList()}");
    _isScanning = false;
    widget.onScannedCodes(results.map((res) => res.text).toList());
  }

  //
  // UI
  //

  @override
  Widget build(BuildContext context) {
    if (_controller.webviewVideoSize == null) return Container();
    return LayoutBuilder(builder: (context, constraints) {
      return ClipRect(
        child: SizedBox(
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: _controller.webviewVideoSize!.width,
              height: _controller.webviewVideoSize!.height,
              child: HtmlElementView(viewType: _controller.webviewId),
            ),
          ),
        ),
      );
    });
  }
}
