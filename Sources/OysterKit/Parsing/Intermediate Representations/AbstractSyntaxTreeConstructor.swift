//    Copyright (c) 2016, RED When Excited
//    All rights reserved.
//
//    Redistribution and use in source and binary forms, with or without
//    modification, are permitted provided that the following conditions are met:
//
//    * Redistributions of source code must retain the above copyright notice, this
//    list of conditions and the following disclaimer.
//
//    * Redistributions in binary form must reproduce the above copyright notice,
//    this list of conditions and the following disclaimer in the documentation
//    and/or other materials provided with the distribution.
//
//    THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//    AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//    IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//    DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//    FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//    DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//    SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//    CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//    OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//    OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import Foundation

/**
 AbstractSyntaxTreeConstructor is an `IntermediateRepresentation` responsible for briding between the parsing results and an AbstractSyntaxTree.
 It encapsulates a parsing strategy that creates it's own lightweight homogenous representation of the parsed data. It can build into any
 ``AbstractSyntaxTree``, utilizing the `HomogenousTree` by default. In addition it can parse into a heterogenous abstract syntax tree represented by
 any Swift Type by utlizing the Swift Decoder framework to decode the intermediate representation into a decodable container structure.
 */
public class AbstractSyntaxTreeConstructor  {
    
    /// Errors that can occur during AST creation
    public enum ConstructionError : Error {
        /// Parsing failed before the AST could be constructed
        case parsingFailed(causes: [Error])
        
        /// One or more AST nodes could not be constructed
        case constructionFailed(causes: [Error])
        
        /// An error that is wholly unexpected, throwers should provide as much information as possible to guide
        /// developers to what may have gone wrong (at this point it's not something that will be meaningful to consumers
        case unknownError(message:String)
    }
    
    /**
     An entry in the tree.
     */
    public struct IntermediateRepresentationNode : Node {
        /// The token created
        public      let token       : Token
        /// The range of the match in the source string
        public      let range       : Range<String.UnicodeScalarView.Index>
        
        /// Children of this node
        public      let children       : [IntermediateRepresentationNode]
        
        /// Any associated annotations made on the `token`
        public      let annotations: [RuleAnnotation : RuleAnnotationValue]
        
        /**
         Creates a new instance with no `value`
         
         -Parameter for: The `Token` the node captures
         -Parameter at: The range the token was matched at in the original source string
         -Prameter annotations: Any annotations that should be stored with the node
         */
        public init(for token: Token, at range: Range<String.UnicodeScalarView.Index>, annotations:RuleAnnotations) {
            self.token = token
            self.range = range
            self.children = []
            self.annotations = annotations
        }
        
        /**
         Creates a new instance
         
         -Parameter for: The `Token` the node captures
         -Parameter at: The range the token was matched at in the original source string
         -Parameter children: Any child nodes of this node
         -Prameter annotations: Any annotations that should be stored with the node
         */
        public init(for token: Token, at range: Range<String.UnicodeScalarView.Index>, children:[IntermediateRepresentationNode], annotations:RuleAnnotations) {
            self.token = token
            self.range = range
            self.children = children
            self.annotations = annotations
        }
    }
    
    
    /// The original source string
    private var     source    : String!
    
    /// The original scalars view
    private var     scalars   : String.UnicodeScalarView!
    
    /// The context stack of nodes
    private var     nodeStack = NodeStack<IntermediateRepresentationNode>()
    
    /// The _errors collected during parsing
    internal var     _errors     = [Error]()
    
    /// The errors generated during parsing
    public  var     errors : [Error] {
        return _errors
    }
    
    //// A cache which can optionally be used
    fileprivate var cache : StateCache<String.UnicodeScalarView.Index, Int, MatchResult>?
    
    /// Creates a new instance, preparing to parse the supplied source
    public required init(){
    }
    
    /// Used for testing, creates a new blank instance for manipulation
    public init(with source:String){
        self.source = source
        self.scalars = source.unicodeScalars
    }
    
    /**
     Constructs a heterogenous AST by first constructing the specified DecodableAbstractSyntaxTree (meeting the requirements of the ``ParsingDecoder`` class).
     You typically do not need to use this method (where you are specifying your own AST to use) and you should consider
     ``build<T:Decodable>(_ heterogenousType:T.Type, from source: String, using language: Language)`` which will create a ``HomegenousTree`` which is very
     easy to use to decode into a concrete type.
     
     - Parameter heterogenousType: The ``Decodable`` Swift Type being constructed
     - Parameter using: The ``DecodableAbstractSyntaxTree`` to construct prior to decoding
     - Parameter from: The text to parse and build the tree from
     - Parameter using: The language to use to parse the source
     - Returns: An instance of a decodable type
     */
    public func build<T:Decodable, AST:DecodeableAbstractSyntaxTree>(_ heterogenousType:T.Type, using astType:AST.Type, from source: String, using language: Language) throws -> T{
        return try heterogenousType.decode(source, with: astType, using: language)
    }
    
