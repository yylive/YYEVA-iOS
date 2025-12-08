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

@interface YYPixelNode : NSObject
@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) NSUInteger y;
@property (nonatomic, assign) NSUInteger u;
@property (nonatomic, assign) NSUInteger v;
@property (nonatomic, assign) BOOL isColorNode;
@end

@implementation YYPixelNode
- (instancetype)init
{
    if (self = [super init]) {
        _y = 0;
        _u = 0;
        _v = 0;
        _point = CGPointZero;
    }
    return self;
}
@end

@interface YYEVARegionChecker()
@property (nonatomic, strong) AVURLAsset *asset;
@property (nonatomic, strong) AVAssetReader *reader;
@property (nonatomic, strong) AVAssetReaderTrackOutput *output;
@end

@implementation YYEVARegionChecker
- (YYEVAColorRegion)checkFile:(NSString *)url
{
    return [self checkFile:url CheckCount:3];
}

- (YYEVAColorRegion)checkFile:(NSString *)url CheckCount:(NSInteger) count
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
    
    for (int i = 0; i<count; i++) {
        @autoreleasepool {
            CMSampleBufferRef sampleBufferRef = [self getNextSampleBufferRefWithStep:i == 0 ? 1 : 10];
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
    
    size_t pWidth = CVPixelBufferGetWidth(yuvPixelBuffer);
    size_t pHeight = CVPixelBufferGetHeight(yuvPixelBuffer);

    //    抽取400个点
    NSUInteger sizePoint = 10;
    NSArray<YYPixelNode *> *LTNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(0, 0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:yuvPixelBuffer]; // 左上角
    NSArray<YYPixelNode *> *RTNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake( pWidth / 2.0, 0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:yuvPixelBuffer];// 右上角
    NSArray<YYPixelNode *> *LBNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(0, pHeight / 2.0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:yuvPixelBuffer]; // 左下角
    NSArray<YYPixelNode *> *RBNodes = [self getSquareSidePoints:sizePoint
                                                    PointsWithRect:CGRectMake(pWidth / 2.0, pHeight / 2.0, pWidth / 2.0, pHeight / 2.0)
                                                     InPixelBuffer:yuvPixelBuffer];// 右下角
    
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
    } else if ((LTIsColor || LBIsColor) && (!RTIsColor && !RBIsColor)) {
        NSLog(@"左彩色，右黑白，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_LeftColorRightGray;
    }  else if ((!LTIsColor && !LBIsColor) && (RTIsColor || RBIsColor)) {
        NSLog(@"左黑白，右彩色，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_LeftGrayRightColor;
    }  else if ((LTIsColor || RTIsColor) && (!LBIsColor && !RBIsColor)) {
        NSLog(@"上彩色，下黑白，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_TopColorBottomGray;
    }  else if ((!LTIsColor && !RTIsColor) && (LBIsColor || RBIsColor)) {
        NSLog(@"上黑白，下彩色，透明MP4");
        result = YYEVAColorRegion_AlphaMP4_TopGrayBottomColor;
    } else {
        NSLog(@"颜色区域分布不规则的MP4");
    }
    
    CVPixelBufferUnlockBaseAddress(yuvPixelBuffer, 0);
    return result;
}

//获取以pointNum个点为边长的矩形的所有点
- (NSArray *)getSquareSidePoints:(NSUInteger)pointNum
                  PointsWithRect:(CGRect)rect
          InPixelBuffer:(CVPixelBufferRef)pixelBuffer
{
    void (^block)(YYPixelNode *) = ^(YYPixelNode *node) {
        // 第一步：提前校验 pixelBuffer 非空，锁定内存（关键：CVPixelBuffer 访问前建议锁定）
        if (pixelBuffer == NULL) {
            NSLog(@"错误：pixelBuffer 为空");
            // 可根据业务逻辑返回默认值或退出
            return;
        }

        // 第二步：获取 Y、UV 平面数据和行宽，并校验空指针
        uint8_t *yPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        uint8_t *uvPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t yPitch = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        size_t uvPitch = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);

        // 校验 Y/UV 平面地址非空
        if (yPlane == NULL || uvPlane == NULL) {
            NSLog(@"错误：Y/UV 平面内存地址为空");
            return;
        }

        // 第三步：获取 Y/UV 平面的有效尺寸（用于越界校验）
        size_t yWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t yHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        size_t uvWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t uvHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);

        // 第四步：校验坐标是否在 Y 平面有效范围内（先校验坐标，再计算索引）
        if (node.point.x < 0 || node.point.x >= yWidth ||
            node.point.y < 0 || node.point.y >= yHeight) {
            NSLog(@"错误：Y 坐标越界！x = %.0f, y = %.0f，Y平面宽 = %zu, 高 = %zu",
                  node.point.x, node.point.y, yWidth, yHeight);
            return;
        }

        // 第五步：计算 Y 索引并校验（双重防护）
        unsigned long yIdx = node.point.y * yPitch + node.point.x;
        size_t yTotalBytes = yPitch * yHeight; // Y 平面总有效字节数
        if (yIdx >= yTotalBytes) {
            NSLog(@"错误：yIdx 越界！yIdx = %lu，Y平面总字节数 = %zu", yIdx, yTotalBytes);
            return;
        }

        // 第六步：校验 UV 坐标并计算索引（UV 平面是 Y 的 1/2，需单独校验）
        int uvX = (int)node.point.x >> 1;
        int uvY = (int)node.point.y >> 1;
        if (uvX < 0 || uvX >= uvWidth ||
            uvY < 0 || uvY >= uvHeight) {
            NSLog(@"错误：UV 坐标越界！uvX = %d, uvY = %d，UV平面宽 = %zu, 高 = %zu",
                  uvX, uvY, uvWidth, uvHeight);
            return;
        }

        // 计算 UV 索引并校验（包含 uvIdx + 1 的边界）
        unsigned long uvIdx = uvY * uvPitch + (uvX << 1);
        size_t uvTotalBytes = uvPitch * uvHeight; // UV 平面总有效字节数
        if (uvIdx + 1 >= uvTotalBytes) { // 校验 uvIdx 和 uvIdx + 1 都不越界
            NSLog(@"错误：uvIdx 越界！uvIdx = %lu，UV平面总字节数 = %zu", uvIdx, uvTotalBytes);
            return;
        }

        // 第七步：安全访问 YUV 分量
        int y = yPlane[yIdx];
        int u = uvPlane[uvIdx];
        int v = uvPlane[uvIdx + 1];
        
        BOOL isGray = isGrayPixelWith(u, v);
        
        node.y = y;
        node.u = u;
        node.v = v;
        node.isColorNode = !isGray;
    };
    
    NSMutableArray *result = @[].mutableCopy;
    int xStep = floor(rect.size.width / (pointNum + 1));
    int yStep = floor(rect.size.height / (pointNum + 1));
    
    for (int col = 0; col < pointNum; col++) {
        @autoreleasepool {
            int y = rect.origin.y + (col + 1) * yStep;
            
            for (int row = 0; row < pointNum; row++) {
                int x = rect.origin.x + (row + 1) * xStep;
                YYPixelNode *node = [YYPixelNode new];
                node.point = CGPointMake(x, y);
                
                block(node);
                
                [result addObject:node];
            }
        }
    }
    
    return result.copy;
}

#pragma mark - get something
- (CMSampleBufferRef)getNextSampleBufferRefWithStep:(NSInteger)step {
    CMSampleBufferRef sampleBufferRef = NULL;
    if (_reader.status == AVAssetReaderStatusReading) {
        for (int i = 0; i < step; i++) {
            sampleBufferRef = [_output copyNextSampleBuffer];
            if (i != step-1) {
                CMSampleBufferInvalidate(sampleBufferRef);
                CFRelease(sampleBufferRef);
            }
        }
    }
    
    return sampleBufferRef;
}


static BOOL isGrayPixelWith(int u, int v) {
    int tolerance = 10;
    // 允许一定容差，判断该像素是否为灰度像素
    if (abs(u - 128) <= tolerance && abs(v - 128) <= tolerance) {
        return YES;
    }
    
    return NO;
}

static BOOL isColorRegion(NSArray<YYPixelNode *>* nodes) {
    __block BOOL isColor = NO;
    [nodes enumerateObjectsUsingBlock:^(YYPixelNode *  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.isColorNode) {
            isColor = obj.isColorNode;
        
            *stop = YES;
            return;
        }
    }];
    
    return  isColor;
}
@end
