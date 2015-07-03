import Foundation

// For knowing which field type corresponds to what data,
// please see "Receipt Fields"
// https://developer.apple.com/library/ios/releasenotes/General/ValidateAppStoreReceipt/Chapters/ReceiptFields.html

let data = NSData(contentsOfFile: "./receipt_payload.sample")
if let data = data {
    let receipt = AppStoreReceipt(payloadData: data)
    receipt.enumerateReceiptAttributes { (type, version, value) in
        switch (type) {
        case 2: fallthrough
        case 3: fallthrough
        case 19: fallthrough
        case 21:
            println("type = \(type); data (\(value.length) bytes) = \(value)")
            if let str = AppStoreReceipt.decodeASN1String(value) {
                println("    string: \"\(str)\"")
            }
            println("")
        case 4: fallthrough
        case 5:
            println("type = \(type); data (\(value.length) bytes) = \(value)")
            println("")
        case 17:
            let inAppPurchaseReceipt = AppStoreReceipt(payloadData: value)
            inAppPurchaseReceipt.enumerateReceiptAttributes { (type, version, value) in
                switch (type) {
                case 1702: fallthrough
                case 1703: fallthrough
                case 1704: fallthrough
                case 1705: fallthrough
                case 1706: fallthrough
                case 1712:
                    println("type = \(type); data (\(value.length) bytes) = \(value)")
                    if let str = AppStoreReceipt.decodeASN1String(value) {
                        println("    string: \"\(str)\"")
                    }
                    println("")
                case 1701:
                    println("type = \(type); data (\(value.length) bytes) = \(value)")
                    if let intVal = AppStoreReceipt.decodeASN1Integer(value) {
                        println("    integer: [\(intVal)]")
                    }
                    println("")
                default:
                    break
                }
            }
        default:
            break
        }
    }
}
