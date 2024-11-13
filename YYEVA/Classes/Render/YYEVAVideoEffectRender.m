//
//  YYEVAVideoEffectRender.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import "YYEVAVideoEffectRender.h"
#import "YYEVAAssets.h"
#include "YYEVAVideoShareTypes.h"
#import "YYEVAEffectInfo.h"
#import "YSVideoMetalUtils.h"
#import <UIKit/UIImageView.h>

extern matrix_float3x3 kColorConversion601FullRangeMatrix;
extern vector_float3 kColorConversion601FullRangeOffset;

@interface YYEVAVideoEffectRender()
{
    float _imageVertices[8];
    float _bgImageVertices[8];
}
@property (nonatomic, weak) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> defaultRenderPipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> bgRenderPipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> mergeRenderPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, strong) id<MTLBuffer> elementVertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> bgVertexBuffer;
@property (nonatomic, strong) id<MTLTexture> bgImageTexture;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, assign) NSInteger numVertices;
@property (nonatomic, assign) NSInteger bgNumVertices;
@property (nonatomic, copy) NSString *bgImageUrl;
@property (nonatomic, assign) UIViewContentMode bgContentMode;
@end

@implementation YYEVAVideoEffectRender
@synthesize completionPlayBlock;
@synthesize playAssets;
@synthesize fillMode = _fillMode;
@synthesize disalbleMetalCache = _disalbleMetalCache;

- (instancetype)initWithMetalView:(MTKView *)mtkView
{
    if (self = [super init]) {
        [self setupRenderWithMetal:mtkView]; 
    }
    return self;
}

- (void)dealloc
{
    CFRelease(_textureCache); 
}


- (void)setFillMode:(YYEVAFillMode)fillMode
{
    _fillMode = fillMode;
    [self setupVertex];
}
  
- (void)setBgImageUrl:(NSString *)bgImageUrl contentMode:(UIViewContentMode)bgContentMode
{
    self.bgImageUrl = bgImageUrl;
    self.bgContentMode = bgContentMode;
    
    [self recalculateBGViewGeometry];
}

- (void)playWithAssets:(YYEVAAssets *)assets
{
    self.playAssets = assets;
    [self setupVertex];
    NSDictionary *cacheAttributes = @{
        (id)kCVMetalTextureCacheMaximumTextureAgeKey: @(0.01),
    };
    CVMetalTextureCacheCreate(NULL, self.disalbleMetalCache ? (__bridge CFDictionaryRef)cacheAttributes : NULL, self.mtkView.device, NULL, &_textureCache);
}

