import 'package:dansertodiscord/spaced_row.dart';
import 'package:dansertodiscord/user_preference_field.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'dart:convert';
import 'package:http/http.dart';
// TODO set app icon and version
void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => AppState(),
      child: MaterialApp(title: "dansertodiscord", home: HomePage()),
    );
  }
}

class AppState extends ChangeNotifier {
  var isRenderingOrUploading = false;
  int renderProgress = 0;
  int uploadProgress = 0;

  // TODO implement logging to file as well
  var log = "";
  var danserLog = "";

  void appendToLog(String text) {
    log += "$text\n";
    notifyListeners();
  }

  void appendToDanserLog(String text) {
    danserLog += "$text\n";
    notifyListeners();
  }

  void toggleIsRenderingOrUploading() {
    isRenderingOrUploading = !isRenderingOrUploading;
    notifyListeners();
  }

  void updateRenderProgress(int progress) {
    if (progress < 0 || progress > 100) {
      throw ArgumentError("Progress out of bounds");
    } else {
      renderProgress = progress;
      notifyListeners();
    }
  }

  void updateUploadProgress(int progress) {
    if (progress < 0 || progress > 100) {
      throw ArgumentError("Progress out of bounds");
    } else {
      uploadProgress = progress;
      notifyListeners();
    }
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          bottom: const TabBar(
            tabs: [
              Tab(text: "Render"),
              Tab(text: "Settings"),
            ],
          ),
          toolbarHeight: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(4),
          child: TabBarView(children: [RenderView(), SettingsView()]),
        ),
      ),
    );
  }
}

class RenderView extends StatelessWidget {
  RenderView({super.key});

  final replayFileTextFieldController = TextEditingController();
  final logTextFieldController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<AppState>();

