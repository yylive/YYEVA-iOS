//
//  YYEVARegionChecker.m
//  YYEVA
//
//  Created by wicky on 2023/4/20.
//

#import "YYEVARegionChecker.h"
#import <AVFoundation/AVFoundation.h>
#import <CoreVideo/CoreVideo.h>
#import <CoreMedia/CMFormatDescription.h>
#import <Accelerate/Accelerate.h>

@interface YYRGBPixelNode : NSObject
@property (nonatomic, assign) NSUInteger r;
@property (nonatomic, assign) NSUInteger g;
@property (nonatomic, assign) NSUInteger b;
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) BOOL isColorNode;
@end

@implementation YYRGBPixelNode
- (instancetype)init
{
    if (self = [super init]) {
        _r = 0;
        _g = 0;
        _b = 0;
        _point = CGPointZero;
    }
    return self;
}
@end

@interface YYEVARegionChecker()
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@property (nonatomic, strong) CIContext *ciContext;
@end

@implementation YYEVARegionChecker
- (YYEVAColorRegion)checkFile:(NSString *)url
{
    return [self checkFile:url CheckMaxFrame:3];
}

- (YYEVAColorRegion)checkFile:(NSString *)url CheckMaxFrame:(NSInteger)maxFrame
{
    YYEVAColorRegion result = YYEVAColorRegion_Invaile;
    
    _asset = [[AVURLAsset alloc] initWithURL:[NSURL fileURLWithPath:url] options:nil];
    _reader = [AVAssetReader assetReaderWithAsset:self.asset error:nil];
    if (!_reader) {
        return YYEVAColorRegion_Invaile;
    }
    
    AVAssetTrack *videoTrack = [[_asset tracksWithMediaType:AVMediaTypeVideo] firstObject];
    if (!videoTrack) {
        //        NSLog(@"tracksWithMediaType url:%@ failure",self.filePath);
        return YYEVAColorRegion_Invaile;
    }
    
    NSDictionary *outputSettings = @{
        (id)kCVPixelBufferIOSurfacePropertiesKey : [NSDictionary dictionary] ,
    };
    _output = [AVAssetReaderTrackOutput assetReaderTrackOutputWithTrack:videoTrack outputSettings:outputSettings];
    _output.alwaysCopiesSampleData = NO;
    ![_reader canAddOutput:_output] ?:  [_reader addOutput:_output];
    [_reader startReading];
    
    for (int i = 0; i<maxFrame; i++) {
        @autoreleasepool {
            CMSampleBufferRef sampleBufferRef = [self getNextSampleBufferRef];
            if (sampleBufferRef == NULL) {
                continue;
            }
            
            result = [self checkSampleRef:sampleBufferRef];
            CMSampleBufferInvalidate(sampleBufferRef);
            CFRelease(sampleBufferRef);
            if (result) {
                break;
            }
        }
    }
    
    return result;
}

