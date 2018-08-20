//
//  ParserTest.swift
//  OysterKit
//
//  
//  Copyright © 2016 RED When Excited. All rights reserved.
//

import XCTest
@testable import OysterKit

fileprivate enum QuotedEscapedStringTestTokens : Int, Token {
    case escapedQuote,quote,character,string
}



fileprivate enum Tokens : Int, Token {
    case whitespace
    case whitespaces
    case dummy
    case letter
    case word
    case greeting
    case fullStop
    case punctuationCharacters
    case whitespaceWord
    case optionalWhitespaceWord
    case repeatedOptionalWhitespaceWord
    case sentance
    case questionMark
    case exlamationMark
    case endOfSentance
    
    var rule: Rule {
        switch self {
        case .dummy:
            return ParserRule.terminal(produces: self, "😁",nil)
        case .whitespace:
            return ParserRule.terminalFrom(produces: self, CharacterSet.whitespaces,nil)
        case .whitespaces:
            return ParserRule.repeated(produces: self, Tokens.whitespace.rule,min: 1, limit: nil,nil)
        case .letter:
            return ParserRule.terminalFrom(produces: self, CharacterSet.letters,nil)
        case .word:
            return ParserRule.repeated(produces: self, Tokens.letter.rule, min: 1, limit: nil,nil)
        case .punctuationCharacters:
            return ParserRule.terminalFrom(produces: self, CharacterSet.punctuationCharacters,nil)
        case .whitespaceWord:
            return ParserRule.sequence(produces: self, [Tokens.whitespaces.rule,Tokens.word.rule],nil)
        case .optionalWhitespaceWord:
            return ParserRule.optional(produces: self, Tokens.whitespaceWord.rule,nil)
        case .repeatedOptionalWhitespaceWord:
            return ParserRule.repeated(produces: self, Tokens.optionalWhitespaceWord.rule, min: nil, limit: nil,nil)
        case .fullStop:
            return ParserRule.terminal(produces: self, ".",nil)
        case .questionMark:
            return ParserRule.terminal(produces: self, "?",nil)
        case .exlamationMark:
            return ParserRule.terminal(produces: self, "!",nil)
        case .endOfSentance:
            return ParserRule.oneOf(produces: self, [
                Tokens.fullStop.rule,
                Tokens.questionMark.rule,
                Tokens.exlamationMark.rule,
                ],nil)
        case .greeting:
            return ParserRule.terminal(produces:self, "Hello",nil)
        case .sentance:
            return ParserRule.sequence(produces: self, [
                Tokens.word.rule,
                Tokens.repeatedOptionalWhitespaceWord.rule,
                Tokens.endOfSentance.rule
                ],nil)
        }
    }
}

class ParserTest: XCTestCase {

    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    @discardableResult
    private func check(_ source:String, produces output: [Token], using rules:[Rule], expectingEndOfInput:Bool? = nil)->[Error]{
        let debugOutput = true
        let parser = TestParser(source: source, grammar: rules)
        
        let tokenIterator       = parser.makeIterator()
        var expectationIterator = output.makeIterator()
        
        defer {
            if debugOutput {
                print("Debugging:")
                print("\tSource: \(source)")
                print("\tLanguage: \(rules.reduce("", {(previous,current)->String in return previous+"\n\t\t\(current)"}))")
                print("Output:")
                do {
                    print(try AbstractSyntaxTreeConstructor().build(source, using: TestLanguage(grammar:rules)).description)
                } catch {
                    print("Errors: \(error)")
                }
            }
        }
        
        while let token = tokenIterator.next() {
            guard let expected = expectationIterator.next() else {
                XCTFail("More tokens generated than expected, overflowed with \(token)")
                return []
            }
            
            XCTAssert(expected == token.token, "Incorrect token \(token), expecting \(expected)")
        }
        
        if let nextpectation = expectationIterator.next(){
            XCTFail("Not all tokens generated, stopped before \(nextpectation) because of \(tokenIterator.parsingErrors)")
        }
        
        if let expectingEndOfInput = expectingEndOfInput {
            XCTAssert(expectingEndOfInput == tokenIterator.reachedEndOfInput, expectingEndOfInput ? "Expected end of input" : "Unexpected end of input")
        }
        
        return tokenIterator.parsingErrors
    }
    
    func testRepatedOptional(){
        check(" hello world", produces: [Tokens.repeatedOptionalWhitespaceWord], using: [Tokens.repeatedOptionalWhitespaceWord.rule], expectingEndOfInput: true)
    }

