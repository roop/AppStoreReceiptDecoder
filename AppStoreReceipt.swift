//
//  AppStoreReceipt.swift
//  Decode the decrypted payload data in App Store receipts.
//
//  Copyright (c) 2015 Roopesh Chander. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
// 
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
// 
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.


//  The App Store receipt is signed with Apple's private key and
//  needs to be decrypted with Apple's public key to obtain the
//  payload data. The payload data is in ASN.1 DER format, which
//  can be decoded with this Swift class.
//  
//  See main.swift for example usage.


import Foundation

// Add '@objc' here if you'd like to use this from Objective-C
class AppStoreReceipt {
    let _payloadData: NSData

    init(payloadData: NSData) {
        self._payloadData = payloadData
    }

    class func receiptWithPayloadData(payloadData: NSData) -> AppStoreReceipt {
        // Helper for using this class from Objective-C.
        // This is required because AppStoreReceipt is not an NSObject.
        return AppStoreReceipt(payloadData: payloadData)
    }

    func enumerateReceiptAttributes(block: (type: Int, version: Int, value: NSData) -> Void) -> Bool {
        return AppStoreReceipt.enumerateReceiptAttributesInASN1SetData(self._payloadData, block: block)
    }

    class func decodeASN1String(data: NSData) -> String? {
        let ptr = UnsafePointer<UInt8>(data.bytes)
        let len: Int = data.length
        var pos: Int = 0
        var numOfBytesInString: Int? = 0

        var decodedString = String()

        while (pos < len) {
            let typeByte = ptr[pos++]
            numOfBytesInString = self.decodeASN1Length(ptr, pos: &pos, bufferLength: len)
            if (numOfBytesInString == nil) { return nil }
            if (pos + numOfBytesInString! > len) { return nil }
            let encoding: NSStringEncoding
            if (typeByte == ASN1Tag.UTF8String.rawValue) {
                encoding = NSUTF8StringEncoding
            } else if (typeByte == ASN1Tag.IA5String.rawValue) {
                encoding = NSASCIIStringEncoding
            } else {
                // Other string types are not used in App Store receipts
                return nil
            }
            let str = NSString(bytes: UnsafePointer<Void>(ptr + pos), length: numOfBytesInString!, encoding: encoding)
            if let str = str as? String {
                decodedString += str
            }
            pos += numOfBytesInString!
        }

        return decodedString
    }

    class func decodeASN1Integer(data: NSData) -> Int? {
        let ptr = UnsafePointer<UInt8>(data.bytes)
        let len: Int = data.length
        var pos: Int = 0

        if (ptr[pos++] != ASN1Tag.Integer.rawValue) { return nil }
        if (pos >= len) { return nil }
        let numOfBytes: Int? = self.decodeASN1Length(ptr, pos: &pos, bufferLength: len)
        if (numOfBytes == nil) { return nil }
        if (pos + numOfBytes! > len) { return nil }

        return self.decodeASN1Integer(ptr, pos: &pos, numberOfBytes: numOfBytes!)
    }
}

// Private stuff follows

private enum ASN1Tag: UInt8 {
    case Integer = 0x02
    case OctetString = 0x04
    case UTF8String = 0x0c
    case IA5String = 0x16
    case Sequence = 0x30    // 0x20 /*Compound*/ | 0x10
    case Set = 0x31         // 0x20 /*Compound*/ | 0x11
}

private typealias ReceiptAttribute = (type: Int, version: Int, value: NSData)

extension AppStoreReceipt {
    private class func enumerateReceiptAttributesInASN1SetData(data: NSData, block: (type: Int, version: Int, value: NSData) -> Void) -> Bool {
        let ptr = UnsafePointer<UInt8>(data.bytes)
        let len: Int = data.length
        var pos: Int = 0
        var fieldIndex: Int = 0

        if (ptr[pos++] != ASN1Tag.Set.rawValue) { return false }
        if (pos >= len) { return false }

        let numOfBytesInSet = self.decodeASN1Length(ptr, pos: &pos, bufferLength: len)
        if (numOfBytesInSet == nil) { return false }

