import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

class AzureStorageService {
  final String sasUrl;
  final String containerName;

  AzureStorageService({
    required this.sasUrl,
    required this.containerName,
  });

  String _buildUrl(String path, {Map<String, String>? queryParams}) {
    // 从 sasUrl 中分离基础 URL 和 SAS 令牌
    final uri = Uri.parse(sasUrl);
    // 获取存储账户的基本 URL
    final baseUrl = '${uri.scheme}://${uri.host}';
    
    // 构建新的查询参数
    final Map<String, String> allParams = {};
    if (queryParams != null) {
      allParams.addAll(queryParams);
    }
    // 添加 SAS 令牌的各个参数
    uri.queryParameters.forEach((key, value) {
      allParams[key] = value;
    });

    // 构建完整路径
    String fullPath = '';
    if (path.isEmpty) {
      fullPath = '/$containerName'; // 用于容器操作
    } else if (path.startsWith('/')) {
      fullPath = '/$containerName$path'; // 用于 blob 操作
    } else {
      fullPath = '/$containerName/$path'; // 用于 blob 操作
    }

    // 构建最终的 URL
    final finalUri = Uri.parse(baseUrl + fullPath).replace(queryParameters: allParams);
    print('Built URL: $finalUri'); // 调试信息
    return finalUri.toString();
  }

  Future<List<Map<String, dynamic>>> listFiles() async {
    try {
      final url = _buildUrl('', queryParams: {
        'restype': 'container',
        'comp': 'list',
      });

      print('List Files Request:');
      print('URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/xml',
          'x-ms-version': '2020-04-08',
        },
      );

      print('Response Status: ${response.statusCode}');
      if (response.statusCode != 200) {
        print('Error Response Headers: ${response.headers}');
        print('Error Response Body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final files = <Map<String, dynamic>>[];
        final responseText = response.body;
        
        // XML parsing
        final blobPattern = RegExp(r'<Blob>.*?<Name>([^<]+)</Name>.*?</Blob>', dotAll: true);
        final matches = blobPattern.allMatches(responseText);
        
        for (final match in matches) {
          if (match.group(1) != null) {
            final fileName = match.group(1)!;
            files.add({
              'name': fileName,
              'url': _buildUrl('/$fileName'),
            });
          }
        }
        
        return files;
      } else {
        throw Exception('Failed to load files: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception in listFiles: ${e.toString()}');
      throw Exception('Failed to list files: ${e.toString()}');
    }
  }

  Future<String> getFileContent(String fileName) async {
    try {
      final url = _buildUrl('/$fileName');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/octet-stream',
          'x-ms-version': '2020-04-08',
        },
      );

      if (response.statusCode == 200) {
        return utf8.decode(response.bodyBytes);
      } else {
        print('Error getting file content:');
        print('Status Code: ${response.statusCode}');
        print('Headers: ${response.headers}');
        print('Body: ${response.body}');
        throw Exception('Failed to load file content: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception in getFileContent: ${e.toString()}');
      throw Exception('Failed to get file content: ${e.toString()}');
    }
  }

  Future<void> uploadFile(String fileName, List<int> content) async {
    try {
      final url = _buildUrl('/$fileName');

      final response = await http.put(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/octet-stream',
          'x-ms-blob-type': 'BlockBlob',
          'Content-Length': content.length.toString(),
          'x-ms-version': '2020-04-08',
        },
        body: content,
      );

      if (response.statusCode != 201) {
        print('Error uploading file:');
        print('Status Code: ${response.statusCode}');
        print('Headers: ${response.headers}');
        print('Body: ${response.body}');
        throw Exception('Failed to upload file: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Exception in uploadFile: ${e.toString()}');
      throw Exception('Failed to upload file: ${e.toString()}');
    }
  }
} 