- (YYEVAColorRegion)checkSampleRef:(CMSampleBufferRef)sampleBuffer
{
    CVPixelBufferRef yuvPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    CVPixelBufferLockBaseAddress(yuvPixelBuffer, 0);
    
    NSInteger scale = 16;
    CVPixelBufferRef rgbPixelBuffer = [self getRGBPixelBufferFromYUVPixelBuffer:yuvPixelBuffer Scale:scale];
    CVPixelBufferLockBaseAddress(rgbPixelBuffer, 0);

    size_t pWidth = CVPixelBufferGetWidth(rgbPixelBuffer);
    size_t pHeight = CVPixelBufferGetHeight(rgbPixelBuffer);

    
    //    抽取144个点
    NSUInteger sizePoint = 6;
    NSArray<YYRGBPixelNode *> *LTNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(0, 0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:rgbPixelBuffer]; // 左上角
    NSArray<YYRGBPixelNode *> *RTNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake( pWidth / 2.0, 0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:rgbPixelBuffer];// 右上角
    NSArray<YYRGBPixelNode *> *LBNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(0, pHeight / 2.0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:rgbPixelBuffer]; // 左下角
    NSArray<YYRGBPixelNode *> *RBNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(pWidth / 2.0, pHeight / 2.0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:rgbPixelBuffer];// 右下角
    
    BOOL LTIsColor = isColorRegion(LTNodes);
    BOOL RTIsColor = isColorRegion(RTNodes);
    BOOL LBIsColor = isColorRegion(LBNodes);
    BOOL RBIsColor = isColorRegion(RBNodes);
    
    YYEVAColorRegion result = YYEVAColorRegion_Invaile;
    if (!LTIsColor && !RTIsColor && !LBIsColor && !RBIsColor) {
        NSLog(@"全都是黑白，无效帧");
    } else if (LTIsColor && RTIsColor && LBIsColor && RBIsColor) {
        NSLog(@"全都是彩色，普通MP4");
        result = YYEVAColorRegion_NormalMP4;
    } else if ((LTIsColor || LBIsColor) && !(RTIsColor && RBIsColor)) {
        NSLog(@"左彩色，右黑白，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_LeftColorRightGray;
    }  else if (!(LTIsColor && LBIsColor) && (RTIsColor || RBIsColor)) {
        NSLog(@"左黑白，右彩色，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_LeftGrayRightColor;
    }  else if ((LTIsColor || RTIsColor) && !(LBIsColor && RBIsColor)) {
        NSLog(@"上彩色，下黑白，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_TopColorBottomGray;
    }  else if (!(LTIsColor && RTIsColor) && (LBIsColor || RBIsColor)) {
        NSLog(@"上黑白，下彩色，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_TopGrayBottomColor;
    }
    
    CFRelease(rgbPixelBuffer);
    rgbPixelBuffer = NULL;
    
    CVPixelBufferUnlockBaseAddress(rgbPixelBuffer, 0);
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    return result;
}

//获取以pointNum个点为边长的矩形的所有点
- (NSArray *)getSquareSidePoints:(NSUInteger)pointNum
                  PointsWithRect:(CGRect)rect
          InPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    void (^block)(YYRGBPixelNode *) = ^(YYRGBPixelNode *node) {
        CVPixelBufferLockBaseAddress(pixelBuffer, 0);
        unsigned char *baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer);
        
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer);
        size_t index = node.point.y * bytesPerRow + node.point.x*4;
        
        int b = *(baseAddress+index);
        int g = *(baseAddress+index+1);
        int r = *(baseAddress+index+2);
        BOOL isGray = isGrayPixelWith(r, g, b);
        
        node.r = r;
        node.g = g;
        node.b = b;
        node.isColorNode = !isGray;
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    };
    
    NSMutableArray *result = @[].mutableCopy;
    int xStep = floor(rect.size.width / (pointNum + 1));
    int yStep = floor(rect.size.height / (pointNum + 1));
    
    for (int col = 0; col < pointNum; col++) {
        @autoreleasepool {
            int y = rect.origin.y + (col + 1) * yStep;
            
            for (int row = 0; row < pointNum; row++) {
                int x = rect.origin.x + (row + 1) * xStep;
                YYRGBPixelNode *node = [YYRGBPixelNode new];
                node.point = CGPointMake(x, y);
                
                block(node);
                
                [result addObject:node];
            }
        }
    }
    
    return result.copy;
}

#pragma mark - get something
- (CVPixelBufferRef)getRGBPixelBufferFromYUVPixelBuffer:(CVPixelBufferRef)yuvPx Scale:(NSInteger)scale
{
    CVPixelBufferLockBaseAddress(yuvPx, 0);
    //     将YUV图像转换为CIImage
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:yuvPx options:nil];
    // 将YUV图像转换为RGBA图像
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGImageRef rgbaImage = [self.ciContext createCGImage:ciImage fromRect:ciImage.extent format:kCIFormatBGRA8 colorSpace:colorSpace];
    CGColorSpaceRelease(colorSpace);
    
    UIImage *img = [self downSample:[UIImage imageWithCGImage:rgbaImage] to:CGSizeMake(CGImageGetWidth(rgbaImage)/scale, CGImageGetHeight(rgbaImage)/scale)];

    CVPixelBufferRef rgbPixelBuffer = [self getCVPixelBufferFromImage:img];
    
    CFRelease(rgbaImage);
    rgbaImage = NULL;
    
    CVPixelBufferUnlockBaseAddress(yuvPx, 0);
    return rgbPixelBuffer;
}

- (CVPixelBufferRef)getCVPixelBufferFromImage:(UIImage *)img
{
    CGSize size = img.size;
    CGImageRef image = [img CGImage];
    
    BOOL hasAlpha = CGImageRefContainsAlpha(image);
    CFDictionaryRef empty = CFDictionaryCreate(kCFAllocatorDefault, NULL, NULL, 0, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
    
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             empty, kCVPixelBufferIOSurfacePropertiesKey,
                             nil];
    CVPixelBufferRef pxbuffer = NULL;
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault, size.width, size.height, inputPixelFormat(), (__bridge CFDictionaryRef) options, &pxbuffer);
    
    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);
    
    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);
    
    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    
    uint32_t bitmapInfo = bitmapInfoWithPixelFormatType(inputPixelFormat(), (bool)hasAlpha);
    
    CGContextRef context = CGBitmapContextCreate(pxdata, size.width, size.height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace, bitmapInfo);
    NSParameterAssert(context);
    
    CGContextDrawImage(context, CGRectMake(0, 0, CGImageGetWidth(image), CGImageGetHeight(image)), image);
    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);
    
    return pxbuffer;
}

