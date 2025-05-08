import 'dart:convert';

/// Class to handle V2Ray configuration generation from VLESS URLs
class V2RayConfig {
  final Map<String, dynamic> _config;

  V2RayConfig._(this._config);

  /// Create a V2Ray configuration from a VLESS URL
  factory V2RayConfig.fromVlessUrl(String vlessLink) {
    if (!vlessLink.startsWith('vless://')) {
      throw FormatException('Invalid VLESS URL format. URL must start with "vless://"');
    }

    final uri = Uri.parse(vlessLink);
    final params = uri.queryParameters;

    // Validate essential components
    if (uri.host.isEmpty) {
      throw FormatException('Invalid VLESS URL: missing host');
    }

    if (uri.userInfo.isEmpty) {
      throw FormatException('Invalid VLESS URL: missing user ID (UUID)');
    }

    // Set default port if not specified
    final port = uri.port != 0 ? uri.port : 443;

    // Create inbounds configuration
    final inbounds = [
      {
        "port": 10808,
        "listen": "127.0.0.1",
        "protocol": "socks",
        "settings": {
          "udp": true
        }
      }
    ];

    // Create outbounds configuration
    final outbounds = [
      {
        "protocol": "vless",
        "settings": {
          "vnext": [
            {
              "address": uri.host,
              "port": port,
              "users": [
                {
                  "id": uri.userInfo,
                  "encryption": "none",
                  "flow": params['flow'] ?? ''
                }
              ]
            }
          ]
        },
        "streamSettings": _buildStreamSettings(uri, params),
        "tag": "proxy"
      },
      {
        "protocol": "freedom",
        "settings": {},
        "tag": "direct"
      },
      {
        "protocol": "blackhole",
        "settings": {},
        "tag": "block"
      }
    ];

    final routing = {
      "domainStrategy": "IPIfNonMatch",
      "rules": [
        {
          "type": "field",
          "ip": ["geoip:private"],
          "outboundTag": "direct"
        }
      ]
    };

    final config = {
      "inbounds": inbounds,
      "outbounds": outbounds,
      "routing": routing
    };

    return V2RayConfig._(config);
  }

  /// Build stream settings based on connection parameters
  static Map<String, dynamic> _buildStreamSettings(Uri uri, Map<String, String> params) {
    final network = params['type'] ?? 'tcp';
    final security = params['security'] ?? 'tls';
    
    final streamSettings = {
      "network": network,
      "security": security,
    };

    // Add TLS settings if security is tls or xtls
    if (security == 'tls' || security == 'xtls') {
      streamSettings["tlsSettings"] = {
        "serverName": params['sni'] ?? uri.host,
        "allowInsecure": params['allowInsecure'] == 'true',
      };
    }

    // Add network specific settings
    switch (network) {
      case 'ws':
        streamSettings["wsSettings"] = {
          "path": params['path'] ?? '/',
          "headers": {"Host": params['host'] ?? uri.host}
        };
        break;
      case 'grpc':
        streamSettings["grpcSettings"] = {
          "serviceName": params['serviceName'] ?? '',
          "multiMode": params['multiMode'] == 'true',
        };
        break;
      case 'tcp':
        if (params['headerType'] == 'http') {
          streamSettings["tcpSettings"] = {
            "header": {
              "type": "http",
              "request": {
                "path": [params['path'] ?? '/'],
                "headers": {"Host": params['host'] ?? uri.host}
              }
            }
          };
        }
        break;
      case 'kcp':
        streamSettings["kcpSettings"] = {
          "header": {"type": params['headerType'] ?? 'none'},
          "seed": params['seed'] ?? '',
        };
        break;
      case 'quic':
        streamSettings["quicSettings"] = {
          "security": params['quicSecurity'] ?? 'none',
          "key": params['key'] ?? '',
          "header": {"type": params['headerType'] ?? 'none'},
        };
        break;
      case 'http':
        streamSettings["httpSettings"] = {
          "path": params['path'] ?? '/',
          "host": [params['host'] ?? uri.host],
        };
        break;
    }

    return streamSettings;
  }

  /// Convert the configuration to a JSON-serializable map
  Map<String, dynamic> toJson() {
    return _config;
  }

  @override
  String toString() {
    return jsonEncode(_config);
  }
}
