//
//  YYEVAVideoEffectRender.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//


#import <Foundation/Foundation.h>
#import "YYEVAAssets.h"
#import "IYYEVAVideoRenderProtol.h"

@import MetalKit;

NS_ASSUME_NONNULL_BEGIN

@interface YYEVAVideoEffectRender : NSObject <IYYEVAVideoRenderProtol>
- (void)setBgImageUrl:(NSString *)bgImageUrl contentMode:(UIViewContentMode)bgContentMode;
@end
 

NS_ASSUME_NONNULL_END
