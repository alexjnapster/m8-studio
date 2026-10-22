import Foundation
import Darwin

func wakePacket(_ mac: String) -> Data? {
    let parts = mac.split(separator: ":", omittingEmptySubsequences: false)
    guard parts.count == 6 else { return nil }
    let bytes = parts.compactMap { part -> UInt8? in
        guard part.count == 2, part.allSatisfy({ $0.isASCII && $0.isHexDigit }) else { return nil }; return UInt8(part, radix: 16)
    }
    guard bytes.count == 6, bytes.contains(where: { $0 != 0 }), bytes[0] & 1 == 0 else { return nil }
    var packet = Data(repeating: 0xff, count: 6)
    for _ in 0..<16 { packet.append(contentsOf: bytes) }
    return packet
}
func sendWake(_ mac: String) -> Bool {
    guard let packet = wakePacket(mac) else { return false }
    let descriptor = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
    guard descriptor >= 0 else { return false }; defer { close(descriptor) }
    var enable: Int32 = 1
    guard setsockopt(descriptor, SOL_SOCKET, SO_BROADCAST, &enable, socklen_t(MemoryLayout<Int32>.size)) == 0 else { return false }
    var target = sockaddr_in(); target.sin_len = UInt8(MemoryLayout<sockaddr_in>.size); target.sin_family = sa_family_t(AF_INET); target.sin_port = UInt16(9).bigEndian
    guard inet_pton(AF_INET, "255.255.255.255", &target.sin_addr) == 1 else { return false }
    return packet.withUnsafeBytes { bytes in
        withUnsafePointer(to: &target) { pointer in
            pointer.withMemoryRebound(to: sockaddr.self, capacity: 1) { sendto(descriptor, bytes.baseAddress, bytes.count, 0, $0, socklen_t(MemoryLayout<sockaddr_in>.size)) == packet.count }
        }
    }
}
