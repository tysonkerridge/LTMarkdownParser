//
//  LTMarkdownParser.swift
//  LTMarkdownParser
//
//  Created by Rhett Rogers on 3/24/16.
//  Copyright © 2016 CocoaPods. All rights reserved.
//

import Foundation
import UIKit

private let nonBreakingSpaceCharacter = Character("\u{00A0}")

public struct TSSwiftMarkdownRegex {
    public static let CodeEscaping = "(?<!\\\\)(?:\\\\\\\\)*+(`+)(.*?[^`].*?)(\\1)(?!`)"
    public static let Escaping = "\\\\."
    public static let Unescaping = "\\\\[0-9a-z]{4}"
    
    public static let Header = "^(#{1,%@})\\s+(.+)$"
    public static let ShortHeader = "^(#{1,%@})\\s*([^#].*)$"
    public static let List = "^( {0,%@})[\\*\\+\\-]\\s+(.+)$"
    public static let ShortList = "^( {0,%@})[\\*\\+\\-]\\s+([^\\*\\+\\-].*)$"
    public static let NumberedList = "^( {0,})[0-9]+\\.\\s(.+)$"
    public static let Quote = "^(\\>{1,%@})\\s*(.+)$"
    public static let ShortQuote = "^(\\>{1,%@})\\s*([^\\>].*)$"
    
    public static let Image = "\\!\\[[^\\[]*?\\]\\(\\S*\\)"
    public static let Link = "\\[[^\\[]*?\\]\\([^\\)]*\\)"
    
    public static let Monospace = "(`+)(\\s*.*?[^`]\\s*)(\\1)(?!`)"
    public static let Strong = "(\\*\\*|__)(.+?)(\\1)"
    public static let Emphasis = "(\\*|_)(.+?)(\\1)"
    public static let StrongAndEmphasis = "(((\\*\\*\\*)(.|\\s)*(\\*\\*\\*))|((___)(.|\\s)*(___)))"
    
    public static func regexForString(_ regexString: String, options: NSRegularExpression.Options = []) -> NSRegularExpression? {
        do {
            return try NSRegularExpression(pattern: regexString, options: options)
        } catch {
            return nil
        }
    }
}

open class LTMarkdownParser: TSBaseParser {
    
    public typealias LTMarkdownParserFormattingBlock = ((NSMutableAttributedString, NSRange) -> Void)
    public typealias LTMarkdownParserLevelFormattingBlock = ((NSMutableAttributedString, NSRange, Int) -> Void)
    
    open var headerAttributes = [[NSAttributedString.Key: Any]]()
    open var listAttributes = [[NSAttributedString.Key: Any]]()
    open var numberedListAttributes = [[NSAttributedString.Key: Any]]()
    open var quoteAttributes = [[NSAttributedString.Key: Any]]()
    
    open var imageAttributes = [NSAttributedString.Key: Any]()
    open var linkAttributes = [NSAttributedString.Key: Any]()
    open var monospaceAttributes = [NSAttributedString.Key: Any]()
    open var strongAttributes = [NSAttributedString.Key: Any]()
    open var emphasisAttributes = [NSAttributedString.Key: Any]()
    open var strongAndEmphasisAttributes = [NSAttributedString.Key: Any]()
    
    public static var standardParser = LTMarkdownParser()
    
    class func addAttributes(_ attributesArray: [[NSAttributedString.Key: Any]], atIndex level: Int, toString attributedString: NSMutableAttributedString, range: NSRange) {
        guard !attributesArray.isEmpty else { return }
        
        guard let newAttributes = level < attributesArray.count && level >= 0 ? attributesArray[level] : attributesArray.last else { return }
        
        attributedString.addAttributes(newAttributes, range: range)
    }
    
