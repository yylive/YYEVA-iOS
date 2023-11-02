//
//  YSVideoMetalUtils.h
//  YYYSVideoPlayer
//
//  Created by guoyabin on 2021/7/15.
//

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
  
#ifdef __cplusplus
extern "C" {
#endif  

    extern void normalVerticesWithFillMod(CGRect rect, CGSize containerSize, CGSize picSize,YYEVAEffectSourceImageFillMode fillMode, float vertices[_Nullable 16],YYEVAFillMode videoFillMode,CGSize trueSize, CGSize *renderSize);
   
    extern void textureCoordinateFromRect(CGRect rect,CGSize containerSize,float coordinates[_Nullable 8]);
    extern void mask_textureCoordinateFromRect(CGRect rect,CGSize containerSize,float coordinates[_Nullable 8]);
    
#ifdef __cplusplus
}
#endif

@interface YSVideoMetalUtils : NSObject

+ (UIImage *)imageWithAttrText:(NSAttributedString *)attrText rectSize:(CGSize)rectSize;

+ (UIImage *)imageWithText:(NSString *)text
                     textColor:(UIColor *)textColor
                      fontSize:(float)fontSize
                      rectSize:(CGSize)rectSize
                     align:(NSTextAlignment)align;

+ (id<MTLTexture>)getTextureFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
                                     device:(id<MTLDevice>)device
                               textureCache:(CVMetalTextureCacheRef)textureCache;

@end


NS_ASSUME_NONNULL_END
