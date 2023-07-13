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

vector_float3 kColorConversion601FullRangeOffset = (vector_float3){0.5, 0.5,1};

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
 
 

void normalVerticesWithFillMod(CGRect rect,
                               CGSize containerSize,
                               CGSize picSize,
                               YYEVAEffectSourceImageFillMode fillMode,
                               float vertices[16],
                               YYEVAFillMode videoFillMode,
                               CGSize trueSize,
                               CGSize *renderSize) {
    //trueSize 传的是pt  设计师计算的是两倍的像素
    trueSize = CGSizeMake(trueSize.width * 2, trueSize.height * 2);
    float heightScaling = 1.0;
    float widthScaling = 1.0;
    CGSize drawableSize = trueSize; 
    CGFloat maxRatio = MAX( drawableSize.width / containerSize.width , drawableSize.height / containerSize.height);
    CGFloat lowRatio = MIN( drawableSize.width / containerSize.width , drawableSize.height / containerSize.height);
    CGFloat realWidth = 0.0;
    CGFloat realHeight = 0.0;
    
    switch (videoFillMode) {
        case YYEVAContentMode_ScaleToFill:
            heightScaling = 1.0;
            widthScaling = 1.0;
            break;

        case YYEVAContentMode_ScaleAspectFit:
            realWidth = lowRatio * containerSize.width;
            realHeight = lowRatio * containerSize.height;
            widthScaling = realWidth / drawableSize.width;
            heightScaling = realHeight / drawableSize.height;
            break;

        case YYEVAContentMode_ScaleAspectFill:
            realWidth = maxRatio * containerSize.width;
            realHeight = maxRatio * containerSize.height;
            widthScaling = realWidth / drawableSize.width;
            heightScaling = realHeight / drawableSize.height;
            break;
    }
   
    float originX, originY, width, height;
     
    
    
    //picSize
    CGFloat picW = picSize.width;
    CGFloat picH = picSize.height;
    
    CGFloat widthPicScaling = 1.0;
    CGFloat heightPicScaling = 1.0;
     
    CGFloat lowPicRatio = MIN( realWidth / picW , realHeight / picH);
    CGFloat highPicRatio = MAX( realWidth / picW , realHeight / picH);
    
    CGFloat picRealWidth = picW;
    CGFloat picRealHeight = picH;
    
    fillMode = YYEVAEffectSourceImageFillModeAspectFit;
    switch (fillMode) {
        case YYEVAEffectSourceImageFillModeScaleFill:
            widthPicScaling = 1.0;
            heightPicScaling = 1.0;
            break;

        case YYEVAEffectSourceImageFillModeAspectFit:
            picRealWidth = lowPicRatio * picW;
            picRealHeight = lowPicRatio * picH;
            widthPicScaling = picRealWidth / picW;
            heightPicScaling = picRealHeight / picH;
            break;

        case YYEVAEffectSourceImageFillModeAspectFill:
            picRealWidth = highPicRatio * picW;
            picRealHeight = highPicRatio * picH;
            widthPicScaling = picRealWidth / picW;
            heightPicScaling = picRealHeight / picH;
            break;
    }
     
    *renderSize = CGSizeMake(picRealWidth, picRealHeight);

    originX = (-1+2*rect.origin.x/containerSize.width) * widthScaling ;
    originY = (1-2*rect.origin.y/containerSize.height) * heightScaling ;
    width = (2 * rect.size.width/containerSize.width) * widthScaling ;
    height = (2 * rect.size.height/containerSize.height) * heightScaling ;

      
    float tempVertices[] = {
        originX, originY,0.0, 1.0,
        originX,originY-height,0.0,1.0,
        originX+width,originY,0.0,1.0 ,
        originX+width,originY-height,0.0, 1.0};
//    
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


void mask_textureCoordinateFromRect(CGRect rect,CGSize containerSize,float coordinates[8])
{
    float originX, originY, width, height;
    originX = rect.origin.x/containerSize.width;
    originY = rect.origin.y/containerSize.height;
    width = rect.size.width/containerSize.width;
    height = rect.size.height/containerSize.height;
     
    float tempCoordintes[] = {
        originX, originY,       //0,0
        originX, originY+height,//0,1
        originX+width, originY, //1,0
        originX+width, originY+height, //1,1
    };
        
    replaceArrayElements(coordinates, tempCoordintes, 8);
}


@implementation YSVideoMetalUtils

+ (UIImage *)imageWithAttrText:(NSAttributedString *)attrText rectSize:(CGSize)rectSize
{
    CGRect rect = (CGRect){CGPointMake(0.0,0.0),rectSize};
    __block UIFont *font = nil;
    [attrText enumerateAttributesInRange:NSMakeRange(0, attrText.length) options:1 usingBlock:^(NSDictionary<NSAttributedStringKey,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
        if (attrs) {
            font = [attrs valueForKey:NSFontAttributeName];
            *stop = YES;
        }
    }];
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, [UIScreen mainScreen].scale);
    rect.origin.y = (rect.size.height - font.lineHeight)/2.0;
    [attrText drawWithRect:rect options:NSStringDrawingUsesLineFragmentOrigin context:nil];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    if (!image) {
        return nil;
    }
    return image;
}

