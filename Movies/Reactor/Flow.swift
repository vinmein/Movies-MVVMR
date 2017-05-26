//
//  Flow.swift
//  Movies
//
//  Created by Göksel Köksal on 22/05/2017.
//  Copyright © 2017 GK. All rights reserved.
//

import Foundation

struct FlowNavigation {
    
    enum Direction {
        case forward
        case backward
    }
    
    unowned let source: AnyFlow
    let destination: AnyFlow
    let direction: Direction
    
    init(source: AnyFlow, destination: AnyFlow, direction: Direction = .forward) {
        self.source = source
        self.destination = destination
        self.direction = direction
    }
}

protocol Dispatcher {
    func dispatch(_ action: Action)
    func dispatch<C: Command>(_ command: C)
}

final class Coordinator: Dispatcher {
    
    private(set) var flows: [AnyFlow]
    let navigationTree: Tree<AnyFlow>
    private(set) var middlewares: [Middleware]
    private let jobQueue = DispatchQueue(label: "flow.queue", qos: .userInitiated, attributes: [])
    
    init(rootFlow: AnyFlow, middlewares: [Middleware] = []) {
        self.navigationTree = Tree(rootFlow)
        self.middlewares = middlewares
        rootFlow.coordinator = self
    }
    
    func dispatch(_ action: Action) {
        jobQueue.async {
            self.willProcess(action)
            if let cleanUpAction = action as? RemoveFlowAction {
                if let index = self.flows.index(where: { $0 === cleanUpAction.flow }) {
                    self.flows.remove(at: index)
                }
            } else {
                for flow in self.flows {
                    if let navigation = flow.process(action) {
                        navigationTree.search(navigation.source, compareBlock: { $0 === $1 })?.add(navigation.destination)
//                        navigationTree.search(navigation.source)?.add(navigation.destination)
                    }
                    if let destination = flow.process(action)?.destination {
                        destination.coordinator = self
                        self.flows.append(destination)
                    }
                }
            }
            self.didProcess(action)
        }
    }
    
    func dispatch<C: Command>(_ command: C) {
        jobQueue.async {
            for flow in self.flows {
                if let specificFlow = flow as? Flow<C.StateType> {
                    command.execute(on: specificFlow, coordinator: self)
                }
            }
        }
    }
    
    private func willProcess(_ action: Action) {
        middlewares.forEach { $0.willProcess(action) }
    }
    
    private func didProcess(_ action: Action) {
        middlewares.forEach { $0.didProcess(action) }
    }
}

// MARK: Flow

protocol AnyFlow: class {
    weak var coordinator: Coordinator? { get set }
    var router: Router? { get }
    func process(_ action: Action) -> FlowNavigation?
}

class Flow<StateType: State>: AnyFlow {
    
    weak var coordinator: Coordinator?
    private(set) var state: StateType
    let router: Router?
    
    private let jobQueue = DispatchQueue(label: "flow.queue", qos: .userInitiated, attributes: [])
    private let subscriptionsSyncQueue = DispatchQueue(label: "flow.subscription.sync")
    
    private var _subscriptions: [Subscription] = []
    private var subscriptions: [Subscription] {
        get {
            return subscriptionsSyncQueue.sync {
                return self._subscriptions
            }
        }
        set {
            subscriptionsSyncQueue.sync {
                self._subscriptions = newValue
            }
        }
    }
    
    init(state: StateType, router: Router? = nil) {
        self.state = state
        self.router = router
    }
    
    func process(_ action: Action) -> FlowNavigation? {
        if let segue = action as? Segue {
            let destination = self.router?.perform(segue)
            self.notifySubscribers(with: destination)
            return destination
        } else {
            self.state.react(to: action)
            self.notifySubscribers(with: self.state)
            return nil
        }
    }
    
    func subscribe<S: Subscriber>(_ subscriber: S, on queue: DispatchQueue = .main) where S.StateType == StateType {
        jobQueue.sync {
            guard !self.subscriptions.contains(where: { $0.subscriber === subscriber }) else { return }
            let subscription = Subscription(subscriber: subscriber, queue: queue)
            self.subscriptions.append(subscription)
        }
    }
    
    func unsubscribe<S: Subscriber>(_ subscriber: S) where S.StateType == StateType {
        if let subscriptionIndex = subscriptions.index(where: { $0.subscriber === subscriber }) {
            subscriptions.remove(at: subscriptionIndex)
        }
    }
    
    private func notifySubscribers(with newState: StateType) {
        forEachSubscription { $0.notify(with: newState) }
    }
    
    private func notifySubscribers(with navigation: FlowNavigation?) {
        guard let navigation = navigation else { return }
        forEachSubscription { $0.notify(with: navigation) }
    }
    
    private func forEachSubscription(_ block: (Subscription) -> Void) {
        subscriptions = subscriptions.filter { $0.subscriber != nil }
        for subscription in subscriptions {
            block(subscription)
        }
    }
}

extension Flow: Dispatcher {
    
    func dispatch(_ action: Action) {
        coordinator?.dispatch(action)
    }
    
    func dispatch<C>(_ command: C) where C : Command {
        coordinator?.dispatch(command)
    }
}

// MARK: Actions

protocol Action { }
protocol Segue: Action { }

struct RemoveFlowAction: Action {
    let flow: AnyFlow
    
    init(_ flow: AnyFlow) {
        self.flow = flow
    }
}

// MARK: Command

protocol Command {
    associatedtype StateType: State
    func execute(on flow: Flow<StateType>, coordinator: Coordinator)
}

// MARK: Router

protocol Router {
    func perform(_ segue: Segue) -> FlowNavigation?
}

// MARK: Subscriber

protocol FlowNavigationPerformer {
    func perform(_ navigation: FlowNavigation)
}

protocol AnySubscriber: class, FlowNavigationPerformer {
    func _update(with state: State)
}

protocol Subscriber: AnySubscriber {
    associatedtype StateType: State
    func update(with state: StateType)
}

extension Subscriber {
    func _update(with state: State) {
        guard let state = state as? StateType else { return }
        update(with: state)
    }
}

struct Subscription {
    
    private(set) weak var subscriber: AnySubscriber?
    let queue: DispatchQueue
    
    fileprivate func notify(with newState: State) {
        queue.async {
            self.subscriber?._update(with: newState)
        }
    }
    
    fileprivate func notify(with navigation: FlowNavigation) {
        queue.async {
            self.subscriber?.perform(navigation: navigation)
        }
    }
}

// MARK: State

protocol State {
    mutating func react(to action: Action)
}

// MARK: Middleware

protocol Middleware {
    func willProcess(_ action: Action)
    func didProcess(_ action: Action)
}

