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
              : Column(
                  children: [
                    Expanded(
                      child: _csvData.isEmpty
                          ? const Center(child: Text('没有数据'))
                          : Scrollbar(
                              thumbVisibility: true,
                              child: InteractiveViewer(
                                constrained: false,
                                minScale: 1,
                                maxScale: 2,
                                child: DataTable(
                                  columns: _buildColumns(),
                                  rows: _buildRows(),
                                  dividerThickness: 1,
                                  horizontalMargin: 12,
                                  columnSpacing: 12,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),
    );
  }

  List<DataColumn> _buildColumns() {
    if (_csvData.isEmpty) return [];
    return _csvData[0].map((header) => DataColumn(
      label: Text(
        header,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
    )).toList();
  }

  List<DataRow> _buildRows() {
    if (_csvData.length <= 1) return [];
    final rows = <DataRow>[];
    for (int rowIndex = 1; rowIndex < _csvData.length; rowIndex++) {
      final row = _csvData[rowIndex];
      while (row.length < _csvData[0].length) {
        row.add('');
      }
      if (row.length > _csvData[0].length) {
        row.length = _csvData[0].length;
      }
      rows.add(DataRow(
        cells: List.generate(row.length, (colIndex) {
          final controller = _getController(rowIndex, colIndex);
          final focusNode = _getFocusNode(rowIndex, colIndex);
          return DataCell(
            TextField(
              controller: controller,
              focusNode: focusNode,
              decoration: const InputDecoration(
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
              ),
              style: const TextStyle(fontSize: 14),
              onChanged: (newValue) {
                _csvData[rowIndex][colIndex] = newValue;
                Future.microtask(() {
                  _checkForChanges();
                });
              },
            ),
          );
        }),
      ));
    }
    return rows;
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