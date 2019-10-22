extension Array where Element == UInt8 {
    mutating func write(string: String) {
        if string.utf8.withContiguousStorageIfAvailable({ storage in
            self.append(contentsOf: storage)
        }) == nil {
            (string + "").utf8.withContiguousStorageIfAvailable({ storage in
                self.append(contentsOf: storage)
            })!
        }
    }
}
