//
//  IYYEVAVideoRenderProtol.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import <Foundation/Foundation.h>

 
NS_ASSUME_NONNULL_BEGIN


@import MetalKit;
@class YYEVAAssets;

@protocol IYYEVAVideoRenderProtol <MTKViewDelegate>
 
@property (nonatomic, copy) dispatch_block_t completionPlayBlock;

@property (nonatomic, strong) YYEVAAssets *playAssets;

- (void)playWithAssets:(YYEVAAssets *)assets;
- (instancetype)initWithMetalView:(MTKView *)mtkView;
 
@end

NS_ASSUME_NONNULL_END