+ (UIImage *)imageWithText:(NSString *)text
                     textColor:(UIColor *)textColor
                      fontSize:(float)fontSize
                      rectSize:(CGSize)rectSize
                         align:(NSTextAlignment)align
{
    CheckReturnNil((text.length != 0));
    
    if (!textColor) {
        textColor = [UIColor whiteColor];
    }
    CGRect rect = (CGRect){CGPointMake(0.0,0.0),rectSize};
    CGSize textSize = CGSizeZero;
    UIFont *font = [self calculatorFontWithText:text rect:rect designedSize:fontSize fontName:nil bold:bold textSize:&textSize needFitWidth:NO];
    NSMutableParagraphStyle *paragraphStyle = [NSMutableParagraphStyle new];
    paragraphStyle.alignment = align;
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
 

//如果图像缓冲区是平面的，则为映射纹理数据的平面索引。对于非平面图像缓冲区忽
+ (id<MTLTexture>)getTextureFromPixelBuffer:(CVPixelBufferRef)pixelBufferRef
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
                                     device:(id<MTLDevice>)device
                               textureCache:(CVMetalTextureCacheRef)textureCache
{
    //设置yuv纹理数据
#if TARGET_OS_SIMULATOR || TARGET_MACOS
    if(CVPixelBufferLockBaseAddress(pixelBufferRef, 0) != kCVReturnSuccess)
       {
           return  nil;
       }
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBufferRef, planeIndex);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBufferRef, planeIndex);
       if (width == 0 || height == 0) {
           return nil;
       }
       MTLTextureDescriptor *descriptor = [MTLTextureDescriptor texture2DDescriptorWithPixelFormat:pixelFormat
                                                                                             width:width
                                                                                            height:height
                                                                                         mipmapped:NO];
    
  
       descriptor.usage = (MTLTextureUsageShaderRead | MTLTextureUsageShaderWrite | MTLTextureUsageRenderTarget);
       id<MTLTexture> texture = [device newTextureWithDescriptor:descriptor];
       MTLRegion region = MTLRegionMake2D(0, 0, width, height);
       [texture replaceRegion:region
                  mipmapLevel:0
                    withBytes:CVPixelBufferGetBaseAddressOfPlane(pixelBufferRef, planeIndex)
                  bytesPerRow:CVPixelBufferGetBytesPerRowOfPlane(pixelBufferRef,planeIndex)];
       return texture;
#else
    //    //y纹理
        id<MTLTexture> texture = nil;
        size_t width = CVPixelBufferGetWidthOfPlane(pixelBufferRef, planeIndex);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBufferRef, planeIndex);
        CVMetalTextureRef textureRef = NULL;
        CVReturn status =  CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, pixelBufferRef, NULL, pixelFormat, width, height, planeIndex, &textureRef);
        if (status == kCVReturnSuccess) {
            texture = CVMetalTextureGetTexture(textureRef);
            CFRelease(textureRef);
            textureRef = NULL;
        }
        CVMetalTextureCacheFlush(textureCache, 0);
        pixelBufferRef = NULL;
        return texture;
#endif
}
@end