- (void)setupRenderWithMetal:(MTKView *)mtkView
{
    _mtkView = mtkView;
    _device = mtkView.device;
    [self setupFragment];
    _commandQueue = [_device newCommandQueue];
    self.viewportSize = (vector_uint2){self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
}

- (NSString *)metalFilePath
{
    NSString *filePath =  [[NSBundle bundleForClass:[self class]] pathForResource:@"YYEVABundle.bundle/default" ofType:@"metallib"];
#ifdef SWIFTPM_MODULE_BUNDLE
    if (filePath.length == 0) {
        NSBundle *swiftPMBundle = SWIFTPM_MODULE_BUNDLE;
        filePath = [swiftPMBundle pathForResource:@"default" ofType:@"metallib"];
    }
#endif
    return filePath;
}


- (void)recalculateViewGeometry
{
     
    NSArray *imgVerices = [self calculateGeometry:self.playAssets.rgbSize
                                     drawableSize:self.mtkView.bounds.size
                                         fillMode:(UIViewContentMode)self.fillMode];
    
    self->_imageVertices[0] = [imgVerices[0] floatValue];
    self->_imageVertices[1] = [imgVerices[1] floatValue];
    self->_imageVertices[2] = [imgVerices[2] floatValue];
    self->_imageVertices[3] = [imgVerices[3] floatValue];
    self->_imageVertices[4] = [imgVerices[4] floatValue];
    self->_imageVertices[5] = [imgVerices[5] floatValue];
    self->_imageVertices[6] = [imgVerices[6] floatValue];
    self->_imageVertices[7] = [imgVerices[7] floatValue];
}


- (void)recalculateBGViewGeometry
{
    CGSize size = CGSizeZero;
    
    if (self.bgImageUrl.length > 0) {
        UIImage *bgImage = [UIImage imageNamed:self.bgImageUrl];
        size = bgImage.size;
        self.bgImageTexture = [self loadTextureWithImage:bgImage
                                                  device:self.device];
    }
     
    NSArray *imgVerices = [self calculateGeometry:size
                                     drawableSize:self.mtkView.bounds.size
                                         fillMode:(UIViewContentMode)self.bgContentMode];
    
    self->_bgImageVertices[0] = [imgVerices[0] floatValue];
    self->_bgImageVertices[1] = [imgVerices[1] floatValue];
    self->_bgImageVertices[2] = [imgVerices[2] floatValue];
    self->_bgImageVertices[3] = [imgVerices[3] floatValue];
    self->_bgImageVertices[4] = [imgVerices[4] floatValue];
    self->_bgImageVertices[5] = [imgVerices[5] floatValue];
    self->_bgImageVertices[6] = [imgVerices[6] floatValue];
    self->_bgImageVertices[7] = [imgVerices[7] floatValue];
    
    
    YSVideoMetalVertex quadVertices[] =
    {   // 顶点坐标，分别是x、y、z；    纹理坐标，x、y；
        { { self->_bgImageVertices[0], self->_bgImageVertices[1], 0.0 ,1.0},  { 0.f, 0.0f} },
        { { self->_bgImageVertices[2],  self->_bgImageVertices[3], 0.0 ,1.0},  { 0.f, 1.0f } },
        { { self->_bgImageVertices[4], self->_bgImageVertices[5], 0.0,1.0 },  { 1.f, 0.f } },
        { { self->_bgImageVertices[6], self->_bgImageVertices[7], 0.0,1.0 },  { 1.f, 1.f } }
    };
    
    //2.创建顶点缓存区
    self.bgVertexBuffer = [self.mtkView.device newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared];
    //3.计算顶点个数
    self.bgNumVertices = sizeof(quadVertices) / sizeof(YSVideoMetalVertex);
}

- (NSArray *)calculateGeometry:(CGSize)size
                  drawableSize:(CGSize)drawableSize
                      fillMode:(UIViewContentMode)mode
{
    drawableSize = CGSizeMake(drawableSize.width * 2, drawableSize.height * 2);
    CGFloat maxRatio = MAX( drawableSize.width / size.width , drawableSize.height / size.height);
    CGFloat lowRatio = MIN( drawableSize.width / size.width , drawableSize.height / size.height);
    
    CGFloat wRatio = 1.0;
    CGFloat hRatio = 1.0;
    
    CGFloat realWidth = 1.0;
    CGFloat realHeight = 1.0;
    
    switch (mode) {
        case UIViewContentModeScaleAspectFit:
            realWidth = lowRatio * size.width;
            realHeight = lowRatio * size.height;
            wRatio = realWidth / drawableSize.width;
            hRatio = realHeight / drawableSize.height;
            break;
        case UIViewContentModeScaleAspectFill:
            
            realWidth = maxRatio * size.width;
            realHeight = maxRatio * size.height;
            wRatio = realWidth / drawableSize.width;
             hRatio = realHeight / drawableSize.height;
            break;
        default:
            wRatio = 1.0;
            hRatio = 1.0;
            break;
    }
    
    NSArray *vertics = @[@(-wRatio),@(-hRatio),@(-wRatio),@(hRatio),@(wRatio),@(-hRatio),@(wRatio),@(hRatio)];
    return vertics;
}


 
// 设置顶点
- (void)setupVertex
{
    [self recalculateViewGeometry];
    
      
    //需要将assets的描述信息来构建顶点和纹理数据
    YYEVAEffectInfo *effectInfo = self.playAssets.effectInfo;
     
//    float static kVAPMTLVerticesIdentity[16] = {
//                    -1.0f, -1.0f, 0.0f,1.0f, //顶点1
//                    -1.0f,  1.0f, 0.0f,1.0f,  //顶点2
//                     1.0f, -1.0f, 0.0f,1.0f,  //顶点3
//                     1.0f,  1.0f, 0.0f,1.0f    //顶点4
//    };
    
    float kVAPMTLVerticesIdentity[16] =
    {   // 顶点坐标，分别是x、y、z；    纹理坐标，x、y；
         self->_imageVertices[0], self->_imageVertices[1], 0.0 ,1.0,
         self->_imageVertices[2],  self->_imageVertices[3], 0.0 ,1.0,
         self->_imageVertices[4], self->_imageVertices[5], 0.0,1.0 ,
         self->_imageVertices[6], self->_imageVertices[7], 0.0,1.0,
    };
     
    const int colunmCountForVertices = 4;
    const int colunmCountForCoordinate = 2;
    const int vertexDataLength = 32;
    static float vertexData[vertexDataLength];
    float rgbCoordinates[8],alphaCoordinates[8];
    //计算顶点数据  3个字节
    const void *vertices = kVAPMTLVerticesIdentity;
    
    //计算rgb的纹理坐标  2个字节 CGRect rect,CGSize containerSize,float coordinate[8]
    CGSize videoSize = CGSizeMake(effectInfo.videoWidth, effectInfo.videoHeight);
    textureCoordinateFromRect(effectInfo.rgbFrame,videoSize,rgbCoordinates);
    textureCoordinateFromRect(effectInfo.alphaFrame,videoSize,alphaCoordinates);
      
    int indexForVertexData = 0;
    //顶点数据+坐标。==> 这里的写法需有优化一下
    for (int i = 0; i < 4 * colunmCountForVertices; i ++) {
         
        //顶点数据
        vertexData[indexForVertexData++] = ((float*)vertices)[i];
        //逐行处理
        if (i%colunmCountForVertices == colunmCountForVertices-1) {
            int row = i/colunmCountForVertices;
            //rgb纹理坐标
            vertexData[indexForVertexData++] = ((float*)rgbCoordinates)[row*colunmCountForCoordinate];
            vertexData[indexForVertexData++] = ((float*)rgbCoordinates)[row*colunmCountForCoordinate+1];
            //alpha纹理坐标
            vertexData[indexForVertexData++] = ((float*)alphaCoordinates)[row*colunmCountForCoordinate];
            vertexData[indexForVertexData++] = ((float*)alphaCoordinates)[row*colunmCountForCoordinate+1];
        }
    }
    float *a = vertexData;
    YSVideoMetalMaskVertex metalVertexts[4];
    for (NSInteger i = 0; i < 4; i++) {
        metalVertexts[i].positon.x = *a++;
        metalVertexts[i].positon.y = *a++;
        metalVertexts[i].positon.z = *a++;
        metalVertexts[i].positon.w = *a++;
        
        metalVertexts[i].rgbTexturCoordinate.x = *a++;
        metalVertexts[i].rgbTexturCoordinate.y = *a++;
        
        metalVertexts[i].alphaTexturCoordinate.x = *a++;
        metalVertexts[i].alphaTexturCoordinate.y = *a++;
    }
     
     
    id<MTLBuffer> vertexBuffer = [self.device newBufferWithBytes:metalVertexts length: sizeof(metalVertexts)  options:MTLResourceStorageModeShared];
    self.numVertices = sizeof(metalVertexts) / sizeof(YSVideoMetalMaskVertex);
    _vertexBuffer = vertexBuffer;
    
}


- (void)setupFragment
{
    //转化矩阵和偏移量都是固定规则，无需纠结为什么这样设置，行业标准，不属于我们学习的范畴
    //转化矩阵
    //3.创建转化矩阵结构体.
    YSVideoMetalConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    self.convertMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                        length:sizeof(YSVideoMetalConvertMatrix)
                                                options:MTLResourceStorageModeShared];
     
}


