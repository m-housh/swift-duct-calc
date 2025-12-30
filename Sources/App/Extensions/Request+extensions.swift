import Vapor

extension Request {
  var isHtmxRequest: Bool {
    headers.contains(name: "hx-request")
  }
}
