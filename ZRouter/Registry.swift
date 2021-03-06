
//
//  Router.swift
//  ZRouter
//
//  Created by zuik on 2017/10/16.
//  Copyright © 2017 zuik. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

import ZIKRouter.Internal
import ZIKRouter.Private

internal let SHOULD_CHECK_ROUTER_IMPLEMENTATION = ZIKROUTER_CHECK == 1

extension Protocol {
    var name: String {
        var name = NSStringFromProtocol(self)
        if let dotRange = name.range(of: ".") {
            name.removeSubrange(name.startIndex...dotRange.lowerBound)
        }
        return name
    }
}

///Key of registered protocol.
internal struct _RouteKey: Hashable {
    fileprivate let type: Any.Type?
    fileprivate let key: String
    internal init(type: Any.Type) {
        self.type = type
        key = String(describing:type)
        assert(key.contains(".") == false, "Key shouldn't contain module prefix.")
    }
    fileprivate init(type: AnyClass) {
        self.type = type
        key = String(describing:type)
        assert(key.contains(".") == false, "Key shouldn't contain module prefix.")
    }
    fileprivate init(route: Any) {
        self.type = nil
        key = String(describing:route)
    }
    fileprivate init(protocol p: Protocol) {
        self.type = nil
        key = p.name
        assert(key.contains(".") == false, "Remove module prefix for swift type.")
    }
    fileprivate init(key: String) {
        type = nil
        self.key = key
        assert(key.contains(".") == false, "Remove module prefix for swift type.")
    }
    fileprivate init?(routerType: ZIKAnyViewRouterType) {
        assert(routerType.routerClass != nil || routerType.route != nil)
        if let routerClass = routerType.routerClass {
            self.init(type: routerClass)
        } else if let route = routerType.route {
            self.init(route: route)
        } else {
            return nil
        }
    }
    fileprivate init?(routerType: ZIKAnyServiceRouterType) {
        assert(routerType.routerClass != nil || routerType.route != nil)
        if let routerClass = routerType.routerClass {
            self.init(type: routerClass)
        } else if let route = routerType.route {
            self.init(route: route)
        } else {
            return nil
        }
    }
    var hashValue: Int {
        return key.hashValue
    }
    static func ==(lhs: _RouteKey, rhs: _RouteKey) -> Bool {
        return lhs.key == rhs.key
    }
}

///Registry for registering pure Swift protocol and discovering ZIKRouter subclass.
internal class Registry {
    /// value: subclass of ZIKViewRouter or ZIKViewRoute
    fileprivate static var viewProtocolContainer = [_RouteKey: Any]()
    /// value: subclass of ZIKViewRouter or ZIKViewRoute
    fileprivate static var viewModuleProtocolContainer = [_RouteKey: Any]()
    /// key: adapter view protocol  value: adaptee view protocol
    fileprivate static var viewAdapterContainer = [_RouteKey: _RouteKey]()
    /// key: adapter view module protocol  value: adaptee view module protocol
    fileprivate static var viewModuleAdapterContainer = [_RouteKey: _RouteKey]()
    /// value: subclass of ZIKServiceRouter or ZIKServiceRoute
    fileprivate static var serviceProtocolContainer = [_RouteKey: Any]()
    /// value: subclass of ZIKServiceRouter or ZIKServiceRoute
    fileprivate static var serviceModuleProtocolContainer = [_RouteKey: Any]()
    /// key: adapter service protocol  value: adaptee service protocol
    fileprivate static var serviceAdapterContainer = [_RouteKey: _RouteKey]()
    /// key: adapter service module protocol  value: adaptee service module protocol
    fileprivate static var serviceModuleAdapterContainer = [_RouteKey: _RouteKey]()
    /// key: subclass of ZIKViewRouter or ZIKViewRoute  value: set of routable view protocols
    fileprivate static var _check_viewProtocolContainer = [_RouteKey: Set<_RouteKey>]()
    /// key: subclass of ZIKServiceRouter or ZIKServiceRoute  value: set of routable service protocols
    fileprivate static var _check_serviceProtocolContainer = [_RouteKey: Set<_RouteKey>]()
    
    // MARK: Register
    
