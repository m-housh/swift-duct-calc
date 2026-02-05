import ManualDCore
import Parsing

struct RoomCSVParser: Parser {
  var body: some Parser<Substring.UTF8View, [RoomRowType]> {
    Many {
      RoomRowParser()
    } separator: {
      "\n".utf8
    }
  }
}

struct RoomRowParser: Parser {

  var body: some Parser<Substring.UTF8View, RoomRowType> {
    OneOf {
      RoomCreateParser().map { RoomRowType.room($0) }
      Prefix { $0 != UInt8(ascii: "\n") }
        .map(.string)
        .map { RoomRowType.header($0) }
    }
  }
}

enum RoomRowType {
  case header(String)
  case room(Room.Create)
}

struct RoomCreateParser: ParserPrinter {

  var body: some ParserPrinter<Substring.UTF8View, Room.Create> {
    ParsePrint {
      Prefix { $0 != UInt8(ascii: ",") }.map(.string)
      ",".utf8
      Double.parser()
      ",".utf8
      Optionally {
        Double.parser()
      }
      ",".utf8
      Optionally {
        Double.parser()
      }
      ",".utf8
      Int.parser()
    }
    .map(.memberwise(Room.Create.init))
  }
}