    /**
     Creates a new empty cache. By default a cache is not used, but this can speed up processing of nodes where there can be
     a series of failures of evaluating a previous set of tokens before failing.
     
     - Parameter size The number of entries that can be cached
     */
    public func initializeCache(depth:Int, breadth: Int){
        cache = StateCache<String.UnicodeScalarView.Index, Int, MatchResult>(memorySize: depth, breadth: breadth)
    }
    
    /**
     Constructs a heterogenous AST by first constructing a ``HomogenousAbstractSyntaxTree`` which is then passed to the ``ParsingDecoder`` to leverage
     Swift's Decoder framework to create the heterogenous AST.
     
     - Parameter heterogenousType: The ``Decodable`` Swift Type being constructed
     - Parameter from: The text to parse and build the tree from
     - Parameter using: The language to use to parse the source
     - Returns: An instance of a decodable type
     */
    public func build<T:Decodable>(_ heterogenousType:T.Type, from source: String, using language: Language) throws -> T{
        return try build(heterogenousType, using: HomogenousTree.self, from: source, using: language)
    }
    
    /**
     Constructs a homogenous AST from the supplied source and language. You typically do not need to use this method (where you are
     specifying your own AST to use) and you should consider ``build(from source: String, using language: Language)`` which creates a
     ``HomegenousTree`` which is very easy to work with.
     
     - Parameter using: The ``AbstractSyntaxTree`` to construct
     - Parameter from: The text to parse and build the tree from
     - Parameter using: The language to use to parse the source
     - Returns: The ``AbstractSyntaxTree``
     */
    public func build<AST:AbstractSyntaxTree>(_ astType:AST.Type, from source: String, using language: Language) throws -> AST{
        self.source  = source
        self.scalars = source.unicodeScalars
        
        do {
            try ParsingStrategy.parse(source, using: language, with: Lexer.self, into: self)
            return try generate(astType)
        } catch {
            _errors.append(error)
            throw ConstructionError.constructionFailed(causes: _errors)
        }
    }
    
    /**
     Generates a homogenous AST based on the current state of the IR
     
     - Parameter using: The ``AbstractSyntaxTree`` to construct
     - Returns: The ``AbstractSyntaxTree``
     */
    func generate<AST:AbstractSyntaxTree>(_ astType:AST.Type) throws ->AST {
        do {
            let topNode : IntermediateRepresentationNode
            
            guard let topNodes = nodeStack.top?.nodes, topNodes.count > 0 else {
                _errors.append(LanguageError.parsingError(at: scalars.startIndex..<scalars.startIndex, message: "No nodes created"))
                throw ConstructionError.parsingFailed(causes: errors)
            }
            
            if topNodes.count > 1 {
                // Wrap it in a single node
                topNode = IntermediateRepresentationNode(for: LabelledToken(withLabel: "root"), at: topNodes.combinedRange, children: topNodes , annotations: [:])
            } else {
                topNode = topNodes[0]
            }
            return try AST(with: topNode, from: source)
        } catch {
            _errors.append(error)
            throw ConstructionError.constructionFailed(causes: _errors)
        }
    }
    
    /**
     Constructs a homogenous AST from the supplied source and language.
     
     - Parameter from: The text to parse and build the tree from
     - Parameter using: The language to use to parse the source
     - Returns: A ``HomogenousAbstractSyntaxTree``
     */
    public func build(_ source:String, using language:Language) throws -> HomogenousTree{
        return try build(HomogenousTree.self, from: source, using: language)
    }

}

//Adds the ability to quickly access standard annotations
extension Dictionary where Key == RuleAnnotation, Value == RuleAnnotationValue {
    var error : String? {
        if let error = self[.error] {
            if case let .string(message) = error {
                return message
            }
        }
        return nil
    }

    var pinned : Bool {
        if let value = self[.pinned] {
            if case .set = value {
                return true
            }
        }
        return false
    }

    
    var void : Bool {
        if let value = self[.void] {
            if case .set = value {
                return true
            }
        }
        return false
    }
    
    var transient : Bool {
        if let value = self[.transient] {
            if case .set = value {
                return true
            }
        }
        return false
    }
}

/**
 Provide the required implementation of the `IntermediateRepresentation` without exposing API consumers to it. This will enable more
 aggressive refactoring without code breaking changes
 */
extension AbstractSyntaxTreeConstructor : IntermediateRepresentation {

    
    /// Does nothing
    public func willBuildFrom(source: String, with: Language) {
    }
    
    /// Does nothing
    public func willEvaluate(rule: Rule, at position: String.UnicodeScalarView.Index) -> MatchResult? {
        return willEvaluate(token: rule.produces, at: position)
    }
    
    /// Prepare for evaluation
    public func willEvaluate(token: Token, at position: String.UnicodeScalarView.Index) -> MatchResult? {
        nodeStack.push()
        
        return cache?.recall(at: position, key: token.rawValue)
    }
    
