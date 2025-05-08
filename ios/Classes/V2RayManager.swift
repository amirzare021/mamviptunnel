import Foundation

enum V2RayError: Error {
    case binaryNotFound
    case configNotFound
    case processStartFailed
    case fileOperationFailed(String)
}

class V2RayManager {
    private var process: Process?
    private let fileManager = FileManager.default
    
    /// Get the application support directory
    private func getAppSupportDirectory() throws -> URL {
        guard let supportDir = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw V2RayError.fileOperationFailed("Could not find application support directory")
        }
        
        let v2rayDir = supportDir.appendingPathComponent("v2ray", isDirectory: true)
        
        if !fileManager.fileExists(atPath: v2rayDir.path) {
            try fileManager.createDirectory(at: v2rayDir, withIntermediateDirectories: true)
        }
        
        return v2rayDir
    }
    
    /// Extract V2Ray binary from the bundle to app support directory
    func extractV2RayBinary() throws {
        let v2rayDir = try getAppSupportDirectory()
        let binaryDestination = v2rayDir.appendingPathComponent("v2ray")
        
        // Check if binary already exists
        if fileManager.fileExists(atPath: binaryDestination.path) {
            print("V2Ray binary already exists at \(binaryDestination.path)")
            return
        }
        
        // Get binary from bundle
        guard let bundle = Bundle(for: V2RayManager.self),
              let binaryPath = bundle.path(forResource: "v2ray", ofType: nil, inDirectory: "v2ray") else {
            throw V2RayError.binaryNotFound
        }
        
        let binaryUrl = URL(fileURLWithPath: binaryPath)
        
        // Copy binary to destination
        try fileManager.copyItem(at: binaryUrl, to: binaryDestination)
        
        // Set executable permissions
        try fileManager.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binaryDestination.path)
        
        print("V2Ray binary extracted to \(binaryDestination.path)")
    }
    
    /// Save V2Ray configuration to file
    func saveConfig(config: String) throws {
        let v2rayDir = try getAppSupportDirectory()
        let configPath = v2rayDir.appendingPathComponent("config.json")
        
        guard let data = config.data(using: .utf8) else {
            throw V2RayError.fileOperationFailed("Failed to convert config to data")
        }
        
        try data.write(to: configPath)
        print("Config saved to \(configPath.path)")
    }
    
    /// Start V2Ray process
    func start() throws {
        if isRunning() {
            print("V2Ray is already running")
            return
        }
        
        let v2rayDir = try getAppSupportDirectory()
        let binaryPath = v2rayDir.appendingPathComponent("v2ray").path
        let configPath = v2rayDir.appendingPathComponent("config.json").path
        
        // Check if binary exists
        if !fileManager.fileExists(atPath: binaryPath) {
            throw V2RayError.binaryNotFound
        }
        
        // Check if config exists
        if !fileManager.fileExists(atPath: configPath) {
            throw V2RayError.configNotFound
        }
        
        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["-config", configPath]
        
        // Redirect output to pipe for logging
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        // Set up output handling
        outputPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("V2Ray output: \(output)")
            }
        }
        
        errorPipe.fileHandleForReading.readabilityHandler = { fileHandle in
            let data = fileHandle.availableData
            if let output = String(data: data, encoding: .utf8), !output.isEmpty {
                print("V2Ray error: \(output)")
            }
        }
        
        // Start process
        do {
            try process.run()
            self.process = process
            print("V2Ray process started")
        } catch {
            throw V2RayError.processStartFailed
        }
    }
    
    /// Stop V2Ray process
    func stop() throws {
        guard let process = self.process else {
            print("No V2Ray process is running")
            return
        }
        
        if process.isRunning {
            process.terminate()
            print("V2Ray process terminated")
        }
        
        self.process = nil
    }
    
    /// Check if V2Ray is running
    func isRunning() -> Bool {
        guard let process = self.process else {
            return false
        }
        
        return process.isRunning
    }
}