    func testRuleOptional(){
        check(" hello world", produces: [
                Tokens.optionalWhitespaceWord,
                Tokens.optionalWhitespaceWord
            ], using: [
                Tokens.optionalWhitespaceWord.rule
            ], expectingEndOfInput: true)
        
        
        check("hello", produces: [], using:[Tokens.optionalWhitespaceWord.rule], expectingEndOfInput: false)
    }
    
    func testOptionalNegative(){
        let pling = ParserRule.terminal(produces: Tokens.exlamationMark, "!",nil)
        let optional = ParserRule.optional(produces: Tokens.exlamationMark, pling, nil)
        
        let parser = TestParser(source: "?", grammar: [optional])
        
        XCTAssert(parser.makeIterator().next() == nil)
    }
    
    func testConsumption(){
        
//        check("are", produces:[], using: ["are".consume])

//        check("areyou", produces:[Tokens.word], using: ["are".consume, Tokens.word.rule])
        
        
        check("Where are you???", produces: [Tokens.word,Tokens.word], using: [
            -"are",
            Tokens.word.rule,
            -CharacterSet.whitespaces,
            -CharacterSet(charactersIn: "?").require(.oneOrMore),
            ])
    }
    
    func testComplexSequence(){
        check("How are you?", produces: [Tokens.sentance], using: [Tokens.sentance.rule], expectingEndOfInput: true)
    }
    
    func testRuleSequence(){
        check(" hello", produces: [Tokens.whitespaceWord], using: [Tokens.whitespaceWord.rule], expectingEndOfInput: true)
        check("hello", produces: [], using: [Tokens.whitespaceWord.rule], expectingEndOfInput: false)
    }
    
    func testRuleTerminal(){
        check(".",produces:[Tokens.fullStop], using: [Tokens.fullStop.rule], expectingEndOfInput: true)
        XCTAssert(check(",",produces:[], using: [Tokens.fullStop.rule], expectingEndOfInput: false).count == 1,"Expected an error")
        check("Hello Hello", produces: [
            Tokens.greeting,
            Tokens.whitespaces,
            Tokens.greeting,
            ], using: [
                Tokens.greeting.rule,
                Tokens.whitespaces.rule,
            ], expectingEndOfInput: true)
        
    }
    
    func testQuotedEscapedStringParsing(){
        let escapedCharacter = ["\\".parse(as: QuotedEscapedStringTestTokens.character), [
                "'".parse(as: QuotedEscapedStringTestTokens.character),
                "\\".parse(as: QuotedEscapedStringTestTokens.character),
            ].choice.parse(as: QuotedEscapedStringTestTokens.character)
            ].sequence.parse(as: QuotedEscapedStringTestTokens.character)
        let stringCharacters = [[
                escapedCharacter,
                !"'".parse(as: QuotedEscapedStringTestTokens.quote),
            ].choice.parse(as: QuotedEscapedStringTestTokens.character)].sequence.require(.oneOrMore).parse(as: QuotedEscapedStringTestTokens.string)
        
        let string = [
            -"'".parse(as: QuotedEscapedStringTestTokens.quote),
            stringCharacters,
            -"'".parse(as: QuotedEscapedStringTestTokens.quote),
            ].sequence.parse(as: QuotedEscapedStringTestTokens.string)
        
        let source = "'\\\\'"
        
        var count = 0
        
        let parser = Parser(grammar: [string])
        
        
        for node in TokenStream(source, using: parser){
            count += 1
            XCTAssert(node.token == QuotedEscapedStringTestTokens.string)
            let capturedString = String(source[node.range])
            XCTAssertEqual(String(source.dropFirst().dropLast()),capturedString)
        }
        
        XCTAssert(count == 1, "Got \(count) tokens")
        
    }
    
    func testRuleTerminalFrom(){
        check("Hello", produces: Array<Token>(repeating:Tokens.letter, count:5), using: [Tokens.letter.rule], expectingEndOfInput: true)
    }
    
    func testRuleSimpleRepeat(){
        check("Hello", produces: [Tokens.word], using: [Tokens.word.rule], expectingEndOfInput: true)
    }
    
    func testSingleRuleFailure(){
        check("Hello", produces: [Tokens.word], using: [Tokens.whitespace.rule, Tokens.word.rule], expectingEndOfInput: true )
    }
    
    func testAllRuleFailure(){
        let errors = check("Hello", produces: [], using: [Tokens.whitespace.rule, Tokens.exlamationMark.rule], expectingEndOfInput: false )
        
        if let parsingError = errors.first {
            if case AbstractSyntaxTreeConstructor.ConstructionError.parsingFailed(let errors) = parsingError {
                XCTAssertEqual(2, errors.count)
            }
        }
        
    }
}