#pragma mark -- MTKView Delegate
//当MTKView size 改变则修改self.viewportSize
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    self.viewportSize = (vector_uint2){size.width, size.height};
    
    [self setupVertex];
}

//视图绘制
- (void)drawInMTKView:(MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    CMSampleBufferRef sampleBuffer = [self.playAssets nextSampleBuffer];
     
        //获取megerInfo
    YYEVAEffectInfo *effectInfo = self.playAssets.effectInfo;
    NSDictionary *dictionary = effectInfo.frames;
    NSArray <YYEVAEffectFrame *> *mergeInfoList = [dictionary objectForKey:@(self.playAssets.frameIndex)];

    if(renderPassDescriptor && sampleBuffer)
    {
        //设置renderPassDescriptor中颜色附着(默认背景色)
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0f);
        //根据渲染描述信息创建渲染命令编码器
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        //设置视口大小(显示区域)
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
 
        if (self.bgImageTexture != nil) {
            [self drawBgWithRenderCommandEncoder:renderEncoder
                                        texture:self.bgImageTexture];
        }
        
        
        //MP4纹理
        id<MTLTexture> textureY = [self getTextureFromSampleBuffer:sampleBuffer
                                                        planeIndex:0
                                                       pixelFormat:MTLPixelFormatR8Unorm];
        id<MTLTexture> textureUV = [self getTextureFromSampleBuffer:sampleBuffer
                                                         planeIndex:1 pixelFormat:MTLPixelFormatRG8Unorm];
        
        [self drawVideoSampleWithRenderCommandEncoder:renderEncoder
                                            textureY:textureY
                                           textureUV:textureUV];
        
        
        if (mergeInfoList) {
            [self drawMergedAttachments:mergeInfoList
                               yTexture:textureY
                              uvTexture:textureUV
                          renderEncoder:renderEncoder];
        }

        [renderEncoder endEncoding];
        //绘制
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    } else {
        if (![self.playAssets hasNextSampleBuffer]) {
            if (self.completionPlayBlock) {
                self.completionPlayBlock();
            }
        }
    }
    
    if (sampleBuffer) {
        CMSampleBufferInvalidate(sampleBuffer);
        CFRelease(sampleBuffer);
    }
    
   
}
 