    /// Register pure Swift protocol or objc protocol for view with a ZIKViewRouter subclass. Router will check whether the registered view protocol is conformed by the registered view.
    ///
    /// - Parameters:
    ///   - routableView: A routabe entry carrying a protocol conformed by the view of the router. Can be pure Swift protocol or objc protocol.
    ///   - router: The subclass of ZIKViewRouter.
    internal static func register<Protocol>(_ routableView: RoutableView<Protocol>, forRouter router: AnyClass) {
        guard let router = router as? ZIKAnyViewRouter.Type else {
            assertionFailure("This router must be subclass of ZIKViewRouter")
            return
        }
        let destinationProtocol = Protocol.self
        assert(ZIKAnyViewRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        assert(ZIKRouter_classIsSubclassOfClass(router, ZIKAnyViewRouter.self), "This router must be subclass of ZIKViewRouter")
        // `UIViewController & ObjcProtocol` type is also a Protocol in objc, but we want to keep it in swift container
        if let routableProtocol = _routableViewProtocolFromObject(destinationProtocol), String(describing: Protocol.self) == routableProtocol.name {
            router.registerViewProtocol(routableProtocol)
            return
        }
        assert(viewProtocolContainer[_RouteKey(type:destinationProtocol)] == nil, "view protocol (\(destinationProtocol)) was already registered with router (\(String(describing: viewProtocolContainer[_RouteKey(type:destinationProtocol)]))).")
        if SHOULD_CHECK_ROUTER_IMPLEMENTATION {
            _addToCheckList(viewProtocol: destinationProtocol, toRouter: router)
        }
        viewProtocolContainer[_RouteKey(type:destinationProtocol)] = router
    }
    
    /// Register pure Swift protocol or objc protocol for your custom configuration with a ZIKViewRouter subclass. Router will check whether the registered config protocol is conformed by the defaultRouteConfiguration of the router.
    ///
    /// - Parameters:
    ///   - routableViewModule: A routabe entry carrying a protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - router: The subclass of ZIKViewRouter.
    internal static func register<Protocol>(_ routableViewModule: RoutableViewModule<Protocol>, forRouter router: AnyClass) {
        guard let router = router as? ZIKAnyViewRouter.Type else {
            assertionFailure("This router must be subclass of ZIKViewRouter")
            return
        }
        let configProtocol = Protocol.self
        assert(ZIKAnyViewRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        assert(ZIKRouter_classIsSubclassOfClass(router, ZIKAnyViewRouter.self), "This router must be subclass of ZIKViewRouter")
        if let routableProtocol = _routableViewModuleProtocolFromObject(configProtocol), String(describing: Protocol.self) == routableProtocol.name {
            router.registerModuleProtocol(routableProtocol)
            return
        }
        assert(router.defaultRouteConfiguration() is Protocol, "The router (\(router))'s default configuration must conform to the config protocol (\(configProtocol)) to register.")
        assert(viewModuleProtocolContainer[_RouteKey(type:configProtocol)] == nil, "view config protocol (\(configProtocol)) was already registered with router (\(String(describing: viewModuleProtocolContainer[_RouteKey(type:configProtocol)]))).")
        viewModuleProtocolContainer[_RouteKey(type:configProtocol)] = router
    }
    
    /// Register pure Swift protocol or objc protocol for your service with a ZIKServiceRouter subclass. Router will check whether the registered service protocol is conformed by the registered service.
    ///
    /// - Parameters:
    ///   - routableService: A routabe entry carrying a protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - router: The subclass of ZIKServiceRouter.
    internal static func register<Protocol>(_ routableService: RoutableService<Protocol>, forRouter router: AnyClass) {
        guard let router = router as? ZIKAnyServiceRouter.Type else {
            assertionFailure("This router must be subclass of ZIKServiceRouter")
            return
        }
        let destinationProtocol = Protocol.self
        assert(ZIKAnyServiceRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        assert(ZIKRouter_classIsSubclassOfClass(router, ZIKAnyServiceRouter.self), "This router must be subclass of ZIKServiceRouter")
        if let routableProtocol = _routableServiceProtocolFromObject(destinationProtocol), String(describing: Protocol.self) == routableProtocol.name {
            router.registerServiceProtocol(routableProtocol)
            return
        }
        assert(serviceProtocolContainer[_RouteKey(type:destinationProtocol)] == nil, "service protocol (\(destinationProtocol)) was already registered with router (\(String(describing: serviceProtocolContainer[_RouteKey(type:destinationProtocol)]))).")
        if SHOULD_CHECK_ROUTER_IMPLEMENTATION {
            _addToCheckList(serviceProtocol: destinationProtocol, toRouter: router)
        }
        serviceProtocolContainer[_RouteKey(type:destinationProtocol)] = router
    }
    
    /// Register pure Swift protocol or objc protocol for your custom configuration with a ZIKServiceRouter subclass.  Router will check whether the registered config protocol is conformed by the defaultRouteConfiguration of the router.
    ///
    /// - Parameters:
    ///   - routableServiceModule: A routabe entry carrying a module config protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - router: The subclass of ZIKServiceRouter.
    internal static func register<Protocol>(_ routableServiceModule: RoutableServiceModule<Protocol>, forRouter router: AnyClass) {
        guard let router = router as? ZIKAnyServiceRouter.Type else {
            assertionFailure("This router must be subclass of ZIKServiceRouter")
            return
        }
        let configProtocol = Protocol.self
        assert(ZIKAnyServiceRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        assert(ZIKRouter_classIsSubclassOfClass(router, ZIKAnyServiceRouter.self), "This router must be subclass of ZIKServiceRouter")
        if let routableProtocol = _routableServiceModuleProtocolFromObject(configProtocol), String(describing: Protocol.self) == routableProtocol.name {
            router.registerModuleProtocol(routableProtocol)
            return
        }
        assert(router.defaultRouteConfiguration() is Protocol, "The router (\(router))'s default configuration must conform to the config protocol (\(configProtocol)) to register.")
        assert(serviceModuleProtocolContainer[_RouteKey(type:configProtocol)] == nil, "service config protocol (\(configProtocol)) was already registered with router (\(String(describing: serviceModuleProtocolContainer[_RouteKey(type:configProtocol)]))).")
        serviceModuleProtocolContainer[_RouteKey(type:configProtocol)] = router
    }
    
    /// Register pure Swift protocol or objc protocol for view with a ZIKViewRoute. Router will check whether the registered view protocol is conformed by the registered view.
    ///
    /// - Parameters:
    ///   - routableView: A routabe entry carrying a protocol conformed by the view of the router. Can be pure Swift protocol or objc protocol.
    ///   - route: A ZIKViewRoute.
    internal static func register<Protocol>(_ routableView: RoutableView<Protocol>, forRoute route: Any) {
        guard let route = route as? ZIKAnyViewRoute else {
            assertionFailure("This route must be ZIKAnyViewRoute")
            return
        }
        let destinationProtocol = Protocol.self
        assert(ZIKAnyViewRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        if let routableProtocol = _routableViewProtocolFromObject(destinationProtocol), String(describing: Protocol.self) == routableProtocol.name {
            _ = route.registerDestinationProtocol(routableProtocol)
            return
        }
        assert(viewProtocolContainer[_RouteKey(type:destinationProtocol)] == nil, "view protocol (\(destinationProtocol)) was already registered with router (\(String(describing: viewProtocolContainer[_RouteKey(type:destinationProtocol)]))).")
        if SHOULD_CHECK_ROUTER_IMPLEMENTATION {
            _addToCheckList(viewProtocol: destinationProtocol, toRoute: route)
        }
        viewProtocolContainer[_RouteKey(type:destinationProtocol)] = route
    }
    
    /// Register pure Swift protocol or objc protocol for your custom configuration with a ZIKViewRoute. Router will check whether the registered config protocol is conformed by the defaultRouteConfiguration of the router.
    ///
    /// - Parameters:
    ///   - routableViewModule: A routabe entry carrying a protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - route: A ZIKViewRoute.
    internal static func register<Protocol>(_ routableViewModule: RoutableViewModule<Protocol>, forRoute route: Any) {
        guard let route = route as? ZIKAnyViewRoute else {
            assertionFailure("This route must be ZIKAnyViewRoute")
            return
        }
        let configProtocol = Protocol.self
        assert(ZIKAnyViewRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        if let routableProtocol = _routableViewModuleProtocolFromObject(configProtocol), String(describing: Protocol.self) == routableProtocol.name {
            _ = route.registerModuleProtocol(routableProtocol)
            return
        }
        assert(viewModuleProtocolContainer[_RouteKey(type:configProtocol)] == nil, "view config protocol (\(configProtocol)) was already registered with router (\(String(describing: viewModuleProtocolContainer[_RouteKey(type:configProtocol)]))).")
        viewModuleProtocolContainer[_RouteKey(type:configProtocol)] = route
    }
    
    /// Register pure Swift protocol or objc protocol for your service with a ZIKServiceRoute. Router will check whether the registered service protocol is conformed by the registered service.
    ///
    /// - Parameters:
    ///   - routableService: A routabe entry carrying a protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - route: A ZIKServiceRoute.
    internal static func register<Protocol>(_ routableService: RoutableService<Protocol>, forRoute route: Any) {
        guard let route = route as? ZIKAnyServiceRoute else {
            assertionFailure("This route must be ZIKAnyServiceRoute")
            return
        }
        let destinationProtocol = Protocol.self
        assert(ZIKAnyServiceRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        if let routableProtocol = _routableServiceProtocolFromObject(destinationProtocol), String(describing: Protocol.self) == routableProtocol.name {
            _ = route.registerDestinationProtocol(routableProtocol)
            return
        }
        assert(serviceProtocolContainer[_RouteKey(type:destinationProtocol)] == nil, "service protocol (\(destinationProtocol)) was already registered with router (\(String(describing: serviceProtocolContainer[_RouteKey(type:destinationProtocol)]))).")
        if SHOULD_CHECK_ROUTER_IMPLEMENTATION {
            _addToCheckList(serviceProtocol: destinationProtocol, toRoute: route)
        }
        serviceProtocolContainer[_RouteKey(type:destinationProtocol)] = route
    }
    
    /// Register pure Swift protocol or objc protocol for your custom configuration with a ZIKServiceRoute. Router will check whether the registered config protocol is conformed by the defaultRouteConfiguration of the router.
    ///
    /// - Parameters:
    ///   - routableServiceModule: A routabe entry carrying a module config protocol conformed by the custom configuration of the router. Can be pure Swift protocol or objc protocol.
    ///   - route: A ZIKServiceRoute.
    internal static func register<Protocol>(_ routableServiceModule: RoutableServiceModule<Protocol>, forRoute route: Any) {
        guard let route = route as? ZIKAnyServiceRoute else {
            assertionFailure("This route must be ZIKAnyServiceRoute")
            return
        }
        let configProtocol = Protocol.self
        assert(ZIKAnyServiceRouter.isRegistrationFinished() == false, "Can't register after app did finish launch. Only register in registerRoutableDestination().")
        if let routableProtocol = _routableServiceModuleProtocolFromObject(configProtocol), String(describing: Protocol.self) == routableProtocol.name {
            _ = route.registerModuleProtocol(routableProtocol)
            return
        }
        assert(serviceModuleProtocolContainer[_RouteKey(type:configProtocol)] == nil, "service config protocol (\(configProtocol)) was already registered with router (\(String(describing: serviceModuleProtocolContainer[_RouteKey(type:configProtocol)]))).")
        serviceModuleProtocolContainer[_RouteKey(type:configProtocol)] = route
    }
    
    internal static func register<Adapter, Adaptee>(adapter: RoutableView<Adapter>, forAdaptee adaptee: RoutableView<Adaptee>) {
        let adapterKey = _RouteKey(type: Adapter.self)
        let objcAdapter = _routableViewProtocolFromObject(Adapter.self)
        let objcAdaptee = _routableViewProtocolFromObject(Adaptee.self)
        if let objcAdapter = objcAdapter, let objcAdaptee = objcAdaptee,
            String(describing: Adapter.self) == objcAdapter.name,
            String(describing: Adaptee.self) == objcAdaptee.name {
            assert(viewProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: viewProtocolContainer[adapterKey])))")
            assert(viewAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(viewAdapterContainer[adapterKey]!.key))")
            ZIKViewRouteRegistry.registerDestinationAdapter(objcAdapter, forAdaptee: objcAdaptee)
            return
        }
        assert(viewProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: viewProtocolContainer[adapterKey])))")
        assert(viewAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(viewAdapterContainer[adapterKey]!.key))")
        viewAdapterContainer[adapterKey] = _RouteKey(type: Adaptee.self)
    }
    
    internal static func register<Adapter, Adaptee>(adapter: RoutableViewModule<Adapter>, forAdaptee adaptee: RoutableViewModule<Adaptee>) {
        let adapterKey = _RouteKey(type: Adapter.self)
        let objcAdapter = _routableViewModuleProtocolFromObject(Adapter.self)
        let objcAdaptee = _routableViewModuleProtocolFromObject(Adaptee.self)
        if let objcAdapter = objcAdapter, let objcAdaptee = objcAdaptee,
            String(describing: Adapter.self) == objcAdapter.name,
            String(describing: Adaptee.self) == objcAdaptee.name {
            assert(viewModuleProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: viewModuleProtocolContainer[adapterKey])))")
            assert(viewModuleAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(viewModuleAdapterContainer[adapterKey]!.key))")
            ZIKViewRouteRegistry.registerModuleAdapter(objcAdapter, forAdaptee: objcAdaptee)
            return
        }
        assert(viewModuleProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: viewModuleProtocolContainer[adapterKey])))")
        assert(viewModuleAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(viewModuleAdapterContainer[adapterKey]!.key))")
        viewModuleAdapterContainer[adapterKey] = _RouteKey(type: Adaptee.self)
    }
    
    internal static func register<Adapter, Adaptee>(adapter: RoutableService<Adapter>, forAdaptee adaptee: RoutableService<Adaptee>) {
        let adapterKey = _RouteKey(type: Adapter.self)
        let objcAdapter = _routableServiceProtocolFromObject(Adapter.self)
        let objcAdaptee = _routableServiceProtocolFromObject(Adaptee.self)
        if let objcAdapter = objcAdapter, let objcAdaptee = objcAdaptee,
            String(describing: Adapter.self) == objcAdapter.name,
            String(describing: Adaptee.self) == objcAdaptee.name {
            assert(serviceProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: serviceProtocolContainer[adapterKey])))")
            assert(serviceAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(serviceAdapterContainer[adapterKey]!.key))")
            ZIKServiceRouteRegistry.registerDestinationAdapter(objcAdapter, forAdaptee: objcAdaptee)
            return
        }
        assert(serviceProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: serviceProtocolContainer[adapterKey])))")
        assert(serviceAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(serviceAdapterContainer[adapterKey]!.key))")
        serviceAdapterContainer[adapterKey] = _RouteKey(type: Adaptee.self)
    }
    
    internal static func register<Adapter, Adaptee>(adapter: RoutableServiceModule<Adapter>, forAdaptee adaptee: RoutableServiceModule<Adaptee>) {
        let adapterKey = _RouteKey(type: Adapter.self)
        let objcAdapter = _routableServiceModuleProtocolFromObject(Adapter.self)
        let objcAdaptee = _routableServiceModuleProtocolFromObject(Adaptee.self)
        if let objcAdapter = objcAdapter, let objcAdaptee = objcAdaptee,
            String(describing: Adapter.self) == objcAdapter.name,
            String(describing: Adaptee.self) == objcAdaptee.name {
            assert(serviceModuleProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: serviceModuleProtocolContainer[adapterKey])))")
            assert(serviceModuleAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(serviceModuleAdapterContainer[adapterKey]!.key))")
            ZIKServiceRouteRegistry.registerModuleAdapter(objcAdapter, forAdaptee: objcAdaptee)
            return
        }
        assert(serviceModuleProtocolContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) is already registered with a router (\(String(describing: serviceModuleProtocolContainer[adapterKey])))")
        assert(serviceModuleAdapterContainer[adapterKey] == nil, "Adapter (\(Adapter.self)) can't register adaptee (\(Adaptee.self)), already register another adaptee (\(serviceModuleAdapterContainer[adapterKey]!.key))")
        serviceModuleAdapterContainer[adapterKey] = _RouteKey(type: Adaptee.self)
    }
    
    // MARK: Check
    
    private static func _addToCheckList(viewProtocol: Any.Type, toRouter router: ZIKAnyViewRouter.Type) {
        var protocols = _check_viewProtocolContainer[_RouteKey(type: router.self)]
        if protocols == nil {
            protocols = Set()
            protocols?.insert(_RouteKey(type:viewProtocol))
        } else {
            protocols?.insert(_RouteKey(type:viewProtocol))
        }
        _check_viewProtocolContainer[_RouteKey(type: router.self)] = protocols
    }
    
    
    private static func _addToCheckList(serviceProtocol: Any.Type, toRouter router: ZIKAnyServiceRouter.Type) {
        var protocols = _check_serviceProtocolContainer[_RouteKey(type: router.self)]
        if protocols == nil {
            protocols = Set()
            protocols?.insert(_RouteKey(type:serviceProtocol))
        } else {
            protocols?.insert(_RouteKey(type:serviceProtocol))
        }
        _check_serviceProtocolContainer[_RouteKey(type: router.self)] = protocols
    }
    
    private static func _addToCheckList(viewProtocol: Any.Type, toRoute route: ZIKAnyViewRoute) {
        var protocols = _check_viewProtocolContainer[_RouteKey(route: route)]
        if protocols == nil {
            protocols = Set()
            protocols?.insert(_RouteKey(type:viewProtocol))
        } else {
            protocols?.insert(_RouteKey(type:viewProtocol))
        }
        _check_viewProtocolContainer[_RouteKey(route: route)] = protocols
    }
    
    
    private static func _addToCheckList(serviceProtocol: Any.Type, toRoute route: ZIKAnyServiceRoute) {
        var protocols = _check_serviceProtocolContainer[_RouteKey(route: route)]
        if protocols == nil {
            protocols = Set()
            protocols?.insert(_RouteKey(type:serviceProtocol))
        } else {
            protocols?.insert(_RouteKey(type:serviceProtocol))
        }
        _check_serviceProtocolContainer[_RouteKey(route: route)] = protocols
    }
}