    return ListView(
      children: [
        SpacedRow(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(labelText: "Replay File"),
                controller: replayFileTextFieldController,
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ["osr"],
                  lockParentWindow: true,
                );
                if (result != null) {
                  replayFileTextFieldController.text =
                      result.files.single.path!;
                }
              },
              child: Text("Select File"),
            ),
            OutlinedButton(
              onPressed: () async {
                final outputFileName =
                    "danser_${DateFormat("yyyy-MM-dd_HH-mm-ss").format(DateTime.now())}";
                final prefs = await SharedPreferences.getInstance();
                final discordWebhookUrl =
                    prefs.getString("discordWebhookUrl") ?? "";
                final danserBinaryPath =
                    prefs.getString("danserBinaryPath") ?? "";
                var danserArguments = (prefs.getString("danserArguments") ?? "")
                    .split(" ");
                final replayFilePath = replayFileTextFieldController.text;
                final danserSettingsPath =
                    prefs.getString("danserSettingsPath") ?? "";
                final danserSettingsFileName = p.basenameWithoutExtension(
                  danserSettingsPath,
                );
                if (danserSettingsFileName != "") {
                  danserArguments.add("-settings");
                  danserArguments.add(danserSettingsFileName);
                }

                if (!context.mounted) return;

                appState.toggleIsRenderingOrUploading();
                // TODO add log and cancel button to dialog
                // TODO change dialog text when rendering finished
                showProgressDialog(context, "Render and Upload", "Video is rendering and uploading");

                final errorCode = await _renderVideo(
                  danserBinaryPath,
                  replayFilePath,
                  danserArguments,
                  outputFileName,
                  context,
                );

                appState.toggleIsRenderingOrUploading();

                if (errorCode == 0) {
                  var pathComponents = p.split(danserBinaryPath);
                  pathComponents.removeLast();

                  final danserFolderPath = p.joinAll(pathComponents);
                  var danserVideosFolder = Directory(
                    p.join(danserFolderPath, "videos"),
                  );
                  var videoFilePath = "";

                  await for (var file in danserVideosFolder.list()) {
                    if (p.basenameWithoutExtension(file.path) ==
                        outputFileName) {
                      videoFilePath = file.path;
                    }
                  }

                  var request = MultipartRequest(
                    "POST",
                    Uri.parse(discordWebhookUrl),
                  );

                  request.files.add(
                    await MultipartFile.fromPath("files[0]", videoFilePath),
                  );
                  var response = await request.send();
                  print(response.statusCode);
                } else {
                  print("error $errorCode");
                  // TODO check file size: if under 10 MiB upload to discord webhook, otherwise upload to litterbox
                  // TODO if over 1 GB, too large for litterbox, cancel upload
                }
              },
              child: Text("Render and Upload"),
            ),
          ],
        ),
        SpacedRow(
          children: [
            Expanded(
              child: UserPreferenceField(
                label: "danser arguments",
                keyName: "danserArguments",
              ),
            ),
            Text("Upload Progress:"),
            Expanded(
              child: LinearProgressIndicator(value: 0),
            ),
            OutlinedButton(
              onPressed: () async {},
              child: Text("Render Latest Replay"),
            ),
          ],
        ),
        DefaultTabController(
          length: 2,
          child: Column(
            children: [
              const TabBar(
                tabs: [
                  Tab(text: "Log"),
                  Tab(text: "danser Log"),
                ],
              ),
              SizedBox(
                height: 200,
                child: TabBarView(
                  children: [
                    // TODO remove if log moved to dialog
                    SelectableText(appState.log),
                    TextField(readOnly: true),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  final danserBinaryTextFieldController = TextEditingController();
  final danserSettingsTextFieldController = TextEditingController();
  final osuDirectoryTextFieldController = TextEditingController();

  var deleteRenderedVideo = false;
  var showDanserTerminal = false;

  @override
  void initState() {
    super.initState();

    _loadCheckboxUserPreferences();
  }

  void _loadCheckboxUserPreferences() async {
    final prefs = await SharedPreferences.getInstance();

    setState(() {
      deleteRenderedVideo = prefs.getBool("deleteRenderedVideo") ?? false;
      showDanserTerminal = prefs.getBool("showDanserTerminal") ?? false;
    });
  }

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<AppState>();

    return ListView(
      children: [
        SpacedRow(
          children: [
            Expanded(
              child: UserPreferenceField(
                label: "Discord Webhook URL",
                keyName: "discordWebhookUrl",
              ),
            ),
          ],
        ),
        SpacedRow(
          children: [
            Expanded(
              child: UserPreferenceField(
                label: "danser binary",
                keyName: "danserBinaryPath",
                controller: danserBinaryTextFieldController,
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  lockParentWindow: true,
                );
                if (result != null) {
                  danserBinaryTextFieldController.text =
                      result.files.single.path!;
                }
              },
              child: Text("Select File"),
            ),
            OpenDanserGuiButton(appState: appState),
            OutlinedButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                final danserBinaryPath =
                    prefs.getString("danserBinaryPath") ?? "";

                var pathComponents = p.split(danserBinaryPath);
                pathComponents.removeLast();

                final danserFolderPath = p.joinAll(pathComponents);

                try {
                  await Process.run("explorer", [danserFolderPath]);
                } catch (e) {
                  if (!context.mounted) return;
                  showErrorDialog(
                    context,
                    "Error",
                    "Invalid danser binary path",
                  );
                }
              },
              child: Text("Open danser folder"),
            ),
          ],
        ),
        SpacedRow(
          children: [
            Expanded(
              child: UserPreferenceField(
                label: "danser settings",
                keyName: "danserSettingsPath",
                controller: danserSettingsTextFieldController,
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                FilePickerResult? result = await FilePicker.platform.pickFiles(
                  type: FileType.custom,
                  allowedExtensions: ["json"],
                  lockParentWindow: true,
                );
                if (result != null) {
                  danserSettingsTextFieldController.text =
                      result.files.single.path!;
                }
              },
              child: Text("Select File"),
            ),
          ],
        ),
        SpacedRow(
          children: [
            Expanded(
              child: UserPreferenceField(
                label: "osu! directory",
                keyName: "osuDirectoryPath",
                controller: osuDirectoryTextFieldController,
              ),
            ),
            OutlinedButton(
              onPressed: () async {
                String? selectedDirectory = await FilePicker.platform
                    .getDirectoryPath();
                if (selectedDirectory != null) {
                  osuDirectoryTextFieldController.text = selectedDirectory;
                }
              },
              child: Text("Select Directory"),
            ),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: deleteRenderedVideo,
              onChanged: (checked) async {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();

                await prefs.setBool("deleteRenderedVideo", checked ?? false);
                setState(() {
                  deleteRenderedVideo = checked!;
                });
              },
            ),
            Text("Delete rendered video?"),
          ],
        ),
        Row(
          children: [
            Checkbox(
              value: showDanserTerminal,
              onChanged: (checked) async {
                final SharedPreferences prefs =
                    await SharedPreferences.getInstance();

                await prefs.setBool("showDanserTerminal", checked ?? false);
                setState(() {
                  showDanserTerminal = checked!;
                });
              },
            ),
            Text("Show danser terminal?"),
          ],
        ),
      ],
    );
  }
}