- (void)drawMergedAttachments:(NSArray<YYEVAEffectFrame *> *)merges
                       yTexture:(id<MTLTexture>)yTexture
                      uvTexture:(id<MTLTexture>)uvTexture
                  renderEncoder:(id<MTLRenderCommandEncoder>)encoder
{
    if (merges.count > 0) {
        [merges enumerateObjectsUsingBlock:^(YYEVAEffectFrame * _Nonnull mergeInfo, NSUInteger idx, BOOL * _Nonnull stop) {
            CGSize videoSize = self.playAssets.size;
            CGSize size = self.playAssets.effectInfo.rgbFrame.size;
            [encoder setRenderPipelineState:self.mergeRenderPipelineState];
            
            //构造YSVideoMetalElementVertex：「
            //    vector_float4 positon;  4
            //    vector_float2 sourceTextureCoordinate; 2
            //    vector_float2 maskTextureCoordinate; 2
            // 」
            CGSize renderSize = CGSizeZero;
            id<MTLBuffer> vertexBuffer = [mergeInfo vertexBufferWithContainerSize:size
                                                                maskContianerSize:videoSize
                                                                           device:self.device
                                                                         fillMode:self.fillMode
                                                                         trueSize:self.mtkView.bounds.size
                                                                       renderSize:&renderSize];
            
            id<MTLTexture> sourceTexture = mergeInfo.src.texture;
            if (!sourceTexture) {
                sourceTexture =  [self loadTextureWithImage:mergeInfo.src.sourceImage
                                                     device:_device
                                                   trueSize:self.mtkView.bounds.size
                                              containerSize:renderSize
                                              videoFillMode:self.fillMode
                                                   fillMode:mergeInfo.src.fillMode]; //图片纹理
                mergeInfo.src.texture = sourceTexture;
            }
            
            
            id<MTLBuffer> colorParamsBuffer = mergeInfo.src.colorParamsBuffer;
            id<MTLBuffer> convertMatrix = self.convertMatrix;
            if (!sourceTexture || !vertexBuffer || !convertMatrix) {
                return ;
            }
            [encoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
            [encoder setFragmentBuffer:convertMatrix offset:0 atIndex:0];
            [encoder setFragmentBuffer:colorParamsBuffer offset:0 atIndex:1];
            //遮罩信息在视频流中
            [encoder setFragmentTexture:yTexture atIndex:0];
            [encoder setFragmentTexture:uvTexture atIndex:1];
            [encoder setFragmentTexture:sourceTexture atIndex:2];
             
            [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4 instanceCount:1];
            
            //
            //
            //json -> bin
        }];
    }
}

- (id<MTLTexture>)loadTextureWithImage:(UIImage *)image device:(id<MTLDevice>)device {
    
    if (!image) {
        return nil;
    }
    if (@available(iOS 10.0, *)) {
        MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
        NSError *error = nil;
        
        
         
        
        id<MTLTexture> texture = [loader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionOrigin : MTKTextureLoaderOriginFlippedVertically} error:&error];
        if (!texture || error) {
            return nil;
        }
        return texture;
    }
    return nil;
}
 

