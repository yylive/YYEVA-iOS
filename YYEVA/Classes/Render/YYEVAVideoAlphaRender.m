//
//  YYEVAVideoAlphaRender.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import "YYEVAVideoAlphaRender.h"
#import "YYEVAAssets.h"
#include "YYEVAVideoShareTypes.h"
#import "YSVideoMetalUtils.h"
extern matrix_float3x3 kColorConversion601FullRangeMatrix;
extern vector_float3 kColorConversion601FullRangeOffset;

@interface YYEVAVideoAlphaRender()
{
    float _imageVertices[8];
}
@property (nonatomic, weak) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong)  id<MTLLibrary> library;
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, strong) id<MTLBuffer> elementVertexBuffer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, assign) NSInteger numVertices;
@property (nonatomic, strong) NSMutableDictionary *fragmentFunctionDict;
@end

@implementation YYEVAVideoAlphaRender
@synthesize completionPlayBlock;
@synthesize playAssets;
@synthesize fillMode = _fillMode;
@synthesize disalbleMetalCache = _disalbleMetalCache;


- (void)dealloc
{
    CFRelease(_textureCache);
}

- (instancetype)initWithMetalView:(MTKView *)mtkView
{
    if (self = [super init]) {
        [self setupRenderWithMetal:mtkView];
    }
    return self;
}

- (void)setFillMode:(YYEVAFillMode)fillMode
{
    _fillMode = fillMode;
    [self setupVertex];
}
 
- (void)playWithAssets:(YYEVAAssets *)assets
{
    self.playAssets = assets;
    [self setupVertex];

    id<MTLFunction> vertexFunction = [self.library newFunctionWithName:@"normalVertexShader"];
    id<MTLFunction> fragmentFunction = [self.fragmentFunctionDict objectForKey:@"LCRGFragmentSharder"];
    
    if (self.playAssets.region == YYEVAColorRegion_AlphaMP4_LeftGrayRightColor) {
        fragmentFunction = [self.fragmentFunctionDict objectForKey:@"LGRCFragmentSharder"];
    } else if (self.playAssets.region == YYEVAColorRegion_AlphaMP4_TopColorBottomGray) {
        fragmentFunction = [self.fragmentFunctionDict objectForKey:@"TCBGFragmentSharder"];
    } else if (self.playAssets.region == YYEVAColorRegion_AlphaMP4_TopGrayBottomColor) {
        fragmentFunction = [self.fragmentFunctionDict objectForKey:@"TGBCFragmentSharder"];
    } else if (self.playAssets.region == YYEVAColorRegion_AlphaMP4_alphaHalfRightTop) {
        fragmentFunction = [self.fragmentFunctionDict objectForKey:@"AHTRFragmentSharder"];
    }
    
    MTLRenderPipelineDescriptor *renderPipelineDescriptor = [self getRenderPipelineDescriptorWithVertexFunction:vertexFunction FragmentFunction:fragmentFunction];
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    
    NSDictionary *cacheAttributes = @{
        (id)kCVMetalTextureCacheMaximumTextureAgeKey: @(0.01),
    };
    CVMetalTextureCacheCreate(NULL, self.disalbleMetalCache ? (__bridge CFDictionaryRef)cacheAttributes : NULL, self.mtkView.device, NULL, &_textureCache);
}


- (void)setupRenderWithMetal:(MTKView *)mtkView
{
    _mtkView = mtkView;
    _device = mtkView.device;
    [self setupRenderPiplineState];
    [self setupVertex];
    [self setupFragment];
    self.viewportSize = (vector_uint2){self.mtkView.drawableSize.width, self.mtkView.drawableSize.height};
}

