//
//  YSVideoMetalUtils.m
//  YYYSVideoPlayer
//
//  Created by guoyabin on 2021/7/15.
//
#import "YSVideoMetalUtils.h"
#import <AVFoundation/AVFoundation.h>
@import MetalKit;

matrix_float3x3 kColorConversion601FullRangeMatrix = (matrix_float3x3){
    (simd_float3){1.0,    1.0,    1.0},
    (simd_float3){0.0,    -0.343, 1.765},
    (simd_float3){1.4,    -0.711, 0.0},
};

vector_float3 kColorConversion601FullRangeOffset = (vector_float3){ -(16.0/255.0), -0.5, -0.5};

//arr0[0...(size-1)] <- arr1[0...(size-1)]
void replaceArrayElements(float arr0[], float arr1[], int size) {
    
    if ((arr0 == NULL || arr1 == NULL) && size > 0) {
        assert(0);
    }
    if (size < 0) {
        assert(0);
    }
    for (int i = 0; i < size; i++) {
        arr0[i] = arr1[i];
    }
}
  
void generatorVertices(CGRect rect, CGSize containerSize, float vertices[16]) {
    
    float originX, originY, width, height;
    originX = -1+2*rect.origin.x/containerSize.width;
    originY = 1-2*rect.origin.y/containerSize.height;
    width = 2*rect.size.width/containerSize.width;
    height = 2*rect.size.height/containerSize.height;
      
    float tempVertices[] = {
            originX, originY,0.0, 1.0,
            originX,originY-height,0.0,1.0,
            originX+width,originY,0.0,1.0 ,
            originX+width,originY-height,0.0, 1.0};
    replaceArrayElements(vertices, tempVertices, 16);
}
 

void normalVerticesWithFillMode(CGRect rect, CGSize containerSize, CGSize picSize,YYEVAEffectSourceImageFillMode fillMode, float vertices[16],YYEVAFillMode videoFillMode,CGSize trueSize) {
    if (picSize.width > 0 && picSize.height > 0) {
        float picWidth = picSize.width;
        float picHeight = picSize.height;
        float rectWidth = rect.size.width;
        float rectHeight = rect.size.height;
        float wRatio = rectWidth / picWidth;
        float hRatio = rectHeight/ picHeight;
        float ratio = wRatio;
        if (fillMode == YYEVAEffectSourceImageFillModeAspectFit) {  //eAspectFit
            ratio = MIN(wRatio, hRatio);
        } else {
            ratio = MAX(wRatio, hRatio);
        }
       float trueW;
       float trueH;
       trueW =  (picWidth * ratio);
       trueH =  (picHeight * ratio);
       //有改变  调整 x y值
       if (trueW != rectWidth || trueH != rectHeight) {
           float trueX = rect.origin.x;
           float trueY = rect.origin.y;
           if (rectWidth - trueW) {
               trueX += (rectWidth - trueW) / 2;
           }
           if (rectHeight - trueH) {
               trueY += (rectHeight - trueH) / 2;
           }
           
           rect = CGRectMake(trueX, trueY, trueW, trueH);
       }
    }
    
    //containerSize
    
    //trueSize
    float heightScaling = 1.0;
    float widthScaling = 1.0;
    CGSize drawableSize = trueSize;
    CGRect bounds = CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(containerSize, bounds);
    switch (videoFillMode) {
        case YYEVAContentMode_ScaleToFill:
            heightScaling = 1.0;
            widthScaling = 1.0;
            break;

        case YYEVAContentMode_ScaleAspectFit:
            widthScaling = insetRect.size.width / drawableSize.width;
            heightScaling = insetRect.size.height / drawableSize.height;
            break;

        case YYEVAContentMode_ScaleAspectFill:
            widthScaling = drawableSize.height / insetRect.size.height;
            heightScaling = drawableSize.width / insetRect.size.width;
            break;
    }
     
//    rect
//    rect = CGRectMake(rect.origin.x * widthScaling, rect.origin.y * heightScaling, rect.size.width, rect.size.height);
     
    float originX, originY, width, height;
    originX = (-1+2*rect.origin.x/containerSize.width) * widthScaling;
    originY = (1-2*rect.origin.y/containerSize.height) * heightScaling;
    width = (2*rect.size.width/containerSize.width) * widthScaling;
    height = (2*rect.size.height/containerSize.height) * heightScaling;
      
    float tempVertices[] = {
            originX, originY,0.0, 1.0,
            originX,originY-height,0.0,1.0,
            originX+width,originY,0.0,1.0 ,
            originX+width,originY-height,0.0, 1.0};
    replaceArrayElements(vertices, tempVertices, 16);
}

