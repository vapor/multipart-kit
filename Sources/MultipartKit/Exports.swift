#if swift(>=5.8)

@_documentation(visibility: internal) @_exported import protocol Foundation.DataProtocol
@_documentation(visibility: internal) @_exported import struct NIO.ByteBuffer
@_documentation(visibility: internal) @_exported import struct NIOHTTP1.HTTPHeaders

#else

@_exported import protocol Foundation.DataProtocol
@_exported import struct NIO.ByteBuffer
@_exported import struct NIOHTTP1.HTTPHeaders

#endif