- (void)setupRenderPiplineState
{
    NSString *filePath = [[NSBundle bundleForClass:[self class]] pathForResource:@"YYEVABundle.bundle/default" ofType:@"metallib"];
#ifdef SWIFTPM_MODULE_BUNDLE
    NSBundle *swiftPMBundle = SWIFTPM_MODULE_BUNDLE;
    filePath = [swiftPMBundle pathForResource:@"default" ofType:@"metallib"];
#endif
    _library = [_device newLibraryWithFile:filePath error:nil];
    id<MTLFunction> vertexFunction = [_library newFunctionWithName:@"normalVertexShader"];
    id<MTLFunction> fragmentFunction1 = [_library newFunctionWithName:@"LCRGFragmentSharder"];
    id<MTLFunction> fragmentFunction2 = [_library newFunctionWithName:@"LGRCFragmentSharder"];
    id<MTLFunction> fragmentFunction3 = [_library newFunctionWithName:@"TCBGFragmentSharder"];
    id<MTLFunction> fragmentFunction4 = [_library newFunctionWithName:@"TGBCFragmentSharder"];
    id<MTLFunction> fragmentFunction5 = [_library newFunctionWithName:@"AHTRFragmentSharder"];

    [self.fragmentFunctionDict setObject:fragmentFunction1 forKey:@"LCRGFragmentSharder"];
    [self.fragmentFunctionDict setObject:fragmentFunction2 forKey:@"LGRCFragmentSharder"];
    [self.fragmentFunctionDict setObject:fragmentFunction3 forKey:@"TCBGFragmentSharder"];
    [self.fragmentFunctionDict setObject:fragmentFunction4 forKey:@"TGBCFragmentSharder"];
    [self.fragmentFunctionDict setObject:fragmentFunction5 forKey:@"AHTRFragmentSharder"];

    MTLRenderPipelineDescriptor *renderPipelineDescriptor = [self getRenderPipelineDescriptorWithVertexFunction:vertexFunction FragmentFunction:fragmentFunction1];
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    
    _commandQueue = [_device newCommandQueue];
}

- (MTLRenderPipelineDescriptor *)getRenderPipelineDescriptorWithVertexFunction:( id<MTLFunction>)vertexFunction
                                                              FragmentFunction:(id<MTLFunction>)fragmentFunction
{
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
    
    return renderPipelineDescriptor;
}

- (void)recalculateViewGeometry
{
    float heightScaling = 1.0;
    float widthScaling = 1.0;
    CGSize drawableSize = self.mtkView.bounds.size;
    CGRect bounds = CGRectMake(0, 0, drawableSize.width, drawableSize.height);
    CGRect insetRect = AVMakeRectWithAspectRatioInsideRect(self.playAssets.rgbSize, bounds);

    widthScaling = drawableSize.width / insetRect.size.width;
    heightScaling = drawableSize.height / insetRect.size.height;
    
    CGFloat wRatio = 1.0;
    CGFloat hRatio = 1.0;
    CGFloat scale = self.playAssets.rgbSize.height / self.playAssets.rgbSize.width;
    
    switch (self.fillMode) {
        case YYEVAContentMode_ScaleAspectFit:
            if (widthScaling > heightScaling) {
                hRatio = 1;
                CGFloat width = drawableSize.height / scale;
                wRatio = width / drawableSize.width;
            } else {
                wRatio = 1;
                CGFloat height = drawableSize.width * scale;
                hRatio = height / drawableSize.height;
            }
            break;
        case YYEVAContentMode_ScaleAspectFill:
            if (widthScaling < heightScaling) {
                hRatio = 1;
                CGFloat width = drawableSize.height / scale;
                wRatio = width / drawableSize.width;
            } else {
                wRatio = 1;
                CGFloat height = drawableSize.width * scale;
                hRatio = height / drawableSize.height;
            }
            break;
        default:
            wRatio = 1.0;
            hRatio = 1.0;
            break;
    }
    self->_imageVertices[0] = -wRatio;
    self->_imageVertices[1] = -hRatio;
    self->_imageVertices[2] = -wRatio;
    self->_imageVertices[3] = hRatio;
    self->_imageVertices[4] = wRatio;
    self->_imageVertices[5] = -hRatio;
    self->_imageVertices[6] = wRatio;
    self->_imageVertices[7] = hRatio;
    NSLog(@"w %@, h %@", @(wRatio), @(hRatio));
}



