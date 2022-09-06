//
//  YSVideoMetalUtils.h
//  YYYSVideoPlayer
//
//  Created by guoyabin on 2021/7/15.
//

#import <Foundation/Foundation.h>
#import "YYEVACommon.h"

NS_ASSUME_NONNULL_BEGIN
  
#ifdef __cplusplus
extern "C" {
#endif 
    extern void normalVerticesWithFillMode(CGRect rect, CGSize containerSize, CGSize picSize,YYEVAEffectSourceImageFillMode fillMode, float vertices[16],YYEVAFillMode videoFillMode,CGSize trueSize);
    extern void textureCoordinateFromRect(CGRect rect,CGSize containerSize,float coordinates[_Nullable 8]);
    
#ifdef __cplusplus
}
#endif

@interface YSVideoMetalUtils : NSObject

+ (UIImage *)imageWithText:(NSString *)text
                     textColor:(UIColor *)textColor
                      fontSize:(float)fontSize
                      rectSize:(CGSize)rectSize;
@end


NS_ASSUME_NONNULL_END
