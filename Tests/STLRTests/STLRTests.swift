//
//  STLRTests.swift
//  OysterKitTests
//
//  Created  on 06/09/2017.
//  Copyright © 2017 RED When Excited. All rights reserved.
//

import Foundation

import XCTest
@testable import OysterKit
@testable import ExampleLanguages
@testable import STLR


class STLRTest: XCTestCase {
    
    func testBackslash(){
        let backSlash = ".backslash"
        
        let ruleSource = """
        id = \(backSlash) "x"
"""
        guard let testLanguage = STLRParser(source: ruleSource).ast.runtimeLanguage else {
            XCTFail("Could not compile")
            return
        }
        
        let source = "\\x"
        
        do {
            let ast = try AbstractSyntaxTreeConstructor().build(source, using: testLanguage)
            if ast.children.count != 0 {
                XCTFail("Expected one node, no children")
//                print(ast.description)
                return
            }
            XCTAssertEqual(ast.token.rawValue, 1)
        } catch {
            XCTFail("Parsing failed, but it should have succeeded")
        }
        
    }
    
    func testPinnedNodes(){
        enum TestToken : Int, Token{
            case pass
        }
        
        let ruleSource = """
            letters = .letter+
            digits = .decimalDigit+

            pass = letters " " @pin @token("numbers") digits?
"""

        let stlr = STLRParser(source: ruleSource)
        guard let testLanguage = stlr.ast.runtimeLanguage else {
            XCTFail("Compilation failed"); return
        }


//        print(stlr.ast.swift(grammar: "Test")!)
        
        var source = "abc 123"
        var ast = try! AbstractSyntaxTreeConstructor().build(source, using: testLanguage)
       
//        print(ast.description)
        
        XCTAssertNotNil(ast.children.first?.token , "Basic parsing did not work")

        source = "abc "
        ast = try! AbstractSyntaxTreeConstructor().build(source, using: testLanguage)
        
        XCTAssert(ast.children.first?.matchedString ?? "fail" == "abc" , "Letters node does not exist or contains the wrong value")

        
        
//        print("Done")
    }
    
    func testParseSelf(){
////        for bundle in Bundle.allBundles{
////            print("BUNDLE PATH: \(bundle)")
////        }
//        
//        if let _ = try? String(contentsOfFile: "/Volumes/Personal/SPM/OysterKit/Resources/STLR.stlr") {
//            let source = """
//            @void a = "a"
//            b = "b"
//            ab= a b
//            """
//            
//            let compiledScope = STLRScope(building: source)
//            
//            compiledScope.errors.forEach(){
//                XCTFail("\($0)")
//            }
//            
////            compiledScope.rules.forEach(){
////                print($0.description)
////            }
//            
////            print(compiledScope.swift(grammar: "Test")!)
//        } else {
//            XCTFail("Could not load source")
//        }

    }
    
    var allTests : [(()->Void)]{
        return [
            testParseSelf
        ]
    }
    
}

