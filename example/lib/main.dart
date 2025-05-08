import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter V2Ray Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const V2RayConnectionPage(),
    );
  }
}

class V2RayConnectionPage extends StatefulWidget {
  const V2RayConnectionPage({Key? key}) : super(key: key);

  @override
  State<V2RayConnectionPage> createState() => _V2RayConnectionPageState();
}

class _V2RayConnectionPageState extends State<V2RayConnectionPage> {
  final _formKey = GlobalKey<FormState>();
  final _urlController = TextEditingController();
  bool _isConnected = false;
  bool _isLoading = false;
  String _statusMessage = 'Disconnected';

  @override
  void initState() {
    super.initState();
    _initializeV2Ray();
  }

  Future<void> _initializeV2Ray() async {
    try {
      await FlutterV2ray.initialize();
      _checkConnectionStatus();
    } catch (e) {
      setState(() {
        _statusMessage = 'Initialization failed: $e';
      });
    }
  }

  Future<void> _checkConnectionStatus() async {
    final isConnected = await FlutterV2ray.isConnected();
    setState(() {
      _isConnected = isConnected;
      _statusMessage = isConnected ? 'Connected' : 'Disconnected';
    });
  }

  Future<void> _connect() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
        _statusMessage = 'Connecting...';
      });

      try {
        final vlessUrl = _urlController.text.trim();
        await FlutterV2ray.connect(vlessUrl);
        await FlutterV2ray.start();
        
        setState(() {
          _isConnected = true;
          _statusMessage = 'Connected';
        });
      } catch (e) {
        setState(() {
          _statusMessage = 'Connection failed: $e';
        });
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _disconnect() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Disconnecting...';
    });

    try {
      await FlutterV2ray.stop();
      setState(() {
        _isConnected = false;
        _statusMessage = 'Disconnected';
      });
    } catch (e) {
      setState(() {
        _statusMessage = 'Disconnection failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('V2Ray VLESS Connection'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'VLESS URL',
                  hintText: 'vless://uuid@host:port?type=tcp&security=tls#remark',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a VLESS URL';
                  }
                  if (!value.startsWith('vless://')) {
                    return 'Invalid VLESS URL format';
                  }
                  return null;
                },
                enabled: !_isConnected && !_isLoading,
              ),
              const SizedBox(height: 16),
              _buildStatusIndicator(),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                _isConnected
                    ? ElevatedButton(
                        onPressed: _disconnect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Disconnect'),
                      )
                    : ElevatedButton(
                        onPressed: _connect,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: const Text('Connect'),
                      ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              const Text(
                'VLESS URL Format:',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 8),
              const Text(
                'vless://<UUID>@<host>:<port>?type=tcp&security=tls&sni=example.com#remark',
                style: TextStyle(fontFamily: 'monospace'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Common parameters:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              _buildParameterList(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _isConnected ? Colors.green.shade100 : Colors.red.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _isConnected ? Colors.green : Colors.red,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isConnected ? Icons.check_circle : Icons.cancel,
            color: _isConnected ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Text(
            'Status: $_statusMessage',
            style: TextStyle(
              color: _isConnected ? Colors.green.shade900 : Colors.red.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParameterList() {
    final parameters = [
      {'name': 'type', 'description': 'tcp, ws, grpc, etc.'},
      {'name': 'security', 'description': 'tls, none'},
      {'name': 'flow', 'description': 'xtls-rprx-vision, etc.'},
      {'name': 'sni', 'description': 'Server Name Indication'},
      {'name': 'path', 'description': 'WebSocket path'},
      {'name': 'host', 'description': 'WebSocket host header'},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: parameters
          .map(
            (param) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                '• ${param['name']}: ${param['description']}',
                style: const TextStyle(fontSize: 14),
              ),
            ),
          )
          .toList(),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }
}
