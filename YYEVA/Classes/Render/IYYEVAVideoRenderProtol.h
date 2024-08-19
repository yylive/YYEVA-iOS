//
//  IYYEVAVideoRenderProtol.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"
 
NS_ASSUME_NONNULL_BEGIN


@import MetalKit;
@class YYEVAAssets;

@protocol IYYEVAVideoRenderProtol <MTKViewDelegate>
 
@property (nonatomic, copy) dispatch_block_t completionPlayBlock;

@property (nonatomic, strong) YYEVAAssets *playAssets;

- (void)playWithAssets:(YYEVAAssets *)assets;
- (instancetype)initWithMetalView:(MTKView *)mtkView;

@property (nonatomic, assign) YYEVAFillMode fillMode; 
 
@property (nonatomic, assign) BOOL disalbleMetalCache;

@end

NS_ASSUME_NONNULL_END
