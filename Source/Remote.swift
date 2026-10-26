import Foundation
import AppKit
import SwiftUI
import Security
import CryptoKit
import LocalAuthentication

func localHost(_ host: String) -> Bool {
    let labels = host.split(separator: ".", omittingEmptySubsequences: false)
    let parts = labels.compactMap { label in label.allSatisfy({ $0.isASCII && $0.isNumber }) ? Int(label) : nil }
    if labels.count == 4, parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) {
        return parts[0] == 10 || (parts[0] == 192 && parts[1] == 168) || (parts[0] == 172 && (16...31).contains(parts[1])) || (parts[0] == 169 && parts[1] == 254)
    }
    return host.range(of: "^[a-zA-Z0-9-]+\\.(local|lan)$", options: .regularExpression) != nil
}
enum Vault {
    // Ad-hoc rebuilds have distinct code identities. Keep credentials scoped to that
    // identity so a replacement executable cannot trigger a legacy Keychain dialog.
    static let service: String = {
        var code: SecCode?; var staticCode: SecStaticCode?; var information: CFDictionary?
        if SecCodeCopySelf([], &code) == errSecSuccess, let code,
           SecCodeCopyStaticCode(code, [], &staticCode) == errSecSuccess, let staticCode,
           SecCodeCopySigningInformation(staticCode, SecCSFlags(rawValue:kSecCSSigningInformation), &information) == errSecSuccess,
           let values = information as? [String:Any], let unique = values[kSecCodeInfoUnique as String] as? Data {
            return "local.M8Studio.remote." + unique.map { String(format:"%02x",$0) }.joined()
        }
        return "local.M8Studio.remote.v2"
    }()
    private static func query(_ host:String) -> [String:Any] {
        let context = LAContext(); context.interactionNotAllowed = true
        return [kSecClass as String:kSecClassGenericPassword,kSecAttrService as String:service,kSecAttrAccount as String:host,kSecUseAuthenticationContext as String:context]
    }
    private final class ReadResult: @unchecked Sendable {
        let lock = NSLock(); var continuation: CheckedContinuation<String?,Never>?
        init(_ continuation: CheckedContinuation<String?,Never>) { self.continuation = continuation }
        func finish(_ value:String?) { lock.lock(); let pending = continuation; continuation = nil; lock.unlock(); pending?.resume(returning:value) }
    }
    static func readWithoutBlocking(_ host:String) async -> String? {
        guard UserDefaults.standard.bool(forKey:"saved.\(service).\(host)") else { return nil }
        return await withCheckedContinuation { continuation in
            let result = ReadResult(continuation)
            DispatchQueue.global(qos:.utility).async { result.finish(read(host)) }
            DispatchQueue.global(qos:.utility).asyncAfter(deadline:.now()+1) { result.finish(nil) }
        }
    }
    static func read(_ host:String) -> String? {
        var q = query(host); q[kSecReturnData as String] = true; q[kSecMatchLimit as String] = kSecMatchLimitOne
        var value:CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary,&value) == errSecSuccess, let data = value as? Data else { return nil }
        return String(data:data,encoding:.utf8)
    }
    @discardableResult static func save(_ token:String,_ host:String) -> Bool {
        let q = query(host); let attributes:[String:Any] = [kSecValueData as String:Data(token.utf8)]
        if SecItemUpdate(q as CFDictionary,attributes as CFDictionary) == errSecSuccess { UserDefaults.standard.set(true,forKey:"saved.\(service).\(host)"); return true }
        let saved = SecItemAdd(q.merging(attributes) { _,new in new } as CFDictionary,nil) == errSecSuccess
        if saved { UserDefaults.standard.set(true,forKey:"saved.\(service).\(host)") }; return saved
    }
    @discardableResult static func remove(_ host:String) -> Bool {
        let result = SecItemDelete(query(host) as CFDictionary); return result == errSecSuccess || result == errSecItemNotFound
    }
}
final class MonitorTrust: NSObject, URLSessionDelegate {
    let host: String
    init(_ host: String) { self.host = host }
    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else { completionHandler(.performDefaultHandling, nil); return }
        guard challenge.protectionSpace.host == host, localHost(host), let trust = challenge.protectionSpace.serverTrust,
              let cert = (SecTrustCopyCertificateChain(trust) as? [SecCertificate])?.first else { completionHandler(.cancelAuthenticationChallenge, nil); return }
        let hash = SHA256.hash(data: SecCertificateCopyData(cert) as Data).map { String(format: "%02x", $0) }.joined()
        let key = "certificate.\(host)"
        if let pinned = UserDefaults.standard.string(forKey: key), pinned != hash { completionHandler(.cancelAuthenticationChallenge, nil); return }
        UserDefaults.standard.set(hash, forKey: key)
        completionHandler(.useCredential, URLCredential(trust: trust))
    }
}
@MainActor final class SamsungRemote: ObservableObject {
    @Published var host: String = UserDefaults.standard.string(forKey: "monitorHost") ?? "samsung.lan"
    @Published var status = "Not connected"
    @Published var model = ""
    @Published var connected = false
    @Published var busy = false
    @Published var candidates: [String] = []
    @Published var macAddress = ""
    @Published var volume: Double?
    @Published var muted = false
    @Published var mediaStatus = "Connect to read monitor volume."
    @Published var changingVolume = false
    @Published var changingMute = false
    private var verifiedHost:String?
    var mediaAvailable:Bool { verifiedHost == host && volume != nil }
    private var mediaTask: Task<Void, Never>?
    private var pingTask: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var generation = UUID()
    private var wantsConnection = false
    private var wantsRemoteControl = true
    private var screenSleeping = false
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var wakeObserver: NSObjectProtocol?
    init() {
        macAddress = UserDefaults.standard.string(forKey: "mac.\(host)") ?? ""
        let center = NSWorkspace.shared.notificationCenter
        lifecycleObservers.append(center.addObserver(forName:NSWorkspace.willSleepNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.suspendForSleep() } })
        lifecycleObservers.append(center.addObserver(forName:NSWorkspace.screensDidSleepNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in self?.screenSleeping = true } })
        lifecycleObservers.append(center.addObserver(forName:NSWorkspace.screensDidWakeNotification,object:nil,queue:.main) { [weak self] _ in Task { @MainActor in guard let self else { return }; self.screenSleeping = false; await self.refreshMedia() } })
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                guard let self, self.wantsConnection else { return }
                try? await Task.sleep(for: .seconds(3))
                if self.wantsConnection { self.connect(remoteControl:self.wantsRemoteControl) }
            }
        }
    }
    private var connectTimeout: Task<Void, Never>?
    let allowedKeys: Set<String> = ["KEY_UP","KEY_DOWN","KEY_LEFT","KEY_RIGHT","KEY_ENTER","KEY_RETURN","KEY_HOME","KEY_MENU","KEY_SOURCE","KEY_VOLUP","KEY_VOLDOWN","KEY_MUTE","KEY_PLAY","KEY_PAUSE","KEY_INFO","KEY_PICTURE_SIZE","KEY_TOOLS", "KEY_POWEROFF"]
    func discover() {
        guard !busy else { return }; busy = true; status = "Looking for Samsung monitors…"
        Task {
            let found = await Task.detached { () -> [String] in
                let (_, arp) = runTool("/usr/sbin/arp", ["-a"], timeout: 3)
                let ips = arp.components(separatedBy: "\n").compactMap { line -> String? in
                    guard let a = line.firstIndex(of: "("), let b = line.firstIndex(of: ")") else { return nil }
                    let ip = String(line[line.index(after: a)..<b]); return localHost(ip) ? ip : nil
                }
                return await withTaskGroup(of: String?.self) { group in
                    for ip in Array(Set(ips + ["samsung.lan"])) {
                        group.addTask {
                            guard let url = URL(string: "http://\(ip):8001/api/v2/") else { return nil }
                            var req = URLRequest(url: url); req.timeoutInterval = 1.5
                            guard let (data, _) = try? await LocalHTTP.session.data(for: req), let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let d = json["device"] as? [String: Any], SamsungMonitorIdentity(device: d) != nil else { return nil }
                            return ip
                        }
                    }
                    var found: [String] = []; for await ip in group { if let ip { found.append(ip) } }; return Array(Set(found)).sorted()
                }
            }.value
            candidates = found; busy = false
            if found.count == 1 { host = found[0]; status = "Monitor found. Connect to pair." }
            else { status = found.isEmpty ? "No monitor found. Enter its IP from Settings → Network on the monitor." : "Choose your monitor address below." }
        }
    }
    private func suspendForSleep() {
        generation = UUID(); verifiedHost = nil; mediaTask?.cancel(); volume = nil
        changingVolume = false; changingMute = false
        stopSocket("Connection paused while your Mac sleeps.")
    }
    func disconnect() {
        wantsConnection = false
        generation = UUID(); verifiedHost = nil; mediaTask?.cancel(); pingTask?.cancel(); volume = nil; changingVolume = false; changingMute = false; mediaStatus = "Connect to read monitor volume."; connectTimeout?.cancel(); socket?.cancel(with: .goingAway, reason: nil); socket = nil; session?.invalidateAndCancel(); session = nil
        connected = false; busy = false; status = "Disconnected"
    }
    func connect(remoteControl:Bool = true) {
        #if M8_UI_PREVIEW
        return // Covers explicit actions as well as reconnect notifications.
        #endif
        let address = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard localHost(address) else { status = "Enter a private IPv4 address or a .local/.lan hostname."; return }
        disconnect(); wantsConnection = true; wantsRemoteControl = remoteControl; host = address; let stamp = generation; busy = true; status = "Checking monitor…"
        connectTimeout = Task { try? await Task.sleep(for:.seconds(45)); if !Task.isCancelled, generation == stamp, !connected { stopSocket("Connection timed out. Check the monitor and try again.") } }
        Task {
            do {
                var req = URLRequest(url: URL(string: "http://\(address):8001/api/v2/")!); req.timeoutInterval = 4
                let (data, _) = try await LocalHTTP.session.data(for: req)
                guard stamp == generation else { return }
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any], let d = json["device"] as? [String: Any], d["OS"] as? String == "Tizen" else { throw URLError(.badServerResponse) }
                model = d["modelName"] as? String ?? "Samsung Tizen"
                guard SamsungMonitorIdentity(device: d) != nil else { busy = false; connectTimeout?.cancel(); status = "This device is not a recognized Samsung Smart Monitor."; return }
                verifiedHost = address
                await refreshMedia()
                guard stamp == generation else { return }
                startMediaMonitoring(stamp)
                if let mac = d["wifiMac"] as? String, wakePacket(mac) != nil {
                    macAddress = mac; UserDefaults.standard.set(mac, forKey: "mac.\(address)")
                }
                UserDefaults.standard.set(address, forKey: "monitorHost")
                UserDefaults.standard.set(!remoteControl,forKey:"monitorMediaOnly")
                if !remoteControl {
                    connectTimeout?.cancel(); busy = false
                    status = mediaAvailable ? "Volume connected. Remote navigation is not paired.":"Monitor found, but volume could not be read."
                    return
                }
                var url = URLComponents(); url.scheme = "wss"; url.host = address; url.port = 8002; url.path = "/api/v2/channels/samsung.remote.control"
                url.queryItems = [URLQueryItem(name: "name", value: Data("M8 Studio".utf8).base64EncodedString())]
                let savedToken = await Vault.readWithoutBlocking(address)
                guard stamp == generation else { return }
                if let token = savedToken { url.queryItems?.append(URLQueryItem(name: "token", value: token)) }
                let config = URLSessionConfiguration.ephemeral; config.timeoutIntervalForRequest = 45
                session = URLSession(configuration: config, delegate: MonitorTrust(address), delegateQueue: nil)
                socket = session?.webSocketTask(with: url.url!); socket?.resume(); connectTimeout?.cancel(); status = "Choose Allow on the monitor’s M8 Studio access request."
                connectTimeout = Task { try? await Task.sleep(for: .seconds(45)); if !Task.isCancelled, generation == stamp, !connected { stopSocket("Pairing timed out. Enable Device Connection Manager on the monitor, then reconnect.") } }
                await receive(stamp)
            } catch { if stamp == generation { connectTimeout?.cancel(); busy = false; status = "Connection failed: \(error.localizedDescription)" } }
        }
    }
    private func receive(_ stamp: UUID) async {
        while generation == stamp, let socket {
            do {
                let msg = try await socket.receive()
                guard generation == stamp else { return }
                let data: Data
                switch msg { case .data(let d): data = d; case .string(let s): data = Data(s.utf8); @unknown default: continue }
                guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let event = json["event"] as? String else { continue }
                if event == "ms.channel.connect" {
                    let token = (json["data"] as? [String: Any])?["token"]
                    connected = true; busy = false; connectTimeout?.cancel(); startMonitoring(stamp)
                    status = "Connected securely to \(model)"
                    UserDefaults.standard.set(true,forKey:"paired.\(host)")
                    let tokenValue = (token as? String) ?? (token as? NSNumber)?.stringValue
                    if let tokenValue {
                        let address = host
                        Task { let saved = await Task.detached { Vault.save(tokenValue,address) }.value
                            if generation == stamp, connected, !saved { status = "Connected. macOS could not save the pairing token; pairing may be needed again." }
                        }
                    }
                } else if event == "ms.channel.unauthorized" || event == "ms.channel.timeOut" { stopSocket("Access was denied or expired. Reconnect and choose Allow."); return }
                else if event == "ms.error" { status = "Samsung rejected the command." }
            } catch {
                if generation == stamp { stopSocket("Remote disconnected. Reconnect to continue.") }
                return
            }
        }
    }
    func send(_ key: String) {
        guard connected, allowedKeys.contains(key), let socket else { return }
        let message: [String: Any] = ["method": "ms.remote.control", "params": ["Cmd": "Click", "DataOfCmd": key, "Option": "false", "TypeOfRemote": "SendRemoteKey"]]
        guard let data = try? JSONSerialization.data(withJSONObject: message), let text = String(data: data, encoding: .utf8) else { return }
        let stamp = generation
        Task { do { try await socket.send(.string(text))
                if ["KEY_VOLUP", "KEY_VOLDOWN", "KEY_MUTE"].contains(key) { try? await Task.sleep(for: .milliseconds(350)); if stamp == generation { await refreshMedia() } } } catch { if generation == stamp { connected = false; status = "Command could not be sent. Reconnect." } } }
    }
    private func startMonitoring(_ stamp: UUID) {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(20))
                guard !Task.isCancelled, let self, self.connected, self.generation == stamp, let socket = self.socket else { return }
                socket.sendPing { _ in }
            }
        }
    }
    private func stopSocket(_ message:String) {
        connected = false; busy = false; connectTimeout?.cancel(); pingTask?.cancel()
        socket?.cancel(with:.goingAway,reason:nil); socket = nil
        session?.invalidateAndCancel(); session = nil; status = message
    }
    // Controls refresh frequently while Samsung is the active sound output; otherwise
    // back off. A failed read uses the longer interval until the monitor returns.
    var isAudioActive: (() -> Bool)?
    var mediaPollInterval: Double {
        !screenSleeping && volume != nil && (isAudioActive?() ?? false) ? 5 : 30
    }
    private func startMediaMonitoring(_ stamp:UUID) {
        mediaTask?.cancel()
        mediaTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for:.seconds(self?.mediaPollInterval ?? 30))
                guard !Task.isCancelled, let self, self.generation == stamp, self.verifiedHost == self.host else { return }
                if !self.changingVolume && !self.changingMute { await self.refreshMedia() }
            }
        }
    }
    func toggleMute() {
        guard mediaAvailable, !changingMute else { return }; changingMute = true
        let stamp = generation; let address = host; let target = !muted
        Task {
            do { _ = try await RenderingControl(host:address).request("SetMute",desired:target ? 1:0)
                await refreshMedia()
                if generation == stamp, muted != target { mediaStatus = "Mute change was not confirmed." }
            } catch { if generation == stamp { mediaStatus = "Volume change failed: \(error.localizedDescription)" } }
            if generation == stamp { changingMute = false }
        }
    }
    func refreshMedia() async {
        guard verifiedHost == host else { return }; let stamp = generation; let address = host
        do {
            let value = try await RenderingControl(host: address).read()
            guard stamp == generation, verifiedHost == address else { return }
            if volume != Double(value.0) { volume = Double(value.0) }
            if muted != value.1 { muted = value.1 }
            let summary = "Monitor reports \(value.0)%\(value.1 ? " · Muted" : "")"
            if mediaStatus != summary { mediaStatus = summary }
        } catch { if stamp == generation { volume = nil; mediaStatus = "Precise volume unavailable. Use the remote buttons." } }
    }
    func setVolume(_ value: Double) {
        guard mediaAvailable, !changingVolume, value.isFinite, (0...100).contains(value) else { return }
        let stamp = generation; let address = host; changingVolume = true
        Task {
            do {
                _ = try await RenderingControl(host: address).request("SetVolume", desired: Int(value.rounded()))
                await refreshMedia()
                if stamp == generation, volume != value.rounded() { mediaStatus = "The monitor reports \(volume.map { String(Int($0)) } ?? "unknown")%; requested level was not confirmed." }
            } catch { if stamp == generation { mediaStatus = "Volume change failed: \(error.localizedDescription)" } }
            if stamp == generation { changingVolume = false }
        }
    }
    func wake() {
        let address = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard localHost(address), let mac = UserDefaults.standard.string(forKey: "mac.\(address)"), wakePacket(mac) != nil else { status = "Pair with the monitor once to save its network address."; return }
        let sent = sendWake(mac)
        guard sent else { status = "Could not send the local wake packet."; return }
        status = "Wake request sent. Power On with Mobile must be enabled on the monitor."
        Task { try? await Task.sleep(for: .seconds(4)); if !connected && !busy { connect() } }
    }
    func forget() {
        let address = host; disconnect()
        UserDefaults.standard.removeObject(forKey:"paired.\(address)")
        UserDefaults.standard.removeObject(forKey:"certificate.\(address)")
        Task { let deleted = await Task.detached { Vault.remove(address) }.value
            status = deleted ? "Pairing for this installation was removed." : "Connection preferences cleared. macOS withheld the stored token; remove it in Keychain Access if needed."
        }
    }
}
