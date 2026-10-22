import Foundation

enum RenderingError: Error, LocalizedError {
    case invalidHost, invalidResponse, rejected(Int)
    var errorDescription: String? {
        switch self { case .invalidHost: return "A private monitor address is required."; case .invalidResponse: return "The monitor did not return a valid control value."; case .rejected(let code): return "The monitor rejected the media control (HTTP \(code))." }
    }
}
final class XMLValues: NSObject, XMLParserDelegate {
    var values: [String: String] = [:]
    private var names: [String] = []
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) { names.append(elementName.components(separatedBy: ":").last ?? elementName) }
    func parser(_ parser: XMLParser, foundCharacters string: String) { if let key = names.last { values[key, default: ""] += string } }
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) { if !names.isEmpty { names.removeLast() } }
    static func parse(_ data: Data) -> [String: String]? {
        let delegate = XMLValues(); let parser = XMLParser(data: data); parser.delegate = delegate
        parser.shouldResolveExternalEntities = false
        guard parser.parse(), delegate.values["errorCode"] == nil else { return nil }
        return delegate.values.mapValues { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
    }
}
struct RenderingControl {
    let host: String
    static let service = "urn:schemas-upnp-org:service:RenderingControl:1"
    func request(_ action: String, desired: Int? = nil) async throws -> [String: String] {
        guard localHost(host) else { throw RenderingError.invalidHost }
        guard ["GetVolume", "GetMute", "SetVolume", "SetMute"].contains(action) else { throw RenderingError.invalidResponse }
        var arguments = "<InstanceID>0</InstanceID><Channel>Master</Channel>"
        if action == "SetVolume" { guard let desired, (0...100).contains(desired) else { throw RenderingError.invalidResponse }; arguments += "<DesiredVolume>\(desired)</DesiredVolume>" }
        if action == "SetMute" { guard let desired, (0...1).contains(desired) else { throw RenderingError.invalidResponse }; arguments += "<DesiredMute>\(desired)</DesiredMute>" }
        let body = "<?xml version=\"1.0\"?><s:Envelope xmlns:s=\"http://schemas.xmlsoap.org/soap/envelope/\" s:encodingStyle=\"http://schemas.xmlsoap.org/soap/encoding/\"><s:Body><u:\(action) xmlns:u=\"\(Self.service)\">\(arguments)</u:\(action)></s:Body></s:Envelope>"
        var req = URLRequest(url: URL(string: "http://\(host):9197/upnp/control/RenderingControl1")!); req.httpMethod = "POST"; req.httpBody = Data(body.utf8); req.timeoutInterval = 3
        req.setValue("text/xml; charset=\"utf-8\"", forHTTPHeaderField: "Content-Type"); req.setValue("\"\(Self.service)#\(action)\"", forHTTPHeaderField: "SOAPACTION")
        let (data, response) = try await LocalHTTP.session.data(for: req)
        guard let http = response as? HTTPURLResponse else { throw RenderingError.invalidResponse }
        guard http.statusCode == 200 else { throw RenderingError.rejected(http.statusCode) }
        guard let values = XMLValues.parse(data) else { throw RenderingError.invalidResponse }; return values
    }
    func read() async throws -> (Int, Bool) {
        let v = try await request("GetVolume"); let m = try await request("GetMute")
        guard let raw = v["CurrentVolume"], let volume = Int(raw), (0...100).contains(volume), let mute = m["CurrentMute"], ["0","1","true","false"].contains(mute.lowercased()) else { throw RenderingError.invalidResponse }
        return (volume, mute == "1" || mute.lowercased() == "true")
    }
}
