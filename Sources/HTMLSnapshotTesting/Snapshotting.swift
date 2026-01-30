import Elementary
import SnapshotTesting

extension Snapshotting where Value == (any HTML), Format == String {
  public static var html: Snapshotting {
    var snapshotting = SimplySnapshotting.lines
      .pullback { (html: any HTML) in html.renderFormatted() }

    snapshotting.pathExtension = "html"
    return snapshotting
  }
}

// extension Snapshotting where Value == String, Format == String {
//   public static var html: Snapshotting {
//     var snapshotting = SimplySnapshotting.lines
//       .pullback { $0 }
//
//     snapshotting.pathExtension = "html"
//     return snapshotting
//   }
// }
