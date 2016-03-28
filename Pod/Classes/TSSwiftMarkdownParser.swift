//
//  TSSwiftMarkdownParser.swift
//  TSSwiftMarkdownParser
//
//  Created by Rhett Rogers on 3/24/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

public struct TSSwiftMarkdownRegex {
    public static let Escaping = "\\\\."
    public static let Unescaping = "\\\\[0-9a-z]{4}"
    
    public static let Header = "^(#{1,%@})\\s+(.+)$"
    public static let ShortHeader = "^(#{1,%@})\\s*([^#].*)$"
    public static let List = "^([\\*\\+\\-]{1,%@})\\s+(.+)$"
    public static let ShortList = "^([\\*\\+\\-]{1,%@})\\s*([^\\*\\+\\-].*)$"
    public static let Quote = "^(\\>{1,%@})\\s+(.+)$"
    public static let ShortQuote = "^(\\>{1,%@})\\s*([^\\>].*)$"
    
    public static let Image = "\\!\\[[^\\[]*?\\]\\(\\S*\\)"
    public static let Link = "\\[[^\\[]*?\\]\\([^\\)]*\\)"
    
    public static let Monospace = "(`+)(\\s*.*?[^`]\\s*)(\\1)(?!`)"
    public static let Strong = "(\\*\\*|__)(.+?)(\\1)"
    public static let Emphasis = "(\\*|_)(.+?)(\\1)"
    
    public static func regexForString(regexString: String, options: NSRegularExpressionOptions = []) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: regexString, options: options)
        } catch {
            return nil
        }
    }
}

public class TSSwiftMarkdownParser: TSBaseParser {
    
    public typealias TSSwiftMarkdownParserFormattingBlock = ((NSMutableAttributedString, NSRange) -> Void)
    public typealias TSSwiftMarkdownParserLevelFormattingBlock = ((NSMutableAttributedString, NSRange, Int) -> Void)
    
    public var headerAttributes = [[String: AnyObject]]()
    public var listAttributes = [[String: AnyObject]]()
    public var quoteAttributes = [[String: AnyObject]]()
    
    public var imageAttributes = [String: AnyObject]()
    public var linkAttributes = [String: AnyObject]()
    public var monospaceAttributes = [String: AnyObject]()
    public var strongAttributes = [String: AnyObject]()
    public var emphasisAttributes = [String: AnyObject]()
    
    
    public static var standardParser: TSSwiftMarkdownParser {
        let defaultParser = TSSwiftMarkdownParser()
        
        defaultParser.addEscapingParsing()
        defaultParser.addCodeEscapingParsing()
        
        defaultParser.addHeaderParsingWithMaxLevel(0, leadFormattingBlock: { (attributedString, range, level) in
            attributedString.replaceCharactersInRange(range, withString: "")
        }) { attributedString, range, level in
            self.addAttributes(defaultParser.headerAttributes, atIndex: level - 1, toString: attributedString, range: range)
        }
        
        defaultParser.addListParsingWithMaxLevel(0, leadFormattingBlock: { attributedString, range, level in
            var listString = ""
            var currentLevel = level - 1
            while currentLevel > 0 {
                listString = "\(listString)\t"
                currentLevel -= 1
            }
            listString = "\(listString)•\t"
            attributedString.replaceCharactersInRange(range, withString: listString)
        }) { attributedString, range, level in
            self.addAttributes(defaultParser.listAttributes, atIndex: level - 1, toString: attributedString, range: range)
        }
        
        defaultParser.addQuoteParsingWithMaxLevel(0, leadFormattingBlock: { attributedString, range, level in
            var quoteString = ""
            var currentLevel = level
            while currentLevel > 0 {
                currentLevel -= 1
                quoteString = "\(quoteString)\t"
            }
            attributedString.replaceCharactersInRange(range, withString: quoteString)
        }) { attributedString, range, level in
            self.addAttributes(defaultParser.quoteAttributes, atIndex: level - 1, toString: attributedString, range: range)
        }
        
        defaultParser.addImageParsingWithImageFormattingBlock({ attributedString, range in
            //No default formatting
        }) { attributedString, range in
            attributedString.addAttributes(defaultParser.imageAttributes, range: range)
        }
        
        defaultParser.addLinkParsingWithFormattingBlock { attributedString, range in
            attributedString.addAttributes(defaultParser.linkAttributes, range: range)
        }
        
        defaultParser.addLinkDetectionWithFormattingBlock { attributedString, range in
            attributedString.addAttributes(defaultParser.linkAttributes, range: range)
        }
        
        defaultParser.addStrongParsingWithFormattingBlock { attributedString, range in
            attributedString.addAttributes(defaultParser.strongAttributes, range: range)
        }
        
        defaultParser.addEmphasisParsingWithFormattingBlock { attributedString, range in
            attributedString.addAttributes(defaultParser.emphasisAttributes, range: range)
        }
        
        defaultParser.addCodeUnescapingParsingWithFormattingBlock { attributedString, range in
            attributedString.addAttributes(defaultParser.monospaceAttributes, range: range)
        }
        
        defaultParser.addUnescapingParsing()
        
        return defaultParser
    }
    
