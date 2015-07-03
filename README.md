
## App Store Receipt Decoder

The Apple App Store receipt is a PKCS7 container signed with Apple's
private key and needs to be decrypted with Apple's public key to obtain
the contained payload data. The payload data is in ASN.1 DER format.

This project helps in decoding that format.

### Usage

To try it, run `./run.sh`

To use it in your project, add `AppStoreReceipt.swift` to the project and use it like:

~~~ Swift
let data: NSData // data output from PKCS7_verify
let bundleId: String?
let bundleIdData: NSData?
let receipt = AppStoreReceipt(payloadData: data)
receipt.enumerateReceiptAttributes { (type, version, value) in
    switch (type) {
        case 2: // Bundle id
            bundleId = AppStoreReceipt.decodeASN1String(value)
            bundleIdData = value
        ...
        default:
            break
    }
}
~~~

See `main.swift` for a more detailed example.

### Why

Integrating the [ASN.1 compiler][asn1c]-generated code with an iOS
project introduces multiple source files and warnings, and is not Swift
1.2-friendly because of the use of function pointers.

This project provides a clean one-file receipt decoder in Swift.

[asn1c]: https://github.com/vlm/asn1c

