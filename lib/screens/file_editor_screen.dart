import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/azure_storage_service.dart';
import 'file_list_screen.dart';
import 'package:csv/csv.dart';

class FileEditorScreen extends StatefulWidget {
  final String fileName;
  const FileEditorScreen({super.key, required this.fileName});

  @override
  State<FileEditorScreen> createState() => _FileEditorScreenState();
}

class _FileEditorScreenState extends State<FileEditorScreen> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasEdits = false;
  String _error = '';
  List<List<String>> _csvData = [];
  List<List<String>> _originalCsvData = [];
  final Map<String, TextEditingController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCsvData();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  TextEditingController _getController(int rowIndex, int colIndex) {
    final key = '$rowIndex:$colIndex';
    if (!_controllers.containsKey(key)) {
      final value = rowIndex < _csvData.length && colIndex < _csvData[rowIndex].length
          ? _csvData[rowIndex][colIndex]
          : '';
      _controllers[key] = TextEditingController(text: value);
    }
    return _controllers[key]!;
  }

  FocusNode _getFocusNode(int rowIndex, int colIndex) {
    final key = '$rowIndex:$colIndex';
    if (!_focusNodes.containsKey(key)) {
      _focusNodes[key] = FocusNode();
    }
    return _focusNodes[key]!;
  }

  Future<void> _loadCsvData() async {
    setState(() {
      _isLoading = true;
      _error = '';
      _hasEdits = false;
    });
    try {
      final azureStorageService = AuthService.instance.storageService;
      final content = await azureStorageService.getFileContent(widget.fileName);
      _parseCsvContent(content);
    } catch (e) {
      setState(() {
        _error = '加载数据失败: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseCsvContent(String csvContent) {
    final List<List<dynamic>> rows = const CsvToListConverter(
      fieldDelimiter: ',',
      textDelimiter: '"',
      eol: '\n',
      shouldParseNumbers: false,
    ).convert(csvContent);
    _csvData = rows.map((row) => row.map((cell) => cell.toString()).toList()).toList();
    _originalCsvData = List<List<String>>.from(
      _csvData.map((row) => List<String>.from(row))
    );
    _clearUnusedControllers();
    _updateAllControllers();
  }

  void _clearUnusedControllers() {
    final validKeys = <String>{};
    for (int i = 0; i < _csvData.length; i++) {
      for (int j = 0; j < _csvData[i].length; j++) {
        validKeys.add('$i:$j');
      }
    }
    final keysToRemove = _controllers.keys.where((key) => !validKeys.contains(key)).toList();
    for (final key in keysToRemove) {
      _controllers[key]?.dispose();
      _controllers.remove(key);
    }
    final focusKeysToRemove = _focusNodes.keys.where((key) => !validKeys.contains(key)).toList();
    for (final key in focusKeysToRemove) {
      _focusNodes[key]?.dispose();
      _focusNodes.remove(key);
    }
  }

  void _updateAllControllers() {
    for (int i = 0; i < _csvData.length; i++) {
      for (int j = 0; j < _csvData[i].length; j++) {
        final key = '$i:$j';
        final controller = _controllers[key];
        if (controller != null) {
          final selection = controller.selection;
          controller.text = _csvData[i][j];
          controller.selection = selection;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fileName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const FileListScreen()),
          ),
        ),
        actions: [
          if (_hasEdits && !_isLoading && !_isSaving)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _saveChanges,
              tooltip: '保存更改',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading || _isSaving ? null : _loadCsvData,
            tooltip: '刷新数据',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _isSaving
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('正在保存更改...'),
                    ],
                  ),
                )
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text(_error, textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: _loadCsvData,
                              child: const Text('重试'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                )
              : _buildVirtualTable(),
    );
  }

  Widget _buildVirtualTable() {
    if (_csvData.isEmpty) {
      return const Center(child: Text('没有数据'));
    }
    final headers = _csvData[0];
    final rowCount = _csvData.length - 1;
    final double cellWidth = 160;
    final double tableWidth = (headers.length * cellWidth).clamp(300.0, double.infinity);
    return Scrollbar(
      controller: _horizontalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _horizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: tableWidth,
          child: Column(
            children: [
              // 表头
              Container(
                color: Theme.of(context).colorScheme.surfaceVariant,
                child: Row(
                  children: List.generate(headers.length, (colIndex) {
                    return Container(
                      width: cellWidth,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                      alignment: Alignment.centerLeft,
                      child: Text(
                        headers[colIndex],
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    );
                  }),
                ),
              ),
              // 内容区
              Expanded(
                child: Scrollbar(
                  controller: _verticalController,
                  thumbVisibility: true,
                  child: ListView.builder(
                    controller: _verticalController,
                    itemCount: rowCount,
                    itemBuilder: (context, rowIndex) {
                      final row = _csvData[rowIndex + 1];
                      return Row(
                        children: List.generate(headers.length, (colIndex) {
                          final controller = _getController(rowIndex + 1, colIndex);
                          final focusNode = _getFocusNode(rowIndex + 1, colIndex);
                          return Container(
                            width: cellWidth,
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                            alignment: Alignment.centerLeft,
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.zero,
                              ),
                              style: const TextStyle(fontSize: 14),
                              onChanged: (newValue) {
                                _csvData[rowIndex + 1][colIndex] = newValue;
                                Future.microtask(() {
                                  _checkForChanges();
                                });
                              },
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _checkForChanges() {
    bool hasChanges = false;
    if (_csvData.length != _originalCsvData.length) {
      hasChanges = true;
    } else {
      for (int i = 1; i < _csvData.length; i++) {
        if (i >= _originalCsvData.length) {
          hasChanges = true;
          break;
        }
        final row = _csvData[i];
        final originalRow = _originalCsvData[i];
        if (row.length != originalRow.length) {
          hasChanges = true;
          break;
        }
        for (int j = 0; j < row.length; j++) {
          if (row[j] != originalRow[j]) {
            hasChanges = true;
            break;
          }
        }
        if (hasChanges) break;
      }
    }
    if (hasChanges != _hasEdits) {
      setState(() {
        _hasEdits = hasChanges;
      });
    }
  }

  Future<void> _saveChanges() async {
    if (!_hasEdits) return;
    setState(() {
      _isSaving = true;
      _error = '';
    });
    try {
      final quotedData = _csvData.map((row) =>
        row.map((cell) {
          final escaped = cell.replaceAll('"', '""');
          return '"$escaped"';
        }).toList()
      ).toList();
      final String csvContent = const ListToCsvConverter(
        fieldDelimiter: ',',
        textDelimiter: '',
        eol: '\n',
      ).convert(quotedData);
      final content = '\uFEFF' + csvContent;
      final azureStorageService = AuthService.instance.storageService;
      await azureStorageService.uploadFile(widget.fileName, utf8.encode(content));
      _originalCsvData = List<List<String>>.from(
        _csvData.map((row) => List<String>.from(row))
      );
      setState(() {
        _hasEdits = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已成功保存更改')),
      );
    } catch (e) {
      setState(() {
        _error = '保存失败: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('保存失败: $e')),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
} 