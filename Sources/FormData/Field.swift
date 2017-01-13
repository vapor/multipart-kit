import Multipart

/**
    A single form-data field with the field name,
    optional filename, and underlying Multipart.Part.
 
    Headers and body reside in the Part.
*/
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
