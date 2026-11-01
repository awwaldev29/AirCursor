import Darwin
import Foundation

enum NetworkInfo {
    /// IPv4 addresses of active, non-loopback interfaces (e.g. Wi-Fi `en0`), for the user to type on the Watch.
    static func localIPv4Addresses() -> [String] {
        var result: [String] = []
        var head: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&head) == 0, let first = head else { return [] }
        defer { freeifaddrs(head) }

        for pointer in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let interface = pointer.pointee
            let flags = Int32(interface.ifa_flags)
            guard let address = interface.ifa_addr,
                  address.pointee.sa_family == UInt8(AF_INET),
                  flags & IFF_UP != 0, flags & IFF_LOOPBACK == 0
            else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(address, socklen_t(address.pointee.sa_len), &host, socklen_t(host.count),
                           nil, 0, NI_NUMERICHOST) == 0 {
                let name = String(cString: interface.ifa_name)
                let ip = String(decoding: host.prefix { $0 != 0 }.map(UInt8.init), as: UTF8.self)
                // Wi-Fi / Ethernet first; skip link-local addresses that the Watch cannot reach.
                guard !ip.hasPrefix("169.254.") else { continue }
                if name.hasPrefix("en") { result.insert(ip, at: 0) } else { result.append(ip) }
            }
        }
        return result
    }
}