// 设置顶点
- (void)setupVertex {
      
    [self recalculateViewGeometry];
    
    YSVideoMetalVertex quadVertices[] =
    {   // 顶点坐标，分别是x、y、z；    纹理坐标，x、y；
        { { self->_imageVertices[0], self->_imageVertices[1], 0.0 ,1.0},  { 0.f, 1.f} },
        { { self->_imageVertices[2],  self->_imageVertices[3], 0.0 ,1.0},  { 0.f, 0.0f } },
        { { self->_imageVertices[4], self->_imageVertices[5], 0.0,1.0 },  { 1.f, 1.f } },
        { { self->_imageVertices[6], self->_imageVertices[7], 0.0,1.0 },  { 1.f, 0.f } }

    };
    
    //2.创建顶点缓存区
    self.vertexBuffer = [self.mtkView.device newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared];
    //3.计算顶点个数
    self.numVertices = sizeof(quadVertices) / sizeof(YSVideoMetalVertex);
}
- (void)setupFragment
{
    //创建转化矩阵结构体.
    YSVideoMetalConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    //4.创建转换矩阵缓存区.
    self.convertMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                        length:sizeof(YSVideoMetalConvertMatrix)
                                                options:MTLResourceStorageModeShared];
}

// 0.311307 - 0.186305
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
     
    if(renderPassDescriptor && sampleBuffer)
    {
        //设置renderPassDescriptor中颜色附着(默认背景色)
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0f);
        //根据渲染描述信息创建渲染命令编码器
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        //设置视口大小(显示区域)
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
        [renderEncoder setRenderPipelineState:self.renderPipelineState];
        [self setupVertexFunctionData:renderEncoder];
        [self setupFragmentFunctionData:renderEncoder sampleBuffer:sampleBuffer];
        //绘制
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:self.numVertices];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    } else {
        if (![self.playAssets hasNextSampleBuffer]) {
//            self.mtkView.paused = YES;
            if (self.completionPlayBlock) {
                self.completionPlayBlock();
            }
        }
    }
    
    if (sampleBuffer) {
        CMSampleBufferInvalidate(sampleBuffer);
        CFRelease(sampleBuffer);
        sampleBuffer = NULL;
    }
}

- (void)setupVertexFunctionData:(id<MTLRenderCommandEncoder>)renderCommandEncoder
{
    //设置顶点数据和纹理坐标
    [renderCommandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:YSVideoMetalVertexInputIndexVertices];
}

- (void)setupFragmentFunctionData:(id<MTLRenderCommandEncoder>)renderCommandEncoder
                     sampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //设置转换矩阵
    [renderCommandEncoder setFragmentBuffer:self.convertMatrix offset:0 atIndex:YSVideoMetalFragmentBufferIndexMatrix];
     
    //Y纹理
    id<MTLTexture> textureY = [self getTextureFromSampleBuffer:sampleBuffer planeIndex:0 pixelFormat:MTLPixelFormatR8Unorm];
    id<MTLTexture> textureUV = [self getTextureFromSampleBuffer:sampleBuffer planeIndex:1 pixelFormat:MTLPixelFormatRG8Unorm];
    if (textureY && textureUV) {
        [renderCommandEncoder setFragmentTexture:textureY atIndex:YSVideoMetalFragmentTextureIndexTextureY];
        [renderCommandEncoder setFragmentTexture:textureUV atIndex:YSVideoMetalFragmentTextureIndexTextureUV];
    } else {
        NSLog(@"---YUV获取异常---");
    }
    
}


//如果图像缓冲区是平面的，则为映射纹理数据的平面索引。对于非平面图像缓冲区忽
- (id<MTLTexture>)getTextureFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
{
    //设置yuv纹理数据
    CVPixelBufferRef pixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
    id<MTLTexture> texture = [YSVideoMetalUtils getTextureFromPixelBuffer:pixelBufferRef
                                planeIndex:planeIndex
                               pixelFormat:pixelFormat
                                    device:self.device textureCache:self.textureCache];
    return texture;
}

- (NSMutableDictionary *)fragmentFunctionDict
{
    if (!_fragmentFunctionDict) {
        _fragmentFunctionDict = @{}.mutableCopy;
    }
    return _fragmentFunctionDict;
}
 
@end