    public init(withDefaultParsing: Bool = true) {
        super.init()
        
        defaultAttributes = [.font: UIFont.systemFont(ofSize: 12), .paragraphStyle: NSParagraphStyle()]
        headerAttributes = [
            [.font: UIFont.boldSystemFont(ofSize: 23)],
            [.font: UIFont.boldSystemFont(ofSize: 21)],
            [.font: UIFont.boldSystemFont(ofSize: 19)],
            [.font: UIFont.boldSystemFont(ofSize: 17)],
            [.font: UIFont.boldSystemFont(ofSize: 15)],
            [.font: UIFont.boldSystemFont(ofSize: 13)]
        ]
        
        linkAttributes = [
            .foregroundColor: UIColor.blue,
            .underlineStyle: NSUnderlineStyle.single.rawValue as AnyObject
        ]
        
        monospaceAttributes = [
            .font: UIFont(name: "Menlo", size: 12) ?? UIFont.systemFont(ofSize: 12),
            .foregroundColor: UIColor(red: 0.95, green: 0.54, blue: 0.55, alpha: 1)
        ]
        
        strongAttributes = [.font: UIFont.boldSystemFont(ofSize: 12)]
        emphasisAttributes = [.font: UIFont.italicSystemFont(ofSize: 12)]
        
        var strongAndEmphasisFont = UIFont.systemFont(ofSize: 12)
        strongAndEmphasisFont = UIFont(descriptor: strongAndEmphasisFont.fontDescriptor.withSymbolicTraits([.traitItalic, .traitBold])!, size: strongAndEmphasisFont.pointSize)
        strongAndEmphasisAttributes = [.font: strongAndEmphasisFont]
        
        if withDefaultParsing {
            addCodeEscapingParsing()
            addEscapingParsing()
            
            addNumberedListParsingWithLeadFormattingBlock({ (attributedString, range, level) in
                LTMarkdownParser.addAttributes(self.numberedListAttributes, atIndex: level - 1, toString: attributedString, range: range)
                let substring = attributedString.attributedSubstring(from: range).string.replacingOccurrences(of: " ", with: "\(nonBreakingSpaceCharacter)")
                attributedString.replaceCharacters(in: range, with: "\(substring)")
            }, textFormattingBlock: { attributedString, range, level in
                LTMarkdownParser.addAttributes(self.numberedListAttributes, atIndex: level - 1, toString: attributedString, range: range)
            })
            
            addHeaderParsingWithLeadFormattingBlock({ attributedString, range, level in
                attributedString.replaceCharacters(in: range, with: "")
            }, textFormattingBlock: { attributedString, range, level in
                LTMarkdownParser.addAttributes(self.headerAttributes, atIndex: level - 1, toString: attributedString, range: range)
            })
            
            addListParsingWithLeadFormattingBlock({ attributedString, range, level in
                LTMarkdownParser.addAttributes(self.listAttributes, atIndex: level - 1, toString: attributedString, range: range)
                let indentString = String(repeating: String(nonBreakingSpaceCharacter), count: level)
                attributedString.replaceCharacters(in: range, with: "\(indentString)\u{2022}\u{00A0}")
            }, textFormattingBlock: { attributedString, range, level in
                LTMarkdownParser.addAttributes(self.listAttributes, atIndex: level - 1, toString: attributedString, range: range)
            })
            
            addQuoteParsingWithLeadFormattingBlock({ attributedString, range, level in
                let indentString = String(repeating: "\t", count: level)
                attributedString.replaceCharacters(in: range, with: indentString)
            }, textFormattingBlock: { attributedString, range, level in
                LTMarkdownParser.addAttributes(self.quoteAttributes, atIndex: level - 1, toString: attributedString, range: range)
            })
            
            addImageParsingWithImageFormattingBlock(nil) { attributedString, range in
                attributedString.addAttributes(self.imageAttributes, range: range)
            }
            
            addLinkParsingWithFormattingBlock { attributedString, range in
                attributedString.addAttributes(self.linkAttributes, range: range)
            }
            
            addLinkDetectionWithFormattingBlock { attributedString, range in
                attributedString.addAttributes(self.linkAttributes, range: range)
            }
            
            addStrongParsingWithFormattingBlock { attributedString, range in
                attributedString.enumerateAttributes(in: range, options: []) { attributes, range, _ in
                    if let font = attributes[.font] as? UIFont, let italicFont = self.emphasisAttributes[.font] as? UIFont, font == italicFont {
                        attributedString.addAttributes(self.strongAndEmphasisAttributes, range: range)
                    } else {
                        attributedString.addAttributes(self.strongAttributes, range: range)
                    }
                }
            }
            
            addEmphasisParsingWithFormattingBlock { attributedString, range in
                attributedString.enumerateAttributes(in: range, options: []) { attributes, range, _ in
                    if let font = attributes[.font] as? UIFont, let boldFont = self.strongAttributes[.font] as? UIFont, font == boldFont {
                        attributedString.addAttributes(self.strongAndEmphasisAttributes, range: range)
                    } else {
                        attributedString.addAttributes(self.emphasisAttributes, range: range)
                    }
                }
            }
            
            addStrongAndEmphasisParsingWithFormattingBlock { attributedString, range in
                attributedString.addAttributes(self.strongAndEmphasisAttributes, range: range)
            }
            
            addCodeUnescapingParsingWithFormattingBlock { attributedString, range in
                attributedString.addAttributes(self.monospaceAttributes, range: range)
            }
            
            addUnescapingParsing()
        }
    }
    
    open func addEscapingParsing() {
        guard let escapingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Escaping) else { return }
        
