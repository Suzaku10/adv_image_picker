import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:adv_camera/adv_camera.dart';
import 'package:adv_image_picker/adv_image_picker.dart';
import 'package:adv_image_picker/components/toast.dart';
import 'package:adv_image_picker/models/result_item.dart';
import 'package:adv_image_picker/pages/gallery.dart';
import 'package:adv_image_picker/pages/result.dart';
import 'package:adv_image_picker/plugins/adv_image_picker_plugin.dart';
import 'package:basic_components/components/adv_loading_with_barrier.dart';
import 'package:basic_components/components/adv_visibility.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class CameraPage extends StatefulWidget {
  final bool allowMultiple;
  final bool enableGallery;
  final bool useCustomView;
  final bool useFlash;
  final bool switchCamera;
  final int maxSize;
  final String addedText;

  CameraPage(
      {bool allowMultiple,
      bool enableGallery,
      bool useCustomView,
      bool switchCamera,
      this.maxSize,
      bool useFlash,
      this.addedText})
      : assert(maxSize == null || maxSize >= 0),
        this.allowMultiple = allowMultiple ?? true,
        this.enableGallery = enableGallery ?? true,
        this.useFlash = useFlash ?? true,
        this.switchCamera = switchCamera ?? true,
        this.useCustomView = useCustomView ?? false;

  @override
  _CameraPageState createState() {
    return _CameraPageState();
  }
}

void logError(String code, String message) => print(
    '${AdvImagePicker.error}: $code\n${AdvImagePicker.errorMessage}: $message');

class _CameraPageState extends State<CameraPage> with WidgetsBindingObserver {
  AdvCameraController controller;
  String imagePath;
  int _currentCameraIndex = 0;
  Completer<String> takePictureCompleter;
  FlashType flashType = FlashType.off;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AdvImagePicker.customAppBar ??
          AppBar(
              title: Text(
                AdvImagePicker.takePicture,
                style: TextStyle(color: Colors.black87),
              ),
              centerTitle: true,
              elevation: 0.0,
              backgroundColor: Colors.white,
              iconTheme: IconThemeData(color: Colors.black87),
              actions: widget.switchCamera
                  ? [
                      IconButton(
                          icon: Icon(Icons.switch_camera),
                          onPressed: () {
                            controller.switchCamera();
                          })
                    ]
                  : null),
      key: _scaffoldKey,
      body: _buildWidget(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Stack(
        children: <Widget>[
          AdvVisibility(
              visibility: widget.useFlash
                  ? VisibilityFlag.visible
                  : VisibilityFlag.gone,
              child: Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: FloatingActionButton(
                      heroTag: null,
                      onPressed: () async {
                        setState(() {
                          flashType = flashType == FlashType.off
                              ? FlashType.on
                              : FlashType.off;
                          controller.setFlashType(flashType);
                        });
                      },
                      child: Icon(flashType == FlashType.off
                          ? Icons.flash_on
                          : Icons.flash_off),
                    ),
                  ))),
          Align(
              alignment: Alignment.bottomCenter,
              child: FloatingActionButton(
                elevation: 0.0,
                onPressed: () {
                  takePicture().then((resultPath) async {
                    if (resultPath == null) return;
                    ByteData bytes = await _readFileByte(resultPath);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (BuildContext context) => ResultPage(
                                [ResultItem("", resultPath, data: bytes)])));
                  });
                },
                backgroundColor: AdvImagePicker.primaryColor,
                highlightElevation: 0.0,
                child: Container(
                  width: 30.0,
                  height: 30.0,
                  child: AdvImagePicker.assets == null
                      ? Icon(Icons.camera)
                      : Image(
                          image: AssetImage(AdvImagePicker.assets),
                          fit: BoxFit.fill),
                ),
              )),
          AdvVisibility(
            visibility: widget.enableGallery
                ? VisibilityFlag.visible
                : VisibilityFlag.gone,
            child: Padding(
              padding: EdgeInsets.only(right: 16),
              child: Align(
                alignment: Alignment.bottomRight,
                child: FloatingActionButton(
                  heroTag: null,
                  onPressed: () async {
                    if (Platform.isIOS) {
                      bool hasPermission =
                          await AdvImagePickerPlugin.getIosStoragePermission();
                      if (!hasPermission) {
                        Toast.showToast(context, "Permission denied");
                        return null;
                      } else {
                        goToGallery();
                      }
                    } else {
                      goToGallery();
                    }
                  },
                  child: Icon(Icons.photo),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<ByteData> _readFileByte(String filePath) async {
    Uri myUri = Uri.parse(filePath);
    File imageFile = new File.fromUri(myUri);
    Uint8List bytes;
    await imageFile.readAsBytes().then((value) {
      bytes = Uint8List.fromList(value);
    }).catchError((onError) {
      print('Exception Error while reading audio from path:' +
          onError.toString());
    });
    return bytes.buffer.asByteData();
  }

  goToGallery() {
    Navigator.push(
        context,
        MaterialPageRoute(
            builder: (BuildContext context) => GalleryPage(
                  allowMultiple: widget.allowMultiple,
                  maxSize: widget.maxSize,
                )));
  }

  Widget _buildWidget(BuildContext context) {
    return AdvLoadingWithBarrier(
        content: (BuildContext context) => _cameraPreviewWidget(context),
        isProcessing: controller == null);
  }

  /// Display the preview from the camera (or a message if the preview is not available).
  Widget _cameraPreviewWidget(BuildContext context) {
    return AdvCamera(
      onCameraCreated: _onCameraCreated,
      onImageCaptured: (String path) {
        takePictureCompleter.complete(path);
        takePictureCompleter = null;
      },
      cameraPreviewRatio: CameraPreviewRatio.r16_9,
      useCustomRect: widget.useCustomView,
      flashType: flashType,
      addedText: widget.addedText,
    );
  }

  String timestamp() => DateTime.now().millisecondsSinceEpoch.toString();

  void showInSnackBar(String message) {
    _scaffoldKey.currentState.showSnackBar(SnackBar(content: Text(message)));
  }

  Future<String> takePicture() async {
    if (controller == null || takePictureCompleter != null) {
      return null;
    }

    takePictureCompleter = Completer<String>();

    await controller.captureImage(maxSize: widget.maxSize);

    return await takePictureCompleter.future;
  }

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onCameraCreated(AdvCameraController controller) {
    this.controller = controller;

    getApplicationDocumentsDirectory().then((Directory extDir) async {
      final String dirPath = '${extDir.path}/Pictures';
      await Directory(dirPath).create(recursive: true);

      await controller.setSavePath(dirPath);
    });

    setState(() {});
  }
}
