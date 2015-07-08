
## App Store Receipt Decoder

The Apple App Store receipt is a PKCS7 container signed with Apple's
private key and needs to be decrypted with Apple's public key to obtain
the contained payload data. The payload data is in ASN.1 DER format.

This project helps in decoding that format.

### Usage

To try it, run `./run.sh`

To use it in your Swift project, add `AppStoreReceipt.swift` to the project and use it like this:

~~~ Swift
let data: NSData // data output from PKCS7_verify
var bundleId: String?
var bundleIdData: NSData?
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

To use it in your Objective-C project, add `AppStoreReceipt.swift` to the project, add the `@objc` attribute to the `AppStoreReceipt` Swift class, import the Swift header (see 'Using Swift from Objective-C' in [_Using Swift with Cocoa and Objective-C_][swift-cocoa-book]), and use it like this:

[swift-cocoa-book]: https://developer.apple.com/library/prerelease/ios/documentation/Swift/Conceptual/BuildingCocoaApps/

~~~ Objective-C
NSData* data; // data output from PKCS7_verify
__block NSString* bundleId;
__block NSData* bundleIdData;
AppStoreReceipt *receipt = [AppStoreReceipt receiptWithPayloadData: data];
[receipt enumerateReceiptAttributes:^(NSInteger type, NSInteger version, NSData * __nonnull value) {
    switch (type) {
        case 2:
            bundleId = [AppStoreReceipt decodeASN1String:value];
            bundleIdData = value;
            break;
        ...
        default:
            break;
    }
}];
~~~

See `main.swift` for a more detailed example.

### Why

Integrating the [ASN.1 compiler][asn1c]-generated code with an iOS
project introduces multiple source files and warnings, and is not Swift
1.2-friendly because of the use of function pointers.

This project provides a clean one-file receipt decoder in Swift.

[asn1c]: https://github.com/vlm/asn1c