        addParsingRuleWithRegularExpression(escapingRegex) { match, attributedString in
            let range = NSRange(location: match.range.location + 1, length: 1)
            let matchString = attributedString.attributedSubstring(from: range).string as NSString
            let escapedString = NSString(format: "%04x", matchString.character(at: 0)) as String
            attributedString.replaceCharacters(in: range, with: escapedString)
        }
    }
    
    open func addCodeEscapingParsing() {
        guard let codingParsingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.CodeEscaping, options: .dotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(codingParsingRegex) { match, attributedString in
            let range = match.range(at: 2)
            let matchString = attributedString.attributedSubstring(from: range).string as NSString
            
            var escapedString = ""
            for index in 0..<range.length {
                escapedString = "\(escapedString)\(NSString(format: "%04x", matchString.character(at: index)))"
            }

            attributedString.replaceCharacters(in: range, with: escapedString)
        }
    }
    
    fileprivate func addLeadParsingWithPattern(_ pattern: String, maxLevel: Int?, leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        let regexString: String = {
            let maxLevel: Int = maxLevel ?? 0
            return NSString(format: pattern as NSString, maxLevel > 0 ? "\(maxLevel)" : "") as String
        }()
        
        guard let regex = TSSwiftMarkdownRegex.regexForString(regexString, options: .anchorsMatchLines) else { return }
        
        addParsingRuleWithRegularExpression(regex) { match, attributedString in
            let level = match.range(at: 1).length
            formattingBlock?(attributedString, match.range(at: 2), level)
            leadFormattingBlock(attributedString, NSRange(location: match.range(at: 1).location, length: match.range(at: 2).location - match.range(at: 1).location), level)
        }
    }
    
    open func addHeaderParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.Header, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addListParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.List, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addNumberedListParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.NumberedList, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addQuoteParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.Quote, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addShortHeaderParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortHeader, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addShortListParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortList, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addShortQuoteParsingWithLeadFormattingBlock(_ leadFormattingBlock: @escaping LTMarkdownParserLevelFormattingBlock, maxLevel: Int? = nil, textFormattingBlock formattingBlock: LTMarkdownParserLevelFormattingBlock?) {
        addLeadParsingWithPattern(TSSwiftMarkdownRegex.ShortQuote, maxLevel: maxLevel, leadFormattingBlock: leadFormattingBlock, formattingBlock: formattingBlock)
    }
    
    open func addImageParsingWithImageFormattingBlock(_ formattingBlock: LTMarkdownParserFormattingBlock?, alternativeTextFormattingBlock alternateFormattingBlock: LTMarkdownParserFormattingBlock?) {
        guard let headerRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Image, options: .dotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(headerRegex) { match, attributedString in
            let imagePathStart = (attributedString.string as NSString).range(of: "(", options: [], range: match.range).location
            let linkRange = NSRange(location: imagePathStart, length: match.range.length + match.range.location - imagePathStart - 1)
            let imagePath = (attributedString.string as NSString).substring(with: NSRange(location: linkRange.location + 1, length: linkRange.length - 1))
            
            if let image = UIImage(named: imagePath) {
                let imageAttatchment = NSTextAttachment()
                imageAttatchment.image = image
                imageAttatchment.bounds = CGRect(x: 0, y: -5, width: image.size.width, height: image.size.height)
                let imageString = NSAttributedString(attachment: imageAttatchment)
                attributedString.replaceCharacters(in: match.range, with: imageString)
                formattingBlock?(attributedString, NSRange(location: match.range.location, length: imageString.length))
            } else {
                let linkTextEndLocation = (attributedString.string as NSString).range(of: "]", options: [], range: match.range).location
                let linkTextRange = NSRange(location: match.range.location + 2, length: linkTextEndLocation - match.range.location - 2)
                let alternativeText = (attributedString.string as NSString).substring(with: linkTextRange)
                attributedString.replaceCharacters(in: match.range, with: alternativeText)
                alternateFormattingBlock?(attributedString, NSRange(location: match.range.location, length: (alternativeText as NSString).length))
            }
        }
    }
    
    open func addLinkParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        guard let linkRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Link, options: .dotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(linkRegex) { [weak self] match, attributedString in
            let linkStartinResult = (attributedString.string as NSString).range(of: "(", options: .backwards, range: match.range).location
            let linkRange = NSRange(location: linkStartinResult, length: match.range.length + match.range.location - linkStartinResult - 1)
            let linkUrlString = (attributedString.string as NSString).substring(with: NSRange(location: linkRange.location + 1, length: linkRange.length - 1))
            
            let linkTextRange = NSRange(location: match.range.location + 1, length: linkStartinResult - match.range.location - 2)
            attributedString.deleteCharacters(in: NSRange(location: linkRange.location - 1, length: linkRange.length + 2))
            
            if let linkUrlString = self?.unescaped(string: linkUrlString), let url = URL(string: linkUrlString) ?? URL(string: linkUrlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? linkUrlString) {
                attributedString.addAttribute(.link, value: url, range: linkTextRange)
            }
            formattingBlock(attributedString, linkTextRange)
            
            attributedString.deleteCharacters(in: NSRange(location: match.range.location, length: 1))
        }
    }
    
    /// - Parameter insertAtFront: Whether its inserted at the beginning of the array of rules rather than appended to the end. Defaults to false (added to end).
    fileprivate func addEnclosedParsingWithPattern(_ pattern: String, insertAtFront: Bool = false, formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        guard let regex = TSSwiftMarkdownRegex.regexForString(pattern, options: .dotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(regex, insertAtFront: insertAtFront) { match, attributedString in
            attributedString.deleteCharacters(in: match.range(at: 3))
            formattingBlock(attributedString, match.range(at: 2))
            attributedString.deleteCharacters(in: match.range(at: 1))
        }
    }
    
    open func addMonospacedParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Monospace, formattingBlock: formattingBlock)
    }
    
    open func addStrongParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Strong, formattingBlock: formattingBlock)
    }
    
    open func addEmphasisParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.Emphasis, formattingBlock: formattingBlock)
    }
    
    open func addStrongAndEmphasisParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.StrongAndEmphasis, formattingBlock: formattingBlock)
    }
    
    open func addLinkDetectionWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        do {
            let linkDataDetector = try NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
            addParsingRuleWithRegularExpression(linkDataDetector) { [weak self] match, attributedString in
                if let urlString = match.url?.absoluteString.removingPercentEncoding, let unescapedUrlString = self?.unescaped(string: urlString), let url = URL(string: unescapedUrlString) {
                    attributedString.addAttribute(.link, value: url, range: match.range)
                }
                formattingBlock(attributedString, match.range)
            }
        } catch { }
    }
    
    func unescaped(string: String) -> String? {
        guard let unescapingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Unescaping, options: .dotMatchesLineSeparators) else { return nil }
        
        var location = 0
        let unescapedMutableString = NSMutableString(string: string)
        while let match = unescapingRegex.firstMatch(in: unescapedMutableString as String, options: .withoutAnchoringBounds, range: NSRange(location: location, length: unescapedMutableString.length - location)) {
            let oldLength = unescapedMutableString.length
            let range = NSRange(location: match.range.location + 1, length: 4)
            let matchString = unescapedMutableString.substring(with: range)
            let unescapedString = LTMarkdownParser.stringWithHexaString(matchString, atIndex: 0)
            unescapedMutableString.replaceCharacters(in: match.range, with: unescapedString)
            let newLength = unescapedMutableString.length
            location = match.range.location + match.range.length + newLength - oldLength
        }
        
        return unescapedMutableString as String
    }
    
    fileprivate class func stringWithHexaString(_ hexaString: String, atIndex index: Int) -> String {
        let range = hexaString.index(hexaString.startIndex, offsetBy: index)..<hexaString.index(hexaString.startIndex, offsetBy: index + 4)
        let sub = String(hexaString[range])
        
        let char = Character(UnicodeScalar(Int(strtoul(sub, nil, 16)))!)
        return "\(char)"
    }
    
    open func addCodeUnescapingParsingWithFormattingBlock(_ formattingBlock: @escaping LTMarkdownParserFormattingBlock) {
        addEnclosedParsingWithPattern(TSSwiftMarkdownRegex.CodeEscaping) { attributedString, range in
            let matchString = attributedString.attributedSubstring(from: range).string
            var unescapedString = ""
            for index in 0..<range.length {
                guard index * 4 < range.length else { break }
                
                unescapedString = "\(unescapedString)\(LTMarkdownParser.stringWithHexaString(matchString, atIndex: index * 4))"
            }
            attributedString.replaceCharacters(in: range, with: unescapedString)
            formattingBlock(attributedString, NSRange(location: range.location, length: (unescapedString as NSString).length))
        }
    }
    
    open func addUnescapingParsing() {
        guard let unescapingRegex = TSSwiftMarkdownRegex.regexForString(TSSwiftMarkdownRegex.Unescaping, options: .dotMatchesLineSeparators) else { return }
        
        addParsingRuleWithRegularExpression(unescapingRegex) { match, attributedString in
            let range = NSRange(location: match.range.location + 1, length: 4)
            let matchString = attributedString.attributedSubstring(from: range).string
            let unescapedString = LTMarkdownParser.stringWithHexaString(matchString, atIndex: 0)
            attributedString.replaceCharacters(in: match.range, with: unescapedString)
        }
    }
    
}