- (id<MTLTexture>)loadTextureWithImage:(UIImage *)image
                                device:(id<MTLDevice>)device
                              trueSize:(CGSize)trueSize
                         containerSize:(CGSize)containerSize
                         videoFillMode:(YYEVAFillMode)videoFillMode
                              fillMode:(YYEVAEffectSourceImageFillMode)fillMode{
    
    if (!image) {
        return nil;
    }
    if (@available(iOS 10.0, *)) {
        MTKTextureLoader *loader = [[MTKTextureLoader alloc] initWithDevice:device];
        NSError *error = nil;
        //trueSize 传的是pt  设计师计算的是两倍的像素
        CGSize drawableSize = CGSizeMake(trueSize.width * 2, trueSize.height * 2);
        CGFloat maxRatio = MAX( drawableSize.width / containerSize.width , drawableSize.height / containerSize.height);
        CGFloat lowRatio = MIN( drawableSize.width / containerSize.width , drawableSize.height / containerSize.height);
        CGFloat realWidth = 0.0;
        CGFloat realHeight = 0.0;
        
        switch (videoFillMode) {
            case YYEVAContentMode_ScaleToFill:
                realWidth =   containerSize.width;
                realHeight =  containerSize.height;
                break;

            case YYEVAContentMode_ScaleAspectFit:
                realWidth = lowRatio * containerSize.width;
                realHeight = lowRatio * containerSize.height;
                break;

            case YYEVAContentMode_ScaleAspectFill:
                realWidth = maxRatio * containerSize.width;
                realHeight = maxRatio * containerSize.height;
                break;
        }
        
        UIImageView *imgView;
          
        switch (fillMode) {
            case YYEVAEffectSourceImageFillModeAspectFit:
            {
                imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, realWidth, realHeight)];
                imgView.contentMode = UIViewContentModeScaleAspectFit;
                imgView.image = image;
                imgView.clipsToBounds = YES;
                UIGraphicsBeginImageContextWithOptions(imgView.frame.size, NO, [UIScreen mainScreen].scale);
                [imgView.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                image = snapshotImage;
            }
               
                break;

            case YYEVAEffectSourceImageFillModeAspectFill:
            {
                imgView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, realWidth, realHeight)];
                imgView.contentMode = UIViewContentModeScaleAspectFill;
                imgView.image = image;
                imgView.clipsToBounds = YES;
                UIGraphicsBeginImageContextWithOptions(imgView.frame.size, NO, [UIScreen mainScreen].scale);
                [imgView.layer renderInContext:UIGraphicsGetCurrentContext()];
                UIImage *snapshotImage = UIGraphicsGetImageFromCurrentImageContext();
                UIGraphicsEndImageContext();
                image = snapshotImage;
            }
                
                break;
            default:
                break;
        }
        
          
        id<MTLTexture> texture = [loader newTextureWithCGImage:image.CGImage options:@{MTKTextureLoaderOptionOrigin : MTKTextureLoaderOriginFlippedVertically} error:&error];
        if (!texture || error) {
            return nil;
        }
        return texture;
    }
    return nil;
}

