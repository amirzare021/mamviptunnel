import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_v2ray/src/v2ray_config.dart';

/// Main plugin class for V2Ray connection management
class FlutterV2ray {
  static const MethodChannel _channel = MethodChannel('flutter_v2ray');
  static bool _isInitialized = false;

  /// Initialize the plugin
  static Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await _channel.invokeMethod('initialize');
      _isInitialized = true;
    } catch (e) {
      throw Exception('Failed to initialize V2Ray plugin: $e');
    }
  }

  /// Connect to a V2Ray server using a VLESS URL
  static Future<bool> connect(String vlessUrl) async {
    if (!_isInitialized) {
      await initialize();
    }

    try {
      // Parse the VLESS URL and generate the config
      final configJson = convertVlessToJson(vlessUrl);
      
      // Send the config to the native side
      final result = await _channel.invokeMethod('connect', {
        'config': configJson,
      });
      
      return result ?? false;
    } catch (e) {
      throw Exception('Failed to connect to V2Ray server: $e');
    }
  }

  /// Start the V2Ray service with the current configuration
  static Future<bool> start() async {
    if (!_isInitialized) {
      throw Exception('V2Ray plugin not initialized. Call initialize() first.');
    }

    try {
      final result = await _channel.invokeMethod('start');
      return result ?? false;
    } catch (e) {
      throw Exception('Failed to start V2Ray service: $e');
    }
  }

  /// Stop the V2Ray service
  static Future<bool> stop() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('stop');
      return result ?? false;
    } catch (e) {
      throw Exception('Failed to stop V2Ray service: $e');
    }
  }

  /// Check if V2Ray service is connected
  static Future<bool> isConnected() async {
    if (!_isInitialized) {
      return false;
    }

    try {
      final result = await _channel.invokeMethod('isConnected');
      return result ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Convert a VLESS URL to a V2Ray JSON configuration
  static String convertVlessToJson(String vlessLink) {
    final config = V2RayConfig.fromVlessUrl(vlessLink);
    return jsonEncode(config.toJson());
  }
}