class OpenDanserGuiButton extends StatelessWidget {
  const OpenDanserGuiButton({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () async {
        final prefs = await SharedPreferences.getInstance();
        final danserBinaryPath = prefs.getString("danserBinaryPath");

        if (danserBinaryPath != null) {
          try {
            // TODO currently opens GUI without terminal
            await Process.run(
              danserBinaryPath.replaceAll("danser-cli", "danser"),
              [],
            );
          }
          // TODO need to differentiate between different error types?
          // on ProcessException {
          // }
          catch (e) {
            if (!context.mounted) return;
            showErrorDialog(context, "Error", "Invalid danser binary path");
          }
        } else {
          if (!context.mounted) return;
          showErrorDialog(context, "Error", "Invalid danser binary path");
        }
      },
      child: Text("Open danser GUI"),
    );
  }
}

Future<String?> showProgressDialog(
  BuildContext context,
  String title,
  String description,
) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: <Widget>[CancelButton()],
    ),
    barrierDismissible: false,
  );
}

class CancelButton extends StatelessWidget {
  const CancelButton({super.key});

  @override
  Widget build(BuildContext context) {
    var appState = context.watch<AppState>();

    return TextButton(
      onPressed: appState.isRenderingOrUploading
          ? null
          : () => Navigator.pop(context, "OK"),
      child: const Text("OK"),
    );
  }
}

Future<String?> showErrorDialog(
  BuildContext context,
  String title,
  String description,
) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(description),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context, "OK"),
          child: const Text("OK"),
        ),
      ],
    ),
  );
}

Future<int> _renderVideo(
  String danserBinaryPath,
  String replayFilePath,
  List<String> danserArguments,
  String outputFileName,
  BuildContext context,
) async {
  const Utf8Codec utf8 = Utf8Codec();
  try {
    // var appState = Provider.of<AppState>(context, listen: false);
    final process = await Process.start(danserBinaryPath, [
      "-replay",
      replayFilePath,
      ...danserArguments,
      "-out",
      outputFileName,
    ]);

    process.stdout.transform(utf8.decoder).listen((data) {
      print('STDOUT: $data');
      // if (data.contains("Progress:")) {
      //   // TODO get progress percentage, call appState.updateRenderProgress
      // }
    });

    process.stderr.transform(utf8.decoder).listen((data) {
      print('STDERR: $data');
    });

    return await process.exitCode;
  } catch (e) {
    print(e);
    return -1;
  }
}

// TODO implement
// Future<int> _uploadToDiscordWebhook(String discordWebhookUrl) {

// }
