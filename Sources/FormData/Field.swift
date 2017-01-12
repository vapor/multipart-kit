import Multipart

public struct Field {
    var name: String
    var filename: String?
    var part: Multipart.Part
    
    public init(name: String, filename: String?, part: Multipart.Part) {
        self.name = name
        self.filename = filename
        self.part = part
    }
}