extension ZIKViewRouteRegistry {
    @objc class func _swiftRouteForDestinationAdapter(_ adapter: Protocol) -> Any? {
        let adaptee = Registry.viewAdapterContainer[_RouteKey(protocol: adapter)]
        var route: Any?
        repeat {
            guard let adaptee = adaptee else {
                return nil
            }
            route = Registry.viewProtocolContainer[adaptee]
        } while route == nil
        return route
    }
    
    @objc class func _swiftRouteForModuleAdapter(_ adapter: Protocol) -> Any? {
        let adaptee = Registry.viewModuleAdapterContainer[_RouteKey(protocol: adapter)]
        var route: Any?
        repeat {
            guard let adaptee = adaptee else {
                return nil
            }
            route = Registry.viewModuleProtocolContainer[adaptee]
        } while route == nil
        return route
    }
}

extension ZIKServiceRouteRegistry {
    @objc class func _swiftRouteForDestinationAdapter(_ adapter: Protocol) -> Any? {
        let adaptee = Registry.serviceAdapterContainer[_RouteKey(protocol: adapter)]
        var route: Any?
        repeat {
            guard let adaptee = adaptee else {
                return nil
            }
            route = Registry.serviceProtocolContainer[adaptee]
        } while route == nil
        return route
    }
    
