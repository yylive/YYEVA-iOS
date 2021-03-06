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

extern matrix_float3x3 kColorConversion601FullRangeMatrix;
extern vector_float3 kColorConversion601FullRangeOffset;

@interface YYEVAVideoEffectRender()
@property (nonatomic, weak) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLRenderPipelineState> defaultRenderPipelineState;
@property (nonatomic, strong) id<MTLRenderPipelineState> mergeRenderPipelineState;
@property (nonatomic, strong) id<MTLBuffer> vertexBuffer;
@property (nonatomic, strong) id<MTLBuffer> convertMatrix;
@property (nonatomic, strong) id<MTLBuffer> elementVertexBuffer;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, assign) vector_uint2 viewportSize;
@property (nonatomic, assign) NSInteger numVertices;
@end

@implementation YYEVAVideoEffectRender
@synthesize completionPlayBlock;
@synthesize playAssets;

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


- (void)playWithAssets:(YYEVAAssets *)assets
{
    self.playAssets = assets;
    [self setupVertex];
    CVMetalTextureCacheCreate(NULL, NULL, self.mtkView.device, NULL, &_textureCache);
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
    return filePath;
}

 
// ????????????
- (void)setupVertex
{
    //?????????assets?????????????????????????????????????????????
    YYEVAEffectInfo *effectInfo = self.playAssets.effectInfo;
     
    float static kVAPMTLVerticesIdentity[16] = {
                    -1.0f, -1.0f, 0.0f,1.0f, //??????1
                    -1.0f,  1.0f, 0.0f,1.0f,  //??????2
                     1.0f, -1.0f, 0.0f,1.0f,  //??????3
                     1.0f,  1.0f, 0.0f,1.0f    //??????4
    };
     
    const int colunmCountForVertices = 4;
    const int colunmCountForCoordinate = 2;
    const int vertexDataLength = 32;
    static float vertexData[vertexDataLength];
    float rgbCoordinates[8],alphaCoordinates[8];
    //??????????????????  3?????????
    const void *vertices = kVAPMTLVerticesIdentity;
    
    //??????rgb???????????????  2????????? CGRect rect,CGSize containerSize,float coordinate[8]
    CGSize videoSize = CGSizeMake(effectInfo.videoWidth, effectInfo.videoHeight);
    textureCoordinateFromRect(effectInfo.rgbFrame,videoSize,rgbCoordinates);
    textureCoordinateFromRect(effectInfo.alphaFrame,videoSize,alphaCoordinates);
      
    int indexForVertexData = 0;
    //????????????+?????????==> ?????????????????????????????????
    for (int i = 0; i < 4 * colunmCountForVertices; i ++) {
         
        //????????????
        vertexData[indexForVertexData++] = ((float*)vertices)[i];
        //????????????
        if (i%colunmCountForVertices == colunmCountForVertices-1) {
            int row = i/colunmCountForVertices;
            //rgb????????????
            vertexData[indexForVertexData++] = ((float*)rgbCoordinates)[row*colunmCountForCoordinate];
            vertexData[indexForVertexData++] = ((float*)rgbCoordinates)[row*colunmCountForCoordinate+1];
            //alpha????????????
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
    //??????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????????
    //????????????
    //3.???????????????????????????.
    YSVideoMetalConvertMatrix matrix;
    matrix.matrix = kColorConversion601FullRangeMatrix;
    matrix.offset = kColorConversion601FullRangeOffset;
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
     
        //??????megerInfo
    YYEVAEffectInfo *effectInfo = self.playAssets.effectInfo;
    NSDictionary *dictionary = effectInfo.frames;
    NSArray <YYEVAEffectFrame *> *mergeInfoList = [dictionary objectForKey:@(self.playAssets.frameIndex)];

    if(renderPassDescriptor && sampleBuffer)
    {
        //??????renderPassDescriptor???????????????(???????????????)
        renderPassDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1.0, 0.0, 0.0, 1.0f);
        //???????????????????????????????????????????????????
        id<MTLRenderCommandEncoder> renderEncoder = [commandBuffer renderCommandEncoderWithDescriptor:renderPassDescriptor];
        //??????????????????(????????????)
        [renderEncoder setViewport:(MTLViewport){0.0, 0.0, self.viewportSize.x, self.viewportSize.y, -1.0, 1.0 }];
//        //Y??????
        id<MTLTexture> textureY = [self getTextureFromSampleBuffer:sampleBuffer
                                                        planeIndex:0
                                                       pixelFormat:MTLPixelFormatR8Unorm];
        id<MTLTexture> textureUV = [self getTextureFromSampleBuffer:sampleBuffer
                                                         planeIndex:1 pixelFormat:MTLPixelFormatRG8Unorm];
//
        [self drawBackgroundWithRenderCommandEncoder:renderEncoder
                                            textureY:textureY
                                           textureUV:textureUV];
        if (mergeInfoList) {
            [self drawMergedAttachments:mergeInfoList
                               yTexture:textureY
                              uvTexture:textureUV
                          renderEncoder:renderEncoder];
        }

        [renderEncoder endEncoding];
        //??????
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
            id<MTLTexture> sourceTexture = [self loadTextureWithImage:mergeInfo.src.sourceImage device:_device]; //????????????
            //??????YSVideoMetalElementVertex??????
            //    vector_float4 positon;  4
            //    vector_float2 sourceTextureCoordinate; 2
            //    vector_float2 maskTextureCoordinate; 2
            // ???
            id<MTLBuffer> vertexBuffer = [mergeInfo vertexBufferWithContainerSize:size maskContianerSize:videoSize device:self.device];
            id<MTLBuffer> colorParamsBuffer = mergeInfo.src.colorParamsBuffer;
            id<MTLBuffer> convertMatrix = self.convertMatrix;
            if (!sourceTexture || !vertexBuffer || !convertMatrix) {
                return ;
            }
            [encoder setVertexBuffer:vertexBuffer offset:0 atIndex:0];
            [encoder setFragmentBuffer:convertMatrix offset:0 atIndex:0];
            [encoder setFragmentBuffer:colorParamsBuffer offset:0 atIndex:1];
            //???????????????????????????
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

- (void)drawBackgroundWithRenderCommandEncoder:(id<MTLRenderCommandEncoder>)renderCommandEncoder
                                      textureY:(id<MTLTexture>)textureY
                                     textureUV:(id<MTLTexture>)textureUV
{
    [renderCommandEncoder setRenderPipelineState:self.defaultRenderPipelineState];
    [self setupVertexFunctionData:renderCommandEncoder];
    
    //??????????????????
    [renderCommandEncoder setFragmentBuffer:self.convertMatrix offset:0 atIndex:YSVideoMetalFragmentBufferIndexMatrix];
    
    if (textureY && textureUV) {
        [renderCommandEncoder setFragmentTexture:textureY atIndex:YSVideoMetalFragmentTextureIndexTextureY];
        [renderCommandEncoder setFragmentTexture:textureUV atIndex:YSVideoMetalFragmentTextureIndexTextureUV];
    }
    
    [renderCommandEncoder drawPrimitives:MTLPrimitiveTypeTriangleStrip
                      vertexStart:0
                      vertexCount:self.numVertices];
}

- (void)setupVertexFunctionData:(id<MTLRenderCommandEncoder>)renderCommandEncoder
{
    //?????????????????????????????????
    [renderCommandEncoder setVertexBuffer:self.vertexBuffer offset:0 atIndex:YSVideoMetalVertexInputIndexVertices];
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
        CFRelease(textureRef);
        textureRef = NULL;
    }
    CVMetalTextureCacheFlush(_textureCache, 0);
    pixelBufferRef = NULL;
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
        _defaultRenderPipelineState = [_device newRenderPipelineStateWithDescriptor:renderPipelineDescriptor error:nil];
    }
    return _defaultRenderPipelineState;
}


@end
