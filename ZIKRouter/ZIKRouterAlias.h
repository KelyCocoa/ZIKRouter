//
//  ZIKRouterAlias.h
//  ZIKRouter
//
//  Created by zuik on 2017/11/6.
//  Copyright © 2017 zuik. All rights reserved.
//
//  This source code is licensed under the MIT-style license found in the
//  LICENSE file in the root directory of this source tree.
//

#import "ZIKViewRouter.h"
#import "ZIKServiceRouter.h"

typedef ZIKRouteConfiguration ZIKRouteConfig;
typedef ZIKPerformRouteConfiguration ZIKPerformRouteConfig;
typedef ZIKRemoveRouteConfiguration ZIKRemoveRouteConfig;

typedef ZIKServiceRouter<id, ZIKPerformRouteConfig *> ZIKAnyServiceRouter;
#define ZIKDestinationServiceRouter(Destination) ZIKServiceRouter<Destination, ZIKPerformRouteConfig *>
#define ZIKModuleServiceRouter(ModuleConfigProtocol) ZIKServiceRouter<id, ZIKPerformRouteConfig<ModuleConfigProtocol> *>

typedef ZIKViewRouteConfiguration ZIKViewRouteConfig;
typedef ZIKViewRemoveConfiguration ZIKViewRemoveConfig;
typedef ZIKViewRouteSegueConfiguration ZIKViewRouteSegueConfig;
typedef ZIKViewRoutePopoverConfiguration ZIKViewRoutePopoverConfig;

typedef ZIKViewRouter<id, ZIKViewRouteConfig *> ZIKAnyViewRouter;
#define ZIKDestinationViewRouter(Destination) ZIKViewRouter<Destination, ZIKViewRouteConfig *>
#define ZIKModuleViewRouter(ModuleConfigProtocol) ZIKViewRouter<id, ZIKViewRouteConfig<ModuleConfigProtocol> *>

///Check whether the protocol is routable at complie time when passing protocols to `+registerViewProtocol:`, `+registerServiceProtocol:`, `+registerModuleProtocol:`.
#define ZIKRoutable(RoutableProtocol) (Protocol<RoutableProtocol>*)@protocol(RoutableProtocol)
#define ZIKRoutableProtocol(RoutableProtocol) (Protocol<RoutableProtocol>*)@protocol(RoutableProtocol)