- (void)drawVideoSampleWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder
                                      textureY:(id<MTLTexture>)textureY
                                     textureUV:(id<MTLTexture>)textureUV
{
    [renderCommandEncoder setRenderPipelineState:self.defaultRenderPipelineState];
    [self setupVertexFunctionData:renderCommandEncoder];
    
    //设置转换矩阵
    [renderCommandEncoder setFragmentBuffer:self.convertMatrix offset:0 atIndex:YSVideoMetalFragmentBufferIndexMatrix];
    
    if (textureY && textureUV) {
        [renderCommandEncoder setFragmentTexture:textureY atIndex:YSVideoMetalFragmentTextureIndexTextureY];
        [renderCommandEncoder setFragmentTexture:textureUV atIndex:YSVideoMetalFragmentTextureIndexTextureUV];
    }
    
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                      vertexStart:0
                      vertexCount:self.numVertices];
}


- (void)drawBgWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder
                               texture:(id<MTLTexture>)texture
{
    [renderCommandEncoder setRenderPipelineState:self.bgRenderPipelineState];
    [renderCommandEncoder setVertexBuffer:self.bgVertexBuffer offset:0 atIndex:YSVideoMetalVertexInputIndexVertices];
    
    //设置转换矩阵
    [renderCommandEncoder setFragmentBuffer:self.convertMatrix offset:0 atIndex:YSVideoMetalFragmentBufferIndexMatrix];
    
    if (texture) {
        [renderCommandEncoder setFragmentTexture:texture atIndex:YSVideoMetalFragmentTextureIndexTextureY];
    }
    
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                      vertexStart:0
                      vertexCount:self.bgNumVertices];
}

- (void)setupVertexFunctionData:(id<MTLRenderCommandEncoder>)renderCommandEncoder
{
    //设置顶点数据和纹理坐标
    [renderCommandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:YSVideoMetalVertexInputIndexVertices];
}
 

//如果图像缓冲区是平面的，则为映射纹理数据的平面索引。对于非平面图像缓冲区忽
- (id<MTLTexture>)getTextureFromPixelBufferRef:(CVPixelBufferRef)pixelBufferRef
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
{
    //设置yuv纹理数据
    if (pixelBufferRef == NULL) {
        return nil;
    }
    id<MTLTexture> texture = [YSVideoMetalUtils getTextureFromPixelBuffer:pixelBufferRef
                                             planeIndex:planeIndex
                                            pixelFormat:pixelFormat
                                                 device:self.device textureCache:self.textureCache];
    return texture;
}

//如果图像缓冲区是平面的，则为映射纹理数据的平面索引。对于非平面图像缓冲区忽
- (id<MTLTexture>)getTextureFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
{
    //设置yuv纹理数据
    CVPixelBufferRef pixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (pixelBufferRef == NULL) {
        return nil;
    }
    id<MTLTexture> texture = [YSVideoMetalUtils getTextureFromPixelBuffer:pixelBufferRef
                                             planeIndex:planeIndex
                                            pixelFormat:pixelFormat
                                                 device:self.device textureCache:self.textureCache];
    return texture;
}
 
