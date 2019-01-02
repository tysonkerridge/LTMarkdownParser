//
//  TSBaseParser.swift
//  LTMarkdownParser
//
//  Created by Rhett Rogers on 3/24/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation

open class TSBaseParser {

    public typealias LTMarkdownParserMatchBlock = ((NSTextCheckingResult, NSMutableAttributedString) -> Void)
    
    struct TSExpressionBlockPair {
        
        var regularExpression: NSRegularExpression
        var block: LTMarkdownParserMatchBlock
        
    }
    
    open var defaultAttributes = [NSAttributedString.Key: Any]()
    
    fileprivate var parsingPairs = [TSExpressionBlockPair]()
    
    open func attributedStringFromMarkdown(_ markdown: String) -> NSAttributedString? {
        return attributedStringFromMarkdown(markdown, attributes: defaultAttributes)
    }
    
    open func attributedStringFromMarkdown(_ markdown: String, attributes: [NSAttributedString.Key: Any]?) -> NSAttributedString? {
        return attributedStringFromAttributedMarkdownString(NSAttributedString(string: markdown, attributes: attributes))
    }
    
    open func attributedStringFromAttributedMarkdownString(_ attributedString: NSAttributedString?) -> NSAttributedString? {
        guard let attributedString = attributedString else { return nil }
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        for expressionBlockPair in parsingPairs {
            parseExpressionBlockPairForMutableString(mutableAttributedString, expressionBlockPair: expressionBlockPair)
        }
        
        return mutableAttributedString
    }
    
    func parseExpressionBlockPairForMutableString(_ mutableAttributedString: NSMutableAttributedString, expressionBlockPair: TSExpressionBlockPair) {
        parseExpressionForMutableString(mutableAttributedString, expression: expressionBlockPair.regularExpression, block: expressionBlockPair.block)
    }
    
    func parseExpressionForMutableString(_ mutableAttributedString: NSMutableAttributedString, expression: NSRegularExpression, block: LTMarkdownParserMatchBlock) {
        var location = 0
        
        while let match = expression.firstMatch(in: mutableAttributedString.string, options: .withoutAnchoringBounds, range: NSRange(location: location, length: mutableAttributedString.length - location)) {
            let oldLength = mutableAttributedString.length
            block(match, mutableAttributedString)
            let newLength = mutableAttributedString.length
            location = match.range.location + match.range.length + newLength - oldLength
        }
    }
    
    /// - Parameter insertAtFront: Whether its inserted at the beginning of the array of rules rather than appended to the end. Defaults to false (added to end).
    /// - Note: `insertAtFront` useful for cases where one regular expression might conflict with another already there and it needs to be before the other (without adding logic to decide where it gets added compared to all the rest already there).
    open func addParsingRuleWithRegularExpression(_ regularExpression: NSRegularExpression, insertAtFront: Bool = false, block: @escaping LTMarkdownParserMatchBlock) {
        let pair = TSExpressionBlockPair(regularExpression: regularExpression, block: block)
        if insertAtFront {
            parsingPairs.insert(pair, at: 0)
        } else {
            parsingPairs.append(pair)
        }
    }
    
}
