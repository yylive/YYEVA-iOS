//
//  YYEVAVideoAlphaRender.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import <Foundation/Foundation.h>
#import "IYYEVAVideoRenderProtol.h"

@import MetalKit;
NS_ASSUME_NONNULL_BEGIN

@interface YYEVAVideoAlphaRender : NSObject <MTKViewDelegate,IYYEVAVideoRenderProtol>

@end

NS_ASSUME_NONNULL_END