    class func addAttributes(attributesArray: [[String: AnyObject]], atIndex level: Int, toString attributedString: NSMutableAttributedString, range: NSRange) {
        guard !attributesArray.isEmpty else { return }
        
        guard let newAttributes = level < attributesArray.count ? attributesArray[level] : attributesArray.last else { return }
        
        attributedString.addAttributes(newAttributes, range: range)
    }
    
    public override init() {
        super.init()
        
        defaultAttributes = [NSFontAttributeName: UIFont.systemFontOfSize(12)]
        headerAttributes = [
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(23)],
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(21)],
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(19)],
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(17)],
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(15)],
            [NSFontAttributeName: UIFont.boldSystemFontOfSize(13)]
        ]
        
        linkAttributes = [
            NSForegroundColorAttributeName: UIColor.blueColor(),
            NSUnderlineColorAttributeName: NSUnderlineStyle.StyleSingle.rawValue
        ]
        
        monospaceAttributes = [
            NSFontAttributeName: UIFont(name: "Menlo", size: 12) ?? UIFont.systemFontOfSize(12),
            NSForegroundColorAttributeName: UIColor(red: 0.95, green: 0.54, blue: 0.55, alpha: 1)
        ]
        
        strongAttributes = [NSFontAttributeName: UIFont.boldSystemFontOfSize(12)]
        emphasisAttributes = [NSFontAttributeName: UIFont.italicSystemFontOfSize(12)]
    }
    
    public func addEscapingParsing() {
        guard let escapingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Escaping) else { return }
        
        addParsingRuleWithRegularExpression(escapingRegex) { match, attributedString in
            let range = NSRange(location: match.range.location + 1, length: 1)
            let matchString = attributedString.attributedSubstringFromRange(range).string as NSString
            let escapedString = NSString(format: "%04x", matchString.characterAtIndex(0)) as String
            attributedString.replaceCharactersInRange(range, withString: escapedString)
        }
    }
    
    public func addCodeEscapingParsing() {
        guard let codingParsingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Monospace) else { return }
        
        addParsingRuleWithRegularExpression(codingParsingRegex) { match, attributedString in
            let range = match.rangeAtIndex(2)
            let matchString = attributedString.attributedSubstringFromRange(range).string as NSString
            
            var escapedString = ""
            for index in 0..<range.length {
                escapedString = "\(escapedString)\(NSString(format: "%04x", matchString.characterAtIndex(index)))"
            }

            attributedString.replaceCharactersInRange(range, withString: escapedString)
        }
    }
    
    private func addLeadParsingWithPattern(pattern: String, maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        let regexString = NSString(format: pattern, maxLevel > 0 ? "\(maxLevel)" : "") as String
        guard let regex = TSSwiftMarkdownRegex.regexForString(regexString, options: .AnchorsMatchLines) else { return }
        
        addParsingRuleWithRegularExpression(regex) { match, attributedString in
            let level = match.rangeAtIndex(1).length
            formattingBlock?(attributedString, match.rangeAtIndex(2), level)
            leadFormattingBlock(attributedString, NSRange(location: match.rangeAtIndex(1).location, length: match.rangeAtIndex(2).location - match.rangeAtIndex(1).location), level)
        }
    }
    
    public func addHeaderParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.Header, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addListParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.List, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addQuoteParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.Quote, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addShortHeaderParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortHeader, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addShortListParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortList, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addShortQuoteParsingWithMaxLevel(maxLevel: Int, leadFormattingBlock: TSSwiftMarkdownParserLevelFormattingBlock, textFormattingBlock formattingBlock: TSSwiftMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortQuote, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    public func addImageParsingWithImageFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock?, alternativeTextFormattingBlock alternateFormattingBlock: TSSwiftMarkdownParserFormattingBlock?) {
        guard let headerRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Image, options: .DotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(headerRegex) { match, attributedString in
            let imagePathStart = (attributedString.string as NSString).rangeOfString("(", options: [], range: match.range).location
            let linkRange = NSRange(location: imagePathStart, length: match.range.length + match.range.location - imagePathStart - 1)
            let imagePath = (attributedString.string as NSString).substringWithRange(NSRange(location: linkRange.location + 1, length: linkRange.length - 1))
            
            if let image = UIImage(named: imagePath) {
                let imageAttatchment = NSTextAttachment()
                imageAttatchment.image = image
                imageAttatchment.bounds = CGRect(x: 0, y: -5, width: image.size.width, height: image.size.height)
                let imageString = NSAttributedString(attachment: imageAttatchment)
                attributedString.replaceCharactersInRange(match.range, withAttributedString: imageString)
                formattingBlock?(attributedString, NSRange(location: match.range.location, length: imageString.length))
            } else {
                let linkTextEndLocation = (attributedString.string as NSString).rangeOfString("]", options: [], range: match.range).location
                let linkTextRange = NSRange(location: match.range.location + 2, length: linkTextEndLocation - match.range.location - 2)
                let alternativeText = (attributedString.string as NSString).substringWithRange(linkTextRange)
                attributedString.replaceCharactersInRange(match.range, withString: alternativeText)
                alternateFormattingBlock?(attributedString, NSRange(location: match.range.location, length: (alternativeText as NSString).length))
            }
        }
    }
    
    public func addLinkParsingWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        guard let linkRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Link, options: .DotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(linkRegex) { match, attributedString in
            let linkStartinResult = (attributedString.string as NSString).rangeOfString("(", options: .BackwardsSearch, range: match.range).location
            let linkRange = NSRange(location: linkStartinResult, length: match.range.length + match.range.location - linkStartinResult - 1)
            let linkURLString = (attributedString.string as NSString).substringWithRange(NSRange(location: linkRange.location + 1, length: linkRange.length - 1))
            
            let linkTextRange = NSRange(location: match.range.location + 1, length: linkStartinResult - match.range.location - 2)
            attributedString.deleteCharactersInRange(NSRange(location: linkRange.location - 1, length: linkRange.length + 2))
            
            if let URL = NSURL(string: linkURLString) ?? NSURL(string: linkURLString.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding) ?? linkURLString) {
                attributedString.addAttribute(NSLinkAttributeName, value: URL, range: linkTextRange)
            }
            formattingBlock(attributedString, linkTextRange)
            
            attributedString.deleteCharactersInRange(NSRange(location: match.range.location, length: 1))
        }
    }
    
    private func addEnclosedParsingWithPattern(pattern: String, formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        guard let regex = TSSwiftMarkdownRegex.regexForString(pattern) else { return }
        
        addParsingRuleWithRegularExpression(regex) { match, attributedString in
            attributedString.deleteCharactersInRange(match.rangeAtIndex(3))
            formattingBlock(attributedString, match.rangeAtIndex(2))
            attributedString.deleteCharactersInRange(match.rangeAtIndex(1))
        }
    }
    
    public func addMonospacedParsingWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Monospace, formattingBlock: formattingBlock)
    }
    
    public func addStrongParsingWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Strong, formattingBlock: formattingBlock)
    }
    
    public func addEmphasisParsingWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Emphasis, formattingBlock: formattingBlock)
    }
    
    public func addLinkDetectionWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        do {
            let linkDataDetector = try NSDataDetector(types: NSTextCheckingType.Link.rawValue)
            addParsingRuleWithRegularExpression(linkDataDetector) { match, attributedString in
                let linkURLString = (attributedString.string as NSString).substringWithRange(match.range)
                if let URL = NSURL(string: linkURLString) {
                    attributedString.addAttribute(NSLinkAttributeName, value: URL, range: match.range)
                }
                formattingBlock(attributedString, match.range)
            }
        } catch { }
    }
    
    private class func stringWithHexaString(hexaString: String, atIndex index: Int) -> String {
        let range = Range<String.Index>(start: hexaString.startIndex.advancedBy(index), end: hexaString.startIndex.advancedBy(index + 4))
        let sub = hexaString.substringWithRange(range)
        
        let char = Character(UnicodeScalar(Int(strtoul(sub, nil, 16))))
        return "\(char)"
    }
    
    public func addCodeUnescapingParsingWithFormattingBlock(formattingBlock: TSSwiftMarkdownParserFormattingBlock) {
        addMonospacedParsingWithFormattingBlock { attributedString, range in
            let matchString = attributedString.attributedSubstringFromRange(range).string
            var unescapedString = ""
            for index in 0..<range.length {
                guard index * 4 < range.length else { break }
                
                unescapedString = "\(unescapedString)\(TSSwiftMarkdownParser.stringWithHexaString(matchString, atIndex: index * 4))"
            }
            attributedString.replaceCharactersInRange(range, withString: unescapedString)
            formattingBlock(attributedString, NSRange(location: range.location, length: (unescapedString as NSString).length))
        }
    }
    
    public func addUnescapingParsing() {
        guard let unescapingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Unescaping, options: .DotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(unescapingRegex) { match, attributedString in
            let range = NSRange(location: match.range.location + 1, length: 4)
            let matchString = attributedString.attributedSubstringFromRange(range).string
            let unescapedString = TSSwiftMarkdownParser.stringWithHexaString(matchString, atIndex: 0)
            attributedString.replaceCharactersInRange(match.range, withString: unescapedString)
        }
    }
    
}