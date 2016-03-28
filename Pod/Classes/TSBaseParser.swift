//
//  TSBaseParser.swift
//  TSSwiftMarkdownParser
//
//  Created by Rhett Rogers on 3/24/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation



public class TSBaseParser {

    public typealias TSSwiftMarkdownParserMatchBlock = ((NSTextCheckingResult, NSMutableAttributedString) -> Void)
    
    struct TSExpressionBlockPair {
        
        var regularExpression: NSRegularExpression
        var block: TSSwiftMarkdownParserMatchBlock
        
    }
    
    public var defaultAttributes = [String: AnyObject]()
    
    private var parsingPairs = [TSExpressionBlockPair]()
    
    public func attributedStringFromMarkdown(markdown: String) -> NSAttributedString? {
        return attributedStringFromMarkdown(markdown, attributes: defaultAttributes)
    }
    
    public func attributedStringFromMarkdown(markdown: String, attributes: [String: AnyObject]?) -> NSAttributedString? {
        var attributedString: NSAttributedString?
        if let attributes = attributes {
            attributedString = NSAttributedString(string: markdown, attributes: attributes)
        } else {
            attributedString = NSAttributedString(string: markdown)
        }
        
        return attributedStringFromAttributedMarkdownString(attributedString)
    }
    
    public func attributedStringFromAttributedMarkdownString(attributedString: NSAttributedString?) -> NSAttributedString? {
        guard let attributedString = attributedString else { return nil }
        let mutableAttributedString = NSMutableAttributedString(attributedString: attributedString)
        
        for expressionBlockPair in parsingPairs {
            var location = 0
            while let match = expressionBlockPair.regularExpression.firstMatchInString(mutableAttributedString.string, options: .WithoutAnchoringBounds, range: NSRange(location: location, length: mutableAttributedString.length - location)) {
                let oldLength = mutableAttributedString.length
                expressionBlockPair.block(match, mutableAttributedString)
                let newLength = mutableAttributedString.length
                location = match.range.location + match.range.length + newLength - oldLength
            }
            
        }
        
        return mutableAttributedString
    }
    
    public func addParsingRuleWithRegularExpression(regularExpression: NSRegularExpression, block: TSSwiftMarkdownParserMatchBlock) {
        parsingPairs.append(TSExpressionBlockPair(regularExpression: regularExpression, block: block))
    }
    
}