//
//  NavigationNode.swift
//  Movies
//
//  Created by Goksel Koksal on 26/05/2017.
//  Copyright © 2017 GK. All rights reserved.
//

import Foundation

public class Tree<T> {
    
    public typealias CompareBlock = (T, T) -> Bool
    
    public class Node {
        public let value: T
        public var children: [Node] = []
        public weak var parent: Node?
        
        public init(_ value: T) {
            self.value = value
        }
        
        public var isLeaf: Bool {
            return children.count == 0
        }
        
        public func add(_ child: Node) {
            child.parent = self
            children.append(child)
        }
        
        public func add(_ childValue: T) {
            let child = Node(childValue)
            child.parent = self
            children.append(child)
        }
    }
    
    public var root: Node
    
    public init(_ rootValue: T) {
        self.root = Node(rootValue)
    }
    
    public init(_ root: Node) {
        self.root = root
    }
    
    public func search(_ value: T, compareBlock: CompareBlock) -> Node? {
        return Tree.node(for: value, root: root, compareBlock: compareBlock)
    }
    
    @discardableResult
    public func remove(_ value: T, compareBlock: CompareBlock) -> Bool {
        let node = search(value, compareBlock: compareBlock)
        if let parent = node?.parent {
            if let index = parent.children.index(where: { compareBlock($0.value, value) }) {
                parent.children.remove(at: index)
                return true
            }
        }
        return false
    }
    
    private static func node(for value: T, root: Node, compareBlock: CompareBlock) -> Node? {
        if compareBlock(root.value, value) {
            return root
        } else {
            for child in root.children {
                if let result = node(for: value, root: child, compareBlock: compareBlock) {
                    return result
                }
            }
            return nil
        }
    }
}

public extension Tree where T: AnyObject {
    
    static var defaultCompareBlock: CompareBlock {
        return { $0 === $1 }
    }
    
    func search(_ value: T) -> Node? {
        return search(value, compareBlock: Tree.defaultCompareBlock)
    }
    
    @discardableResult
    func remove(_ value: T) -> Bool {
        return remove(value, compareBlock: Tree.defaultCompareBlock)
    }
}

public extension Tree where T: Equatable {
    
    static var defaultCompareBlock: CompareBlock {
        return { $0 == $1 }
    }
    
    func search(_ value: T) -> Node? {
        return search(value, compareBlock: Tree.defaultCompareBlock)
    }
    
    @discardableResult
    func remove(_ value: T) -> Bool {
        return remove(value, compareBlock: Tree.defaultCompareBlock)
    }
}

extension Tree: CustomStringConvertible {
    public var description: String {
        return root.description
    }
}

extension Tree.Node: CustomStringConvertible {
    public var description: String {
        if isLeaf {
            return "{ \(value) }"
        }
        var string = "{ \(value): "
        string += children.map { "\($0)" }.joined(separator: " | ")
        string += " }"
        return string
    }
}