- (id<MTLRenderPipelineState>)mergeRenderPipelineState
{
    if (!_mergeRenderPipelineState) {
        id<MTLLibrary> library = [_device newLibraryWithFile:[self metalFilePath] error:nil];
        id<MTLFunction> vertexFunction = [library newFunctionWithName:@"elementVertexShader"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"elementFragmentSharder"];
        
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        renderPipelineDescriptor.vertexFunction = vertexFunction;
        renderPipelineDescriptor.fragmentFunction = fragmentFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
        [renderPipelineDescriptor.colorAttachments[0] setBlendingEnabled:YES];
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor =  MTLBlendFactorSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        _mergeRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    }
    return _mergeRenderPipelineState;
}

- (id<MTLRenderPipelineState>)defaultRenderPipelineState
{
    if (!_defaultRenderPipelineState) {
        id<MTLLibrary> library = [_device newLibraryWithFile:[self metalFilePath] error:nil];
        id<MTLFunction> vertexFunction = [library newFunctionWithName:@"maskVertexShader"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"maskFragmentSharder"];
        
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        renderPipelineDescriptor.vertexFunction = vertexFunction;
        renderPipelineDescriptor.fragmentFunction = fragmentFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
        [renderPipelineDescriptor.colorAttachments[0] setBlendingEnabled:YES];
        renderPipelineDescriptor.colorAttachments[0].rgbBlendOperation = MTLBlendOperationAdd;
        renderPipelineDescriptor.colorAttachments[0].alphaBlendOperation = MTLBlendOperationAdd;
        renderPipelineDescriptor.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].sourceAlphaBlendFactor =  MTLBlendFactorSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
        _defaultRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    }
    return _defaultRenderPipelineState;
}

- (id<MTLRenderPipelineState>)bgRenderPipelineState
{
    if (!_bgRenderPipelineState) {
        id<MTLLibrary> library = [_device newLibraryWithFile:[self metalFilePath] error:nil];
        id<MTLFunction> vertexFunction = [library newFunctionWithName:@"bgVertexShader"];
        id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"bgFragmentSharder"];
        
        MTLRenderPipelineDescriptor *renderPipelineDescriptor = [[MTLRenderPipelineDescriptor alloc] init];
        renderPipelineDescriptor.vertexFunction = vertexFunction;
        renderPipelineDescriptor.fragmentFunction = fragmentFunction;
        renderPipelineDescriptor.colorAttachments[0].pixelFormat = _mtkView.colorPixelFormat;
        _bgRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    }
    return _bgRenderPipelineState;
}

- (CVPixelBufferRef)syszuxPixelBufferFromUIImage:(UIImage *)originImage {
    CGImageRef image = originImage.CGImage;
    NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                             [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                             nil];

    CVPixelBufferRef pxbuffer = NULL;
    CGFloat frameWidth = CGImageGetWidth(image);
    CGFloat frameHeight = CGImageGetHeight(image);
    CVReturn status = CVPixelBufferCreate(kCFAllocatorDefault,
                                          frameWidth,
                                          frameHeight,
                                          kCVPixelFormatType_32ARGB,
                                          (__bridge CFDictionaryRef) options,
                                          &pxbuffer);

    NSParameterAssert(status == kCVReturnSuccess && pxbuffer != NULL);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata,
                                                 frameWidth,
                                                 frameHeight,
                                                 8,
                                                 CVPixelBufferGetBytesPerRow(pxbuffer),
                                                 rgbColorSpace,
                                                 (CGBitmapInfo)kCGImageAlphaNoneSkipFirst);
    NSParameterAssert(context);
    CGContextConcatCTM(context, CGAffineTransformIdentity);
    CGContextDrawImage(context, CGRectMake(0,
                                           0,
                                           frameWidth,
                                           frameHeight),
                       image);
    CGColorSpaceRelease(rgbColorSpace);
    CGContextRelease(context);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
    return pxbuffer;
}
 
 
@end