- (CMSampleBufferRef)getNextSampleBufferRef {
    CMSampleBufferRef sampleBufferRef = NULL;
    if (_reader.status == AVAssetReaderStatusReading) {
        sampleBufferRef = [_output copyNextSampleBuffer];
    }
    
    return sampleBufferRef;
}

#pragma mark - downSample
- (UIImage *)downSample:(UIImage *)image to:(CGSize)size {
    CFStringRef key[1];
    key[0] = kCGImageSourceShouldCache;
    CFTypeRef value[1];
    value[0] = (CFTypeRef)kCFBooleanFalse;
    
    CFDictionaryRef imageSourceOption = CFDictionaryCreate(NULL,
                                                           (const void **) key,
                                                           (const void **) value,
                                                           1,
                                                           &kCFTypeDictionaryKeyCallBacks,
                                                           &kCFTypeDictionaryValueCallBacks);
    
    CGImageSourceRef imageSource = CGImageSourceCreateWithData((__bridge CFDataRef)UIImagePNGRepresentation(image), imageSourceOption);
    
    CFMutableDictionaryRef mutOption = CFDictionaryCreateMutable(NULL,
                                                                 4,
                                                                 &kCFTypeDictionaryKeyCallBacks,
                                                                 &kCFTypeDictionaryValueCallBacks);
    
    
    CGFloat maxDimension = MAX(size.width, size.height) * [UIScreen mainScreen].scale;
    NSNumber *maxDimensionNum = [NSNumber numberWithFloat:maxDimension];
    CFDictionaryAddValue(mutOption, kCGImageSourceCreateThumbnailFromImageAlways, kCFBooleanTrue);
    CFDictionaryAddValue(mutOption, kCGImageSourceShouldCacheImmediately, kCFBooleanTrue);
    CFDictionaryAddValue(mutOption, kCGImageSourceCreateThumbnailWithTransform, kCFBooleanTrue);
    CFDictionaryAddValue(mutOption, kCGImageSourceThumbnailMaxPixelSize, (__bridge CFNumberRef)maxDimensionNum);
    
    CFDictionaryRef dowsamplingOption = CFDictionaryCreateCopy(NULL, mutOption);
    
    CGImageRef downSampleImageRef = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, dowsamplingOption);
    
    UIImage *img = [UIImage imageWithCGImage:downSampleImageRef];
    return img;
}

#pragma mark - lazy load
- (CIContext *)ciContext
{
    if (!_ciContext) {
        _ciContext = [[CIContext alloc] init];
    }
    return _ciContext;
}

#pragma mark - static
static OSType inputPixelFormat() {
    return kCVPixelFormatType_32BGRA;
}

static uint32_t bitmapInfoWithPixelFormatType(OSType inputPixelFormat, bool hasAlpha) {
    
    if (inputPixelFormat == kCVPixelFormatType_32BGRA) {
        uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Host;
        if (!hasAlpha) {
            bitmapInfo = kCGImageAlphaNoneSkipFirst | kCGBitmapByteOrder32Host;
        }
        return bitmapInfo;
    }else if (inputPixelFormat == kCVPixelFormatType_32ARGB) {
        uint32_t bitmapInfo = kCGImageAlphaPremultipliedFirst | kCGBitmapByteOrder32Big;
        return bitmapInfo;
    }else{
        NSLog(@"不支持此格式");
        return 0;
    }
}

// alpha的判断
static BOOL CGImageRefContainsAlpha(CGImageRef imageRef) {
    if (!imageRef) {
        return NO;
    }
    CGImageAlphaInfo alphaInfo = CGImageGetAlphaInfo(imageRef);
    BOOL hasAlpha = !(alphaInfo == kCGImageAlphaNone ||
                      alphaInfo == kCGImageAlphaNoneSkipFirst ||
                      alphaInfo == kCGImageAlphaNoneSkipLast);
    return hasAlpha;
}

static BOOL isGrayPixelWith(int r, int g, int b) {
    if (abs(r - g) > 10 || abs(g - b) > 10 || abs(b - r) > 10) {
        // 差异较大，不是灰度图像
        return NO;
    }
    // 差异较小，是灰度图像
    return YES;
}

static BOOL isColorRegion(NSArray<YYRGBPixelNode *>* nodes) {
    __block BOOL isColor = NO;
    [nodes enumerateObjectsUsingBlock:^(YYRGBPixelNode *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.isColorNode) {
            isColor = obj.isColorNode;
        
            *stop = YES;
            return;
        }
    }];
    
    return  isColor;
}
@end
