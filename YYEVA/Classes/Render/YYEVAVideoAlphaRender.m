//
//  YYEVAVideoAlphaRender.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/21.
//

#import "YYEVAVideoAlphaRender.h"
#import "YYEVAAssets.h"
#include "YYEVAVideoShareTypes.h"

extern matrix_float3x3 kColorConversion601FullRangeMatrix;
extern vector_float3 kColorConversion601FullRangeOffset;

@interface YYEVAVideoAlphaRender()
@property (nonatomic, weak) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> renderPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, strong) id<MTLBuffer> elementVertexBuffer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, assign) NSInteger numVertices;
@end

@implementation YYEVAVideoAlphaRender
@synthesize completionPlayBlock;
@synthesize playAssets;

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


- (void)playWithAssets:(YYEVAAssets *)assets
{
    self.playAssets = assets;
    CVMetalTextureCacheCreate(NULL, NULL, self.mtkView.device, NULL, &_textureCache);
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
    id<MTLLibrary> library = [_device newLibraryWithFile:filePath error:nil];
    id<MTLFunction> vertexFunction = [library newFunctionWithName:@"normalVertexShader"];
    id<MTLFunction> fragmentFunction = [library newFunctionWithName:@"normalFragmentSharder"];
    
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
    _renderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    
    
    _commandQueue = [_device newCommandQueue];
}


// ????????????
- (void)setupVertex {
    
    //1.????????????(x,y,z);????????????(x,y)
    //??????: ???????????????????????????,???????????????????????????[-1,1]
    static const YSVideoMetalVertex quadVertices[] =
    {   // ????????????????????????x???y???z???    ???????????????x???y???
        { { -1.0, -1.0, 0.0 ,1.0},  { 0.f, 1.f} },
        { { -1.0,  1.0, 0.0 ,1.0},  { 0.f, 0.0f } },
        { {  1.0, -1.0, 0.0,1.0 },  { 1.f, 1.f } },
        { {  1.0, 1.0, 0.0,1.0 },  { 1.f, 0.f } }
         
    };
    
    //2.?????????????????????
    self.vertexBuffer = [self.mtkView.device newBufferWithBytes:quadVertices
                                                     length:sizeof(quadVertices)
                                                    options:MTLResourceStorageModeShared];
    //3.??????????????????
    self.numVertices = sizeof(quadVertices) / sizeof(YSVideoMetalVertex);
}
- (void)setupFragment
{
    //???????????????????????????.
    YSVideoMetalConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
    //4.???????????????????????????.
    self.convertMatrix = [self.mtkView.device newBufferWithBytes:&matrix
                                                        length:sizeof(YSVideoMetalConvertMatrix)
                                                options:MTLResourceStorageModeShared];
     
}


#pragma mark -- MTKView Delegate
//???MTKView size ???????????????self.viewportSize
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size
{
    self.viewportSize = (vector_uint2){size.width, size.height};
}

//????????????
- (void)drawInMTKView:(MTKView *)view
{
    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *renderPassDescriptor = view.currentRenderPassDescriptor;
    CMSampleBufferRef sampleBuffer = [self.playAssets nextSampleBuffer];
     
    if(renderPassDescriptor && sampleBuffer)
    {
        NSLog(@"-----%zd----",self.playAssets.frameIndex);
        
        //??????renderPassDescriptor???????????????(???????????????)
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(0.0, 0.0, 0.0, 0.0f);
        //???????????????????????????????????????????????????
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        //??????????????????(????????????)
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
        [renderEncoder setRenderPipelineState:self.renderPipelineState];
        [self setupVertexFunctionData:renderEncoder];
        [self setupFragmentFunctionData:renderEncoder sampleBuffer:sampleBuffer];
        //??????
        [renderEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                          vertexStart:0
                          vertexCount:self.numVertices];
        [renderEncoder endEncoding];
        [commandBuffer presentDrawable:view.currentDrawable];
        [commandBuffer commit];
    } else {
        if (![self.playAssets hasNextSampleBuffer]) {
            self.mtkView.paused = YES;
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
    //?????????????????????????????????
    [renderCommandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:YSVideoMetalVertexInputIndexVertices];
}

- (void)setupFragmentFunctionData:(id<MTLRenderCommandEncoder>)renderCommandEncoder
                     sampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    //??????????????????
    [renderCommandEncoder setFragmentBuffer:self.convertMatrix offset:0 atIndex:YSVideoMetalFragmentBufferIndexMatrix];
     
    //Y??????
    id<MTLTexture> textureY = [self getTextureFromSampleBuffer:sampleBuffer planeIndex:0 pixelFormat:MTLPixelFormatR8Unorm];
    id<MTLTexture> textureUV = [self getTextureFromSampleBuffer:sampleBuffer planeIndex:1 pixelFormat:MTLPixelFormatRG8Unorm];
    if (textureY && textureUV) {
        [renderCommandEncoder setFragmentTexture:textureY atIndex:YSVideoMetalFragmentTextureIndexTextureY];
        [renderCommandEncoder setFragmentTexture:textureUV atIndex:YSVideoMetalFragmentTextureIndexTextureUV];
    } else {
        NSLog(@"---YUV????????????---");
    }
    
}


//???????????????????????????????????????????????????????????????????????????????????????????????????????????????
- (id<MTLTexture>)getTextureFromSampleBuffer:(CMSampleBufferRef)sampleBuffer
                                  planeIndex:(size_t)planeIndex
                                 pixelFormat:(MTLPixelFormat)pixelFormat
{
    //??????yuv????????????
    CVPixelBufferRef pixelBufferRef = CMSampleBufferGetImageBuffer(sampleBuffer);
//    //y??????
    id<MTLTexture> texture = nil;
    size_t width = CVPixelBufferGetWidthOfPlane(pixelBufferRef, planeIndex);
    size_t height = CVPixelBufferGetHeightOfPlane(pixelBufferRef, planeIndex);
    CVMetalTextureRef textureRef = NULL;
    CVReturn status =  CVMetalTextureCacheCreateTextureFromImage(NULL, _textureCache, pixelBufferRef, NULL, pixelFormat, width, height, planeIndex, &textureRef);
    if (status == kCVReturnSuccess) {
        texture = CVMetalTextureGetTexture(textureRef);
        CVBufferRelease(textureRef);
        textureRef = NULL;
    }
    CVMetalTextureCacheFlush(_textureCache, 0);
    pixelBufferRef = NULL;
    return texture;
}

@end