    /// Process the results of evalution
    public func didEvaluate(token: Token, annotations: RuleAnnotations, matchResult: MatchResult) {
        let children = nodeStack.pop()
        
        cache?.remember(at: matchResult.range, key: token.rawValue, value: matchResult)
        
        switch matchResult {
        case .success(let context):
            // If it's transient, or the constructor produces no nodes then the current top should adopt the children
            /// TODO: Is this a defect (see github issue 24 https://github.com/SwiftStudies/OysterKit/issues/24)
            guard let node = match(token: token, annotations: annotations, context: context, children: children.nodes) else {
                nodeStack.top?.adopt(children.nodes)
                return
            }
            
            nodeStack.top?.append(node)
        case .ignoreFailure(let index):
            if let node = ignoreableFailure(token: token, annotations: annotations, index: index){
                nodeStack.top?.append(node)
            } else {
                nodeStack.top?.adopt(children.nodes)
            }
        case .failure(let index):
            //If we have an error on the rule
            if let error = annotations.error {
                let errorEnd = index < scalars.endIndex ? scalars.index(after:index) : index
                let parsingError = LanguageError.parsingError(at: index..<errorEnd, message: error)
                
                let existing = _errors.compactMap({ (error)->Error? in
                    if let error = error as? LanguageError {
                        if error == parsingError {
                            return error
                        }
                    }
                    return nil
                })
                
                if existing.count == 0{
                    _errors.append(parsingError)
                }
                
            }
            failed(token: token)
        case .consume:
            break
        }
    }
    
    /// Processes the results of evaluation
    public func didEvaluate(rule: Rule, matchResult: MatchResult) {
        let children = nodeStack.pop()

        if !rule.produces.transient {
            cache?.remember(at: matchResult.range, key: rule.produces.rawValue, value: matchResult)
        }
        
        switch matchResult {
        case .success(let context):
            //If the rule is void return nothing, don't add to range
            if rule.void {
                return
            }
            
            // If it's transient, or the constructor produces no nodes then the current top should adopt the children
            /// TODO: Is this a defect (see github issue 24 https://github.com/SwiftStudies/OysterKit/issues/24)
            guard let node = match(token: rule.produces, annotations: rule.annotations, context: context, children: children.nodes) else {
                nodeStack.top?.adopt(children.nodes)
                return
            }
            
            nodeStack.top?.append(node)
        case .ignoreFailure(let index):
            if let node = ignoreableFailure(token: rule.produces, annotations: rule.annotations, index: index){
                nodeStack.top?.append(node)
            } else {
                nodeStack.top?.adopt(children.nodes)
            }
        case .failure(let index):
            //If we have an error on the rule
            if let error = rule.error {
                let errorEnd = index < scalars.endIndex ? scalars.index(after:index) : index
                let parsingError = LanguageError.parsingError(at: index..<errorEnd, message: error)
                
                let existing = _errors.compactMap({ (error)->Error? in
                    if let error = error as? LanguageError {
                        if error == parsingError {
                            return error
                        }
                    }
                    return nil
                })
                
                if existing.count == 0{
                    _errors.append(parsingError)
                }
                
            }
            failed(token: rule.produces)
        case .consume:
            break
        }
    }
    
    /// Does nothing
    public func didBuild() {
        
    }
    
    /// Does nothing
    public func resetState() {
        
    }
    
    /**
     If the token is transient `nil` is returned. Otherwise the behaviour is determined by the number of children
     
     - 0: A new instance of `HeterogeneousNode` is created and returned
     - 1: Providing the token is not @pin'd a new `HeterogeousNode` is created for the child's range and value and returned If it is @pin'd behaviour falls through to
     - _n_: Return a new `HeterogeneousNode` with the combined range of all children and the children are set as the node's value
     
     - Parameter token: The token that has been successfully identified in the source
     - Parameter annotations: The annotations that had been marked on this instance of the token
     - Parameter context: The `LexicalContext` from the `LexicalAnalyzer` from which an implementation can extract the matched range.
     - Parameter children: Any `Node`s that were created while this token was being evaluated.
     - Returns: Any `Node` that was created, or `nil` if not
     */
    final public func match(token: Token, annotations:RuleAnnotations, context: LexicalContext, children: [IntermediateRepresentationNode]) -> IntermediateRepresentationNode? {
        
        switch children.count{
        case 0:
            return IntermediateRepresentationNode(for: token, at: context.range,  annotations: annotations)
        default:
            // Creates a new parent node with the transients filtered out, but their range included
            return IntermediateRepresentationNode(for: token, at: children.combinedRange, children: children.perpetual, annotations: annotations)
        }
    }
    
    /**
     If the token is not transient but is pinned a node is created with a range at the current scan-head but no value. Otherwise `nil` is returned.
     
     - Parameter token: The token that failed to be matched identified in the source
     - Parameter annotations: The annotations that had been marked on this instance of the token
     - Returns: Any `Node` that was created, or `nil` if not
     */
    public func ignoreableFailure(token: Token, annotations: [RuleAnnotation : RuleAnnotationValue], index: String.UnicodeScalarView.Index)->IntermediateRepresentationNode? {
        if !token.transient && annotations[RuleAnnotation.pinned] != nil{
            let range = index..<index
            return IntermediateRepresentationNode(for: token, at: range, annotations: annotations)
        }
        return nil
    }
    
    /// No behaviour
    public func failed(token: Token) {
        
    }
}