    @objc class func _swiftRouteForModuleAdapter(_ adapter: Protocol) -> Any? {
        let adaptee = Registry.serviceModuleAdapterContainer[_RouteKey(protocol: adapter)]
        var route: Any?
        repeat {
            guard let adaptee = adaptee else {
                return nil
            }
            route = Registry.serviceModuleProtocolContainer[adaptee]
        } while route == nil
        return route
    }
}

// MARK: Routable Discover
internal extension Registry {
    
    /// Get view router type for registered view protocol.
    ///
    /// - Parameter routableView: A routabe entry carrying a view protocol conformed by the view registered with a view router. Support objc protocol and pure Swift protocol.
    /// - Returns: The view router type for the view protocol.
    internal static func router<Destination>(to routableView: RoutableView<Destination>) -> ViewRouterType<Destination, ViewRouteConfig>? {
        let routerType = _router(toView: Destination.self)
        if let routerType = routerType {
            return ViewRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get view router type for registered view module config protocol.
    ///
    /// - Parameter routableViewModule: A routabe entry carrying a view module config protocol registered with a view router. Support objc protocol and pure Swift protocol.
    /// - Returns: The view router type for the config protocol.
    internal static func router<Module>(to routableViewModule: RoutableViewModule<Module>) -> ViewRouterType<Any, Module>? {
        let routerType = _router(toViewModule: Module.self)
        if let routerType = routerType {
            return ViewRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get service router type for registered service protocol.
    ///
    /// - Parameter routableService: A routabe entry carrying a service protocol conformed by the service registered with a service router. Support objc protocol and pure Swift protocol.
    /// - Returns: The service router type for the service protocol.
    internal static func router<Destination>(to routableService: RoutableService<Destination>) -> ServiceRouterType<Destination, PerformRouteConfig>? {
        let routerType = _router(toService: Destination.self)
        if let routerType = routerType {
            return ServiceRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get service router type for registered servie module config protocol.
    ///
    /// - Parameter routableServiceModule: A routabe entry carrying a cconfg protocol registered with a service router. Support objc protocol and pure Swift protocol.
    /// - Returns: The service router type for the config protocol.
    internal static func router<Module>(to routableServiceModule: RoutableServiceModule<Module>) -> ServiceRouterType<Any, Module>? {
        let routerType = _router(toServiceModule: Module.self)
        if let routerType = routerType {
            return ServiceRouterType(routerType: routerType)
        }
        return nil
    }
}

// MARK: Switchable Discover

internal extension Registry {
    
    /// Get view router type for switchable registered view protocol, when the destination view is switchable from some view protocols.
    ///
    /// - Parameter switchableView: A struct carrying any routable view protocol, but not a specified one.
    /// - Returns: The view router type for the view protocol.
    internal static func router(to switchableView: SwitchableView) -> ViewRouterType<Any, ViewRouteConfig>? {
        let routerType = _router(toView: switchableView.routableProtocol)
        if let routerType = routerType {
            return ViewRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get view router type for switchable registered view module protocol, when the destination view is switchable from some view module protocols.
    ///
    /// - Parameter switchableViewModule: A struct carrying any routable view module config protocol, but not a specified one.
    /// - Returns: The view router type for the view module config protocol.
    internal static func router(to switchableViewModule: SwitchableViewModule) -> ViewRouterType<Any, ViewRouteConfig>? {
        let routerType = _router(toViewModule: switchableViewModule.routableProtocol)
        if let routerType = routerType {
            return ViewRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get service router type for switchable registered service protocol, when the destination service is switchable from some service protocols.
    ///
    /// - Parameter switchableService: A struct carrying any routable service protocol, but not a specified one.
    /// - Returns: The service router type for the service protocol.
    internal static func router(to switchableService: SwitchableService) -> ServiceRouterType<Any, PerformRouteConfig>? {
        let routerType = _router(toService: switchableService.routableProtocol)
        if let routerType = routerType {
            return ServiceRouterType(routerType: routerType)
        }
        return nil
    }
    
    /// Get service router type for switchable registered service module config protocol, when the destination service is switchable from some service module protocols.
    ///
    /// - Parameter switchableServiceModule: A struct carrying any routable service module config protocol, but not a specified one.
    /// - Returns: The service router type for the service module config protocol.
    internal static func router(to switchableServiceModule: SwitchableServiceModule) -> ServiceRouterType<Any, PerformRouteConfig>? {
        let routerType = _router(toServiceModule: switchableServiceModule.routableProtocol)
        if let routerType = routerType {
            return ServiceRouterType(routerType: routerType)
        }
        return nil
    }
}

// MARK: Type Discover

fileprivate extension Registry {
    
    /// Get view router class for registered view protocol.
    ///
    /// - Parameter routableView: A routabe entry carrying a view protocol conformed by the view registered with a view router. Support objc protocol and pure Swift protocol.
    /// - Returns: The view router class for the view protocol.
    fileprivate static func _router(toView viewProtocol: Any.Type) -> ZIKAnyViewRouterType? {
        if let routerType = _swiftRouter(toViewRouteKey: _RouteKey(type:viewProtocol)) {
            return routerType
        }
        if let routableProtocol = _routableViewProtocolFromObject(viewProtocol), let routerType = _ZIKViewRouterToView(routableProtocol) {
            return routerType
        }
        if _routableViewProtocolFromObject(viewProtocol) == nil {
            ZIKAnyViewRouter
                .notifyGlobalError(
                    with: nil,
                    action: .toView,
                    error: ZIKAnyViewRouter.routeError(withCode:.invalidProtocol, localizedDescription:"Swift view protocol (\(viewProtocol)) was not registered with any view router."))
            assertionFailure("Swift view protocol (\(viewProtocol)) was not registered with any view router.")
        }
        return nil
    }
    fileprivate static func _swiftRouter(toViewRouteKey routeKey: _RouteKey) -> ZIKAnyViewRouterType? {
        assert(routeKey.type != nil)
        if let route = viewProtocolContainer[routeKey], let routerType = ZIKAnyViewRouterType.tryMakeType(forRoute: route) {
            return routerType
        }
        #if DEBUG
        var traversedProtocols: [_RouteKey] = []
        #endif
        var adapter = routeKey
        var adaptee: _RouteKey?
        repeat {
            adaptee = viewAdapterContainer[adapter]
            if let adaptee = adaptee {
                if let route = viewProtocolContainer[adaptee], let routerType = ZIKAnyViewRouterType.tryMakeType(forRoute: route) {
                    return routerType
                }
                if let destinationProtocol = routeKey.type, let routableProtocol = _routableViewProtocolFromObject(destinationProtocol), let routerType = _ZIKViewRouterToView(routableProtocol) {
                    return routerType
                }
                #if DEBUG
                traversedProtocols.append(adapter)
                if traversedProtocols.contains(adaptee) {
                    let adapterChain = traversedProtocols.reduce("") { (r, e) -> String in
                        return r + "\(e.key) -> "
                    }
                    assertionFailure("Dead cycle in destination adapter -> adaptee chain: \(adapterChain + adaptee.key). Check your register(adapter:forAdaptee:).")
                    break
                }
                #endif
                adapter = adaptee
            }
        } while adaptee != nil
        return nil
    }
    
    /// Get view router class for registered config protocol.
    ///
    /// - Parameter routableViewModule: A routabe entry carrying a view module config protocol registered with a view router. Support objc protocol and pure Swift protocol.
    /// - Returns: The view router class for the config protocol.
    fileprivate static func _router(toViewModule configProtocol: Any.Type) -> ZIKAnyViewRouterType? {
        if let routerType = _swiftRouter(toViewModuleRouteKey: _RouteKey(type:configProtocol)) {
            return routerType
        }
        if let routableProtocol = _routableViewModuleProtocolFromObject(configProtocol), let routerType = _ZIKViewRouterToModule(routableProtocol) {
            return routerType
        }
        
        if _routableViewModuleProtocolFromObject(configProtocol) == nil {
            ZIKAnyViewRouter
                .notifyGlobalError(
                    with: nil,
                    action: .toViewModule,
                    error: ZIKAnyViewRouter.routeError(withCode:.invalidProtocol, localizedDescription:"Swift module config protocol (\(configProtocol)) was not registered with any view router."))
            assertionFailure("Swift module config protocol (\(configProtocol)) was not registered with any view router.")
        }
        return nil
    }
    fileprivate static func _swiftRouter(toViewModuleRouteKey routeKey: _RouteKey) -> ZIKAnyViewRouterType? {
        assert(routeKey.type != nil)
        if let route = viewModuleProtocolContainer[routeKey], let routerType = ZIKAnyViewRouterType.tryMakeType(forRoute: route) {
            return routerType
        }
        #if DEBUG
        var traversedProtocols: [_RouteKey] = []
        #endif
        var adapter = routeKey
        var adaptee: _RouteKey?
        repeat {
            adaptee = viewModuleAdapterContainer[adapter]
            if let adaptee = adaptee {
                if let route = viewModuleProtocolContainer[adaptee], let routerType = ZIKAnyViewRouterType.tryMakeType(forRoute: route) {
                    return routerType
                }
                if let configProtocol = routeKey.type, let routableProtocol = _routableViewModuleProtocolFromObject(configProtocol), let routerType = _ZIKViewRouterToModule(routableProtocol) {
                    return routerType
                }
                #if DEBUG
                traversedProtocols.append(adapter)
                if traversedProtocols.contains(adaptee) {
                    let adapterChain = traversedProtocols.reduce("") { (r, e) -> String in
                        return r + "\(e.key) -> "
                    }
                    assertionFailure("Dead cycle in module adapter -> adaptee chain: \(adapterChain + adaptee.key). Check your register(adapter:forAdaptee:).")
                    break
                }
                #endif
                adapter = adaptee
            }
        } while adaptee != nil
        return nil
    }
    
    /// Get service router class for registered service protocol.
    ///
    /// - Parameter routableService: A routabe entry carrying a service protocol conformed by the service registered with a service router. Support objc protocol and pure Swift protocol.
    /// - Returns: The service router class for the service protocol.
    fileprivate static func _router(toService serviceProtocol: Any.Type) -> ZIKAnyServiceRouterType? {
        if let routerType = _swiftRouter(toServiceRouteKey: _RouteKey(type:serviceProtocol)) {
            return routerType
        }
        if let routableProtocol = _routableServiceProtocolFromObject(serviceProtocol), let routerType = _ZIKServiceRouterToService(routableProtocol) {
            return routerType
        }
        if _routableServiceProtocolFromObject(serviceProtocol) == nil {
            ZIKAnyServiceRouter
                .notifyGlobalError(
                    with: nil,
                    action: .toService,
                    error: ZIKAnyServiceRouter.routeError(withCode:.invalidProtocol, localizedDescription:"Swift service protocol (\(serviceProtocol)) was not registered with any service router."))
            assertionFailure("Swift service protocol (\(serviceProtocol)) was not registered with any service router.")
        }
        return nil
    }
    fileprivate static func _swiftRouter(toServiceRouteKey routeKey: _RouteKey) -> ZIKAnyServiceRouterType? {
        assert(routeKey.type != nil)
        if let route = serviceProtocolContainer[routeKey], let routerType = ZIKAnyServiceRouterType.tryMakeType(forRoute: route) {
            return routerType
        }
        #if DEBUG
        var traversedProtocols: [_RouteKey] = []
        #endif
        var adapter = routeKey
        var adaptee: _RouteKey?
        repeat {
            adaptee = serviceAdapterContainer[adapter]
            if let adaptee = adaptee {
                if let route = serviceProtocolContainer[adaptee], let routerType = ZIKAnyServiceRouterType.tryMakeType(forRoute: route) {
                    return routerType
                }
                if let destinationProtocol = routeKey.type, let routableProtocol = _routableServiceProtocolFromObject(destinationProtocol), let routerType = _ZIKServiceRouterToService(routableProtocol) {
                    return routerType
                }
                #if DEBUG
                traversedProtocols.append(adapter)
                if traversedProtocols.contains(adaptee) {
                    let adapterChain = traversedProtocols.reduce("") { (r, e) -> String in
                        return r + "\(e.key) -> "
                    }
                    assertionFailure("Dead cycle in destination adapter -> adaptee chain: \(adapterChain + adaptee.key). Check your register(adapter:forAdaptee:).")
                    break
                }
                #endif
                adapter = adaptee
            }
        } while adaptee != nil
        return nil
    }
    
    /// Get service router class for registered config protocol.
    ///
    /// - Parameter routableServiceModule: A routabe entry carrying a service module config protocol registered with a service router. Support objc protocol and pure Swift protocol.
    /// - Returns: The service router class for the config protocol.
    fileprivate static func _router(toServiceModule configProtocol: Any.Type) -> ZIKAnyServiceRouterType? {
        if let routerType = _swiftRouter(toServiceModuleRouteKey: _RouteKey(type:configProtocol)) {
            return routerType
        }
        
        if let routableProtocol = _routableServiceModuleProtocolFromObject(configProtocol), let routerType = _ZIKServiceRouterToModule(routableProtocol) {
            return routerType
        }
        if _routableServiceModuleProtocolFromObject(configProtocol) == nil {
            ZIKAnyServiceRouter
                .notifyGlobalError(
                    with: nil,
                    action: .toServiceModule,
                    error: ZIKAnyServiceRouter.routeError(withCode:.invalidProtocol, localizedDescription:"Swift module config protocol (\(configProtocol)) was not registered with any service router."))
            assertionFailure("Swift module config protocol (\(configProtocol)) was not registered with any service router.")
        }
        return nil
    }
    fileprivate static func _swiftRouter(toServiceModuleRouteKey routeKey: _RouteKey) -> ZIKAnyServiceRouterType? {
        assert(routeKey.type != nil)
        if let route = serviceModuleProtocolContainer[routeKey], let routerType = ZIKAnyServiceRouterType.tryMakeType(forRoute: route) {
            return routerType
        }
        #if DEBUG
        var traversedProtocols: [_RouteKey] = []
        #endif
        var adapter = routeKey
        var adaptee: _RouteKey?
        repeat {
            adaptee = serviceModuleAdapterContainer[adapter]
            if let adaptee = adaptee {
                if let route = serviceModuleProtocolContainer[adaptee], let routerType = ZIKAnyServiceRouterType.tryMakeType(forRoute: route) {
                    return routerType
                }
                if let configProtocol = routeKey.type, let routableProtocol = _routableServiceModuleProtocolFromObject(configProtocol), let routerType = _ZIKServiceRouterToModule(routableProtocol) {
                    return routerType
                }
                #if DEBUG
                traversedProtocols.append(adapter)
                if traversedProtocols.contains(adaptee) {
                    let adapterChain = traversedProtocols.reduce("") { (r, e) -> String in
                        return r + "\(e.key) -> "
                    }
                    assertionFailure("Dead cycle in module adapter -> adaptee chain: \(adapterChain + adaptee.key). Check your register(adapter:forAdaptee:).")
                    break
                }
                #endif
                adapter = adaptee
            }
        } while adaptee != nil
        return nil
    }
}

// MARK: Validate

internal extension Registry {
    internal class func validateConformance(destination: Any, inViewRouterType routerType: ZIKAnyViewRouterType) -> Bool {
        #if DEBUG
        guard let routeKey = _RouteKey(routerType: routerType) else {
            return false
        }
        if let protocols = _check_viewProtocolContainer[routeKey] {
            for viewProtocolEntry in protocols {
                assert(_swift_typeIsTargetType(type(of: destination), viewProtocolEntry.type!), "Bad implementation in router (\(routerType))'s destination(with configuration:), the destination (\(destination)) doesn't conforms to registered view protocol (\(viewProtocolEntry.type!))")
                if _swift_typeIsTargetType(type(of: destination), viewProtocolEntry.type!) == false {
                    return false
                }
            }
        }
        return true
        #else
        return true
        #endif
    }
    internal class func validateConformance(destination: Any, inServiceRouterType routerType: ZIKAnyServiceRouterType) -> Bool {
        #if DEBUG
        guard let routeKey = _RouteKey(routerType: routerType) else {
            return false
        }
        if let protocols = _check_serviceProtocolContainer[routeKey] {
            for serviceProtocolEntry in protocols {
                assert(_swift_typeIsTargetType(type(of: destination), serviceProtocolEntry.type!), "Bad implementation in router (\(routerType))'s destination(with configuration:), the destination (\(destination)) doesn't conforms to registered service protocol (\(serviceProtocolEntry.type!))")
                if _swift_typeIsTargetType(type(of: destination), serviceProtocolEntry.type!) == false {
                    return false
                }
            }
        }
        return true
        #else
        return true
        #endif
    }
}

#if DEBUG

///Make sure all registered view classes conform to their registered view protocols.
private class _ViewRouterValidater: ZIKViewRouteAdapter {
    override class func isAbstractRouter() -> Bool {
        return true
    }
    override class func _didFinishRegistration() {
        
        // Declared protocol by extend RoutableView and RoutableViewModule should be registered
        var symbolNames = [String]()
        _enumerateSymbolName { (name, demangledAsSwift) -> Bool in
            if (strstr(name, "RoutableView") != nil) {
                let symbolName = demangledAsSwift(name, false)
                if symbolName.contains("(extension in"), symbolName.contains(">.init"), symbolName.contains("(extension in ZRouter)") == false {
                    let simplifiedName = demangledAsSwift(name, true)
                    symbolNames.append(simplifiedName)
                }
            }
            return true
        }
        
        let destinationProtocolRegex = try! NSRegularExpression(pattern: "(?<=-> RoutableView<).*(?=>$)", options: [.anchorsMatchLines])
        let moduleProtocolRegex = try! NSRegularExpression(pattern: "(?<=-> RoutableViewModule<).*(?=>$)", options: [.anchorsMatchLines])
        var declaredDestinationProtocols = [String]()
        var declaredModuleProtocols = [String]()
        for declaration in symbolNames {
            if let result = destinationProtocolRegex.firstMatch(in: declaration, options: .reportCompletion, range: NSRange(location: 0, length: declaration.utf8.count)) {
                let declaredProtocol = (declaration as NSString).substring(with: result.range)
                declaredDestinationProtocols.append(declaredProtocol)
            } else if let result = moduleProtocolRegex.firstMatch(in: declaration, options: .reportCompletion, range: NSRange(location: 0, length: declaration.utf8.count)) {
                let declaredProtocol = (declaration as NSString).substring(with: result.range)
                declaredModuleProtocols.append(declaredProtocol)
            }
        }
        
        for declaredProtocol in declaredDestinationProtocols {
            assert(Registry.viewProtocolContainer.keys.contains(_RouteKey(key: declaredProtocol)) ||
                Registry.viewAdapterContainer.keys.contains(_RouteKey(key: declaredProtocol)), "Declared view protocol (\(declaredProtocol)) is not registered with any router.")
        }
        for declaredProtocol in declaredModuleProtocols {
            assert(Registry.viewModuleProtocolContainer.keys.contains(_RouteKey(key: declaredProtocol)) ||
                Registry.viewModuleAdapterContainer.keys.contains(_RouteKey(key: declaredProtocol)), "Declared view protocol (\(declaredProtocol)) is not registered with any router.")
        }
        
        // Destination should conform to registered destination protocols
        for (routeKey, route) in Registry.viewProtocolContainer {
            let viewProtocol = routeKey.type!
            let badDestinationClass: AnyClass? = ZIKViewRouteRegistry.validateDestinations(forRoute: route, handler: { (destinationClass) -> Bool in
                return _swift_typeIsTargetType(destinationClass, viewProtocol)
            })
            assert(badDestinationClass == nil, "Registered view class (\(String(describing: badDestinationClass)) for router (\(route)) should conform to registered view protocol (\(viewProtocol)).")
        }
        
        // Destination should conforms to registered adapter destination protocols
        for (adapter, _) in Registry.viewAdapterContainer {
            guard let routerType = Registry._swiftRouter(toViewRouteKey: adapter) else {
                assertionFailure("View adapter protocol(\(adapter.key)) is not registered with any router!")
                continue
            }
            let route = routerType.routeObject
            var adapterProtocol: Any? = adapter.type
            if adapterProtocol == nil {
                adapterProtocol = NSProtocolFromString(adapter.key)
            }
            guard let viewProtocol = adapterProtocol else {
                assertionFailure("Invalid adapter (\(adapter.key)), can't get it's type")
                continue
            }
            let badDestinationClass: AnyClass? = ZIKViewRouteRegistry.validateDestinations(forRoute: route, handler: { (destinationClass) -> Bool in
                return _swift_typeIsTargetType(destinationClass, viewProtocol)
            })
            assert(badDestinationClass == nil, "Registered view class (\(String(describing: badDestinationClass)) for router (\(route)) should conform to registered view adapter protocol (\(viewProtocol)).")
        }
        
        // Router's defaultRouteConfiguration should conforms to registered module config protocols
        for (routeKey, route) in Registry.viewModuleProtocolContainer {
            guard let routerType = ZIKAnyViewRouterType.tryMakeType(forRoute: route) else {
                assertionFailure("Invalid route (\(route))")
                continue
            }
            let configProtocol = routeKey.type!
            let configType = type(of: routerType.defaultRouteConfiguration())
            assert(_swift_typeIsTargetType(configType, configProtocol), "The router (\(route))'s default configuration (\(configType)) must conform to the registered config protocol (\(configProtocol)).")
        }
        
        // Router's defaultRouteConfiguration should conforms to registered adapter module config protocols
        for (adapter, _) in Registry.viewModuleAdapterContainer {
            guard let routerType = Registry._swiftRouter(toViewModuleRouteKey: adapter) else {
                assertionFailure("View adapter protocol(\(adapter.key)) is not registered with any router!")
                continue
            }
            var adapterProtocol: Any? = adapter.type
            if adapterProtocol == nil {
                adapterProtocol = NSProtocolFromString(adapter.key)
            }
            guard let configProtocol = adapterProtocol else {
                assertionFailure("Invalid adapter (\(adapter.key)), can't get it's type")
                continue
            }
            let configType = type(of: routerType.defaultRouteConfiguration())
            assert(_swift_typeIsTargetType(configType, configProtocol), "The router (\(routerType))'s default configuration (\(configType)) must conform to the registered adapter config protocol (\(configProtocol)).")
        }
    }
}

///Make sure all registered service classes conform to their registered service protocols.
private class _ServiceRouterValidater: ZIKServiceRouteAdapter {
    override class func isAbstractRouter() -> Bool {
        return true
    }
    override class func _didFinishRegistration() {
        
        // Declared protocol by extend RoutableView and RoutableViewModule should be registered
        var symbolNames = [String]()
        _enumerateSymbolName { (name, demangledAsSwift) -> Bool in
            if (strstr(name, "RoutableService") != nil) {
                let symbolName = demangledAsSwift(name, false)
                if symbolName.contains("(extension in"), symbolName.contains(">.init"), symbolName.contains("(extension in ZRouter)") == false {
                    let simplifiedName = demangledAsSwift(name, true)
                    symbolNames.append(simplifiedName)
                }
            }
            return true
        }
        
        let destinationProtocolRegex = try! NSRegularExpression(pattern: "(?<=-> RoutableService<).*(?=>$)", options: [.anchorsMatchLines])
        let moduleProtocolRegex = try! NSRegularExpression(pattern: "(?<=-> RoutableServiceModule<).*(?=>$)", options: [.anchorsMatchLines])
        var declaredDestinationProtocols = [String]()
        var declaredModuleProtocols = [String]()
        for declaration in symbolNames {
            if let result = destinationProtocolRegex.firstMatch(in: declaration, options: .reportCompletion, range: NSRange(location: 0, length: declaration.utf8.count)) {
                let declaredProtocol = (declaration as NSString).substring(with: result.range)
                declaredDestinationProtocols.append(declaredProtocol)
            } else if let result = moduleProtocolRegex.firstMatch(in: declaration, options: .reportCompletion, range: NSRange(location: 0, length: declaration.utf8.count)) {
                let declaredProtocol = (declaration as NSString).substring(with: result.range)
                declaredModuleProtocols.append(declaredProtocol)
            }
        }
        
        for declaredProtocol in declaredDestinationProtocols {
            assert(Registry.serviceProtocolContainer.keys.contains(_RouteKey(key: declaredProtocol)) ||
                Registry.serviceAdapterContainer.keys.contains(_RouteKey(key: declaredProtocol)), "Declared service protocol (\(declaredProtocol)) is not registered with any router.")
        }
        for declaredProtocol in declaredModuleProtocols {
            assert(Registry.serviceModuleProtocolContainer.keys.contains(_RouteKey(key: declaredProtocol)) ||
                Registry.serviceModuleAdapterContainer.keys.contains(_RouteKey(key: declaredProtocol)), "Declared service protocol (\(declaredProtocol)) is not registered with any router.")
        }
        
        // Destination should conforms to registered destination protocols
        for (routeKey, route) in Registry.serviceProtocolContainer {
            let serviceProtocol = routeKey.type!
            let badDestinationClass: AnyClass? = ZIKServiceRouteRegistry.validateDestinations(forRoute: route, handler: { (destinationClass) -> Bool in
                return _swift_typeIsTargetType(destinationClass, serviceProtocol)
            })
            assert(badDestinationClass == nil, "Registered service class (\(badDestinationClass!)) for router (\(route)) should conform to registered service protocol (\(serviceProtocol)).")
        }
        
        // Destination should conforms to registered adapter destination protocols
        for (adapter, _) in Registry.serviceAdapterContainer {
            guard let routerType = Registry._swiftRouter(toServiceRouteKey: adapter) else {
                assertionFailure("Service adapter protocol(\(adapter.key)) is not registered with any router!")
                continue
            }
            let route = routerType.routeObject
            var adapterProtocol: Any? = adapter.type
            if adapterProtocol == nil {
                adapterProtocol = NSProtocolFromString(adapter.key)
            }
            guard let serviceProtocol = adapterProtocol else {
                assertionFailure("Invalid adapter (\(adapter.key)), can't get it's type")
                continue
            }
            let badDestinationClass: AnyClass? = ZIKServiceRouteRegistry.validateDestinations(forRoute: route, handler: { (destinationClass) -> Bool in
                return _swift_typeIsTargetType(destinationClass, serviceProtocol)
            })
            assert(badDestinationClass == nil, "Registered service class (\(badDestinationClass!)) for router (\(route)) should conform to registered service adapter protocol (\(serviceProtocol)).")
        }
        
        // Router's defaultRouteConfiguration should conforms to registered module config protocols
        for (routeKey, route) in Registry.serviceModuleProtocolContainer {
            guard let routerType = ZIKAnyServiceRouterType.tryMakeType(forRoute: route) else {
                assertionFailure("Invalid route (\(route))")
                continue
            }
            let configProtocol = routeKey.type!
            let configType = type(of: routerType.defaultRouteConfiguration())
            assert(_swift_typeIsTargetType(configType, configProtocol), "The router (\(route))'s default configuration (\(configType)) must conform to the registered config protocol (\(configProtocol)).")
        }
        
        // Router's defaultRouteConfiguration should conforms to registered adapter module config protocols
        for (adapter, _) in Registry.serviceModuleAdapterContainer {
            guard let routerType = Registry._swiftRouter(toServiceModuleRouteKey: adapter) else {
                assertionFailure("Service module adapter protocol(\(adapter.key)) is not registered with any router!")
                continue
            }
            var adapterProtocol: Any? = adapter.type
            if adapterProtocol == nil {
                adapterProtocol = NSProtocolFromString(adapter.key)
            }
            guard let configProtocol = adapterProtocol else {
                assertionFailure("Invalid adapter (\(adapter.key)), can't get it's type")
                continue
            }
            let configType = type(of: routerType.defaultRouteConfiguration())
            assert(_swift_typeIsTargetType(configType, configProtocol), "The router (\(routerType))'s default configuration (\(configType)) must conform to the registered module adapter protocol (\(configProtocol)).")
        }
    }
}

#endif
