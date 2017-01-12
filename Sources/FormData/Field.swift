import Multipart

public struct Field {
    var name: String
    var filename: String?
    var part: Multipart.Part
}