void textureCoordinateFromRect(CGRect rect,CGSize containerSize,float coordinates[8])
{
    float originX, originY, width, height;
    originX = rect.origin.x/containerSize.width;
    originY = rect.origin.y/containerSize.height;
    width = rect.size.width/containerSize.width;
    height = rect.size.height/containerSize.height;
    
    
     
    float tempCoordintes[] = {
        originX, originY+height,//0,1
        originX, originY,       //0,0
        originX+width, originY+height, //1,1
        originX+width, originY}; //1,0
    replaceArrayElements(coordinates, tempCoordintes, 8);
}

@implementation YSVideoMetalUtils

 

+ (UIImage *)imageWithText:(NSString *)text
                     textColor:(UIColor *)textColor
                      fontSize:(float)fontSize
                      rectSize:(CGSize)rectSize
{
    CheckReturnNil((text.length != 0));
    
    if (!textColor) {
        textColor = [UIColor whiteColor];
    }
    CGRect rect = (CGRect){CGPointMake(0.0,0.0),rectSize};
    CGSize textSize = CGSizeZero;
    UIFont *font = [self calculatorFontWithText:text rect:rect designedSize:fontSize fontName:nil bold:bold textSize:&textSize needFitWidth:NO];
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    paragraphStyle.lineBreakMode = NSLineBreakByTruncatingTail;
    NSDictionary *attr = @{NSFontAttributeName:font, NSParagraphStyleAttributeName:paragraphStyle, NSForegroundColorAttributeName:textColor,NSBackgroundColorAttributeName:[UIColor clearColor]};
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    rect.origin.y = (rect.size.height - font.lineHeight)/2.0;
    [text drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin attributes:attr context:nil];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!image) {
        return nil;
    }
    return image;
}
 
//根据指定的字符内容和容器大小计算合适的字体
+ (UIFont *)calculatorFontWithText:(NSString *)text
                              rect:(CGRect)fitFrame
                      designedSize:(CGFloat)designedFontSize
                          fontName:(NSString *)fontName
                              bold:(BOOL)isBold
                          textSize:(CGSize *)textSize
                      needFitWidth:(BOOL)needFitWidth
{
    UIFont *defaultFont = [UIFont systemFontOfSize:designedFontSize weight:UIFontWeightHeavy];
    if ([defaultFont.fontName isEqualToString:@".SFUI-Black"]) {
        defaultFont = [UIFont systemFontOfSize:designedFontSize weight:UIFontWeightSemibold];
        if (![defaultFont.fontName isEqualToString:@".SFUI-Heavy"]) {
            defaultFont = nil;
            NSLog(@"not heavy");
        }
    }

    UIFont *designedFont = isBold ? [UIFont boldSystemFontOfSize:designedFontSize] : [UIFont systemFontOfSize:designedFontSize];
    if (defaultFont != nil) {
        designedFont = defaultFont;
    }

    if (fontName && fontName.length) {
        UIFont *tempFont = [UIFont fontWithName:fontName size:designedFontSize];
        if (tempFont) {
            designedFont = tempFont;
        }
    }

    if (text.length == 0 || CGRectEqualToRect(CGRectZero, fitFrame) || !designedFont) {
        *textSize = fitFrame.size;
        return designedFont;
    }
    CGSize stringSize = [text sizeWithAttributes:@{NSFontAttributeName: designedFont}];
  
    *textSize = stringSize;
    return designedFont;
}
 
@end