        let endOfSetContents = pos + numOfBytesInSet!
        if (len < endOfSetContents) {
            return false
        }

        while (pos < len) {
            if let receiptAttribute = self.decodeASN1ReceiptAttribute(ptr, pos: &pos, bufferLength: endOfSetContents) {
                block(type: receiptAttribute.type, version: receiptAttribute.version, value: receiptAttribute.value)
            } else {
                return false
            }
        }

        return true
    }
}

extension AppStoreReceipt {
    private class func decodeASN1Length(ptr: UnsafePointer<UInt8>, inout pos: Int, bufferLength length: Int) -> Int? {
        let byte = ptr[pos]
        if ((byte & 0x80) == 0x00) {
            // Short form
            pos++
            return Int(byte)
        } else if ((byte & 0x7f) > 0x00) {
            // Long form
            var numOfLengthBytes = Int(byte & 0x7f)
            pos++
            if (pos + numOfLengthBytes >= length) { return nil }
            return self.decodeASN1Integer(ptr, pos: &pos, numberOfBytes: numOfLengthBytes)
        } else {
            // Indefinite form is not expected in App Store receipts
            return nil
        }
    }

    private class func decodeASN1ReceiptAttribute(ptr: UnsafePointer<UInt8>, inout pos: Int, bufferLength len: Int) -> ReceiptAttribute? {
        if (ptr[pos++] != ASN1Tag.Sequence.rawValue) { return nil }
        if (pos >= len) { return nil }

        let numOfBytesInSequence = self.decodeASN1Length(ptr, pos: &pos, bufferLength: len)
        if (numOfBytesInSequence == nil) { return nil }

        let endOfSequenceContents = pos + numOfBytesInSequence!

        var numOfBytesInField: Int? = 0

        if (ptr[pos++] != ASN1Tag.Integer.rawValue) { return nil }
        if (pos >= endOfSequenceContents) { return nil }
        numOfBytesInField = self.decodeASN1Length(ptr, pos: &pos, bufferLength: endOfSequenceContents)
        if (numOfBytesInField == nil) { return nil }
        if (pos + numOfBytesInField! > endOfSequenceContents) { return nil }
        let first: Int = self.decodeASN1Integer(ptr, pos: &pos, numberOfBytes: numOfBytesInField!)

        if (ptr[pos++] != ASN1Tag.Integer.rawValue) { return nil }
        if (pos >= endOfSequenceContents) { return nil }
        numOfBytesInField = self.decodeASN1Length(ptr, pos: &pos, bufferLength: endOfSequenceContents)
        if (numOfBytesInField == nil) { return nil }
        if (pos + numOfBytesInField! > endOfSequenceContents) { return nil }
        let second: Int = self.decodeASN1Integer(ptr, pos: &pos, numberOfBytes: numOfBytesInField!)

        if (ptr[pos++] != ASN1Tag.OctetString.rawValue) { return nil }
        if (pos >= endOfSequenceContents) { return nil }
        numOfBytesInField = self.decodeASN1Length(ptr, pos: &pos, bufferLength: endOfSequenceContents)
        if (numOfBytesInField == nil) { return nil }
        if (pos + numOfBytesInField! > endOfSequenceContents) { return nil }
        let third: NSData = self.decodeASN1OctetString(ptr, pos: &pos, numberOfBytes: numOfBytesInField!)

        return (type: first, version: second, value: third)
    }

    private class func decodeASN1Integer(ptr: UnsafePointer<UInt8>, inout pos: Int, numberOfBytes: Int) -> Int {
        var result: UInt64 = 0
        for i in (0 ..< numberOfBytes) {
            let byte: UInt8 = ptr[pos + i]
            result |= (UInt64(byte) << UInt64((numberOfBytes - 1 - i) * 8))
        }
        pos += numberOfBytes
        return Int(result)
    }

    private class func decodeASN1OctetString(ptr: UnsafePointer<UInt8>, inout pos: Int, numberOfBytes: Int) -> NSData {
        let data = NSData(bytesNoCopy: UnsafeMutablePointer<Void>(ptr + pos), length: numberOfBytes, freeWhenDone: false)
        pos += numberOfBytes
        return data
    }
}

