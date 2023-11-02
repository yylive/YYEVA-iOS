//
//  YYEVAEffectInfo.h
//  YYEVA
//
//  Created by guoyabin on 2022/4/7.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Metal/Metal.h>
#import "YYEVACommon.h"
NS_ASSUME_NONNULL_BEGIN

@class YYEVAEffectSource;

@interface YYEVAEffectFrame : NSObject
+ (instancetype)effectFrameWithDictionary:(NSDictionary *)dict;
@property (nonatomic, assign,readonly) CGRect renderFrame;
@property (nonatomic, assign,readonly) CGRect outputFrame;
@property (nonatomic, assign,readonly) NSInteger effect_id;
@property (nonatomic, assign) YYEVAEffectSource *src; 
- (id<MTLBuffer>)vertexBufferWithContainerSize:(CGSize)size
                             maskContianerSize:(CGSize)mSize
                                        device:(id<MTLDevice>)device
                                      fillMode:(YYEVAFillMode)fillMode
                                      trueSize:(CGSize)trueSize
                                    renderSize:(CGSize *)renderSize;
@end

@interface YYEVAEffectSource : NSObject
+ (instancetype)effectSourceWithDictionary:(NSDictionary *)dict;

@property (nonatomic, assign,readonly) float width;
@property (nonatomic, assign,readonly) float height;
@property (nonatomic, assign,readonly) NSInteger effect_id;
@property (nonatomic, copy,readonly) NSString *effect_tag;
@property (nonatomic, assign,readonly) YYEVAEffectSourceType type;
//文字类型的遮罩生效
@property (nonatomic, copy,readonly) NSString *fontColor;
@property (nonatomic, assign,readonly) float fontSize;
@property (nonatomic, assign,readonly) NSTextAlignment alignment;
//图片类型的遮罩生效
@property (nonatomic, assign,readonly) YYEVAEffectSourceImageFillMode fillMode;



//加载内容
@property (nonatomic, strong) UIImage                   *sourceImage;
@property (nonatomic, strong) id<MTLTexture>            texture;
@property (nonatomic, strong) id<MTLBuffer>             colorParamsBuffer;


@end


@interface YYEVAEffectInfo : NSObject

+ (instancetype)effectInfoWithDictionary:(NSDictionary *)dict;

@property (nonatomic, assign,readonly) float videoWidth;
@property (nonatomic, assign,readonly) float videoHeight;
@property (nonatomic, assign,readonly) BOOL isEffect;
@property (nonatomic, copy,  readonly) NSString *plugin_version;
@property (nonatomic, assign,readonly) CGRect rgbFrame;
@property (nonatomic, assign,readonly) CGRect alphaFrame;

@property (nonatomic, strong) NSArray<YYEVAEffectSource *> *srcs;
@property (nonatomic, strong) NSDictionary <NSNumber *,YYEVAEffectSource *> *mapForSource;
@property (nonatomic, strong) NSDictionary<NSNumber * ,NSArray<YYEVAEffectFrame *>*> *frames;


@end

NS_ASSUME_NONNULL_END
