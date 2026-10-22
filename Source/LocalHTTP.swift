import Foundation
final class NoRedirects:NSObject,URLSessionTaskDelegate {
    func urlSession(_ session:URLSession,task:URLSessionTask,willPerformHTTPRedirection response:HTTPURLResponse,newRequest request:URLRequest,completionHandler:@escaping(URLRequest?)->Void) { completionHandler(nil) }
}
enum LocalHTTP {
    static let session:URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4; config.timeoutIntervalForResource = 6
        config.httpCookieStorage = nil; config.urlCache = nil; config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration:config,delegate:NoRedirects(),delegateQueue:nil)
    }()
}
