//
//  YYEVAEffectInfo.m
//  YYEVA
//
//  Created by guoyabin on 2022/4/7.
//

#import "YYEVAEffectInfo.h"
#import "YSVideoMetalUtils.h"

static NSString *kYYEVAJsonDescriptKey = @"descript";
static NSString *kYYEVAJsonEffectKey = @"effect";
static NSString *kYYEVAJsonFrameDatasKey = @"datas";

#define YYEVACheckValideDict(dict) \
    if(!dict||![dict isKindOfClass:NSDictionary.class]) { \
    return nil;\
}

CGRect getFrame(NSArray *arry)
{
    if (arry.count == 4) {
        return CGRectMake([arry[0] floatValue], [arry[1] floatValue], [arry[2] floatValue], [arry[3] floatValue]);
    }
    return CGRectZero;
}


@implementation YYEVAEffectFrame

+ (instancetype)effectFrameWithDictionary:(NSDictionary *)dict
{
    YYEVACheckValideDict(dict);
    YYEVAEffectFrame *frame = [[YYEVAEffectFrame alloc] initWithDictionary:dict];
    return frame;
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    if (self = [super init]) {
        _renderFrame = getFrame([dict objectForKey:@"renderFrame"]);
        _outputFrame = getFrame([dict objectForKey:@"outputFrame"]);
        _effect_id = [[dict objectForKey:@"effectId"] integerValue];
    }
    return self;
}

- (id<MTLBuffer>)vertexBufferWithContainerSize:(CGSize)size
                             maskContianerSize:(CGSize)mSize
                                        device:(id<MTLDevice>)device
                                      fillMode:(YYEVAFillMode)fillMode
                                      trueSize:(CGSize)trueSize
                                    renderSize:(CGSize *)renderSize
{
    if (size.width <= 0 || size.height <= 0 || mSize.width <= 0 || mSize.height <= 0) {
        NSLog(@"--%@ - fail",NSStringFromSelector(_cmd));
        return nil;
    }
    
    //YSVideoMetalElementVertex
//    vector_float4 positon;  4  -> 画在哪里？
//    vector_float2 sourceTextureCoordinate; 2 -> sourceCoordinates 整个纹理坐标 0->1
//    vector_float2 maskTextureCoordinate; 2  ->  mask的坐标
     //4 + 2 + 2 = 8  * 4 = 32
    const int colunmCountForVertices = 4, colunmCountForCoordinate = 2, vertexDataLength = 32;
    float vertices[16], maskCoordinates[8];
    normalVerticesWithFillMod(self.renderFrame, size, self.src.sourceImage.size,self.src.fillMode,vertices,fillMode,trueSize, renderSize);
    mask_textureCoordinateFromRect(self.outputFrame, mSize, maskCoordinates);
    float sourceCoordinates[8] = {
        0.0, 1.0,
        0.0, 0.0,
        1.0, 1.0,
        1.0, 0.0
    };
     
    static float vertexData[vertexDataLength];
    int indexForVertexData = 0;
    //顶点数据+纹理坐标+遮罩纹理坐标
    for (int i = 0; i < 16; i ++) {
        vertexData[indexForVertexData++] = ((float*)vertices)[i];
        if (i%colunmCountForVertices == colunmCountForVertices-1) {
            int row = i/colunmCountForVertices;
            vertexData[indexForVertexData++] = ((float*)sourceCoordinates)[row*colunmCountForCoordinate];
            vertexData[indexForVertexData++] = ((float*)sourceCoordinates)[row*colunmCountForCoordinate+1];
            vertexData[indexForVertexData++] = ((float*)maskCoordinates)[row*colunmCountForCoordinate];
            vertexData[indexForVertexData++] = ((float*)maskCoordinates)[row*colunmCountForCoordinate+1];
        }
    }
    NSUInteger allocationSize = vertexDataLength * sizeof(float);
    id<MTLBuffer> vertexBuffer = [device newBufferWithBytes:vertexData length:allocationSize options:MTLResourceStorageModeShared];
    return vertexBuffer;
}
 
 
@end

@implementation YYEVAEffectSource

+ (instancetype)effectSourceWithDictionary:(NSDictionary *)dict
{
    YYEVACheckValideDict(dict);
    YYEVAEffectSource *src = [[YYEVAEffectSource alloc] initWithDictionary:dict];
    return src;
}


- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    if (self = [super init]) {
        
        _width = [[dict objectForKey:@"effectWidth"] floatValue];
        _height = [[dict objectForKey:@"effectHeight"] floatValue];
        _effect_id = [[dict objectForKey:@"effectId"] intValue];
        _effect_tag = [dict objectForKey:@"effectTag"];
        NSString *effectTypeStr = [dict objectForKey:@"effectType"];
        if ([effectTypeStr isEqualToString:@"txt"]) {
            _type = YYEVAEffectSourceTypeText;
            NSString *fontColor = [dict objectForKey:@"fontColor"];
            NSInteger fontSize = [[dict objectForKey:@"fontSize"] integerValue];
            if (fontColor.length > 0) {
                _fontColor = [fontColor copy];
            }
            _fontSize = fontSize;
            
            NSString *align = [dict objectForKey:@"textAlign"];
            _alignment = NSTextAlignmentCenter;
            if ([align isEqualToString:@"center"]) {
                _alignment = NSTextAlignmentCenter;
            } else if ([align isEqualToString:@"left"]) {
                _alignment = NSTextAlignmentLeft;
            } else if ([align isEqualToString:@"right"]) {
                _alignment = NSTextAlignmentRight;
            }
            
        } else if ([effectTypeStr isEqualToString:@"img"]) {
            _type = YYEVAEffectSourceTypeImage;
            NSString *scaleModeStr = [dict objectForKey:@"scaleMode"] ;
            if ([scaleModeStr isEqualToString:@"aspectFit"]) {
                _fillMode = YYEVAEffectSourceImageFillModeAspectFit;
            } else if ([scaleModeStr isEqualToString:@"aspectFill"]) {
                _fillMode = YYEVAEffectSourceImageFillModeAspectFill;
            } else {
                _fillMode = YYEVAEffectSourceImageFillModeScaleFill;
            }
        } else {
            _type = YYEVAEffectSourceTypeUnkown;
        }
        
    }
    return self;
}

@end



@implementation YYEVAEffectInfo

+ (instancetype)effectInfoWithDictionary:(NSDictionary *)dict
{
    YYEVACheckValideDict(dict);
    
    YYEVAEffectInfo *effectInfo = [[YYEVAEffectInfo alloc] initWithDictionary:dict];
    
    return effectInfo;
    
}

- (instancetype)initWithDictionary:(NSDictionary *)dict
{
    if (self = [super init]) {
        
        NSDictionary *descript = [dict objectForKey:kYYEVAJsonDescriptKey];
        NSArray *effects = [dict objectForKey:kYYEVAJsonEffectKey];
        NSArray *frameDatas = [dict objectForKey:kYYEVAJsonFrameDatasKey];
        
        [self setupWithDescript:descript];
        [self setupWithEffects:effects];
        [self setupWithFrameDatas:frameDatas];
        
    }
    return self;
}

- (void)setupWithDescript:(NSDictionary *)descript
{
    _videoWidth = [[descript objectForKey:@"width"] floatValue];
    _videoHeight = [[descript objectForKey:@"height"] floatValue];
    _isEffect = [[descript objectForKey:@"isEffect"] intValue];
    _plugin_version = [descript objectForKey:@"version"];
    _rgbFrame = getFrame([descript objectForKey:@"rgbFrame"]);
    _alphaFrame = getFrame([descript objectForKey:@"alphaFrame"]);
}

- (void)setupWithEffects:(NSArray *)effects
{
    if (effects.count > 0) {
        NSMutableArray *srcs = [NSMutableArray array];
        [effects enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            YYEVAEffectSource *source = [YYEVAEffectSource effectSourceWithDictionary:obj];
            [srcs addObject:source];
        }];
        _srcs = [srcs copy];
    }
}

- (void)setupWithFrameDatas:(NSArray *)frameDatas
{
    if (frameDatas.count > 0) {
        
         NSMutableDictionary<NSNumber * ,NSArray <YYEVAEffectFrame *>*> *frames = [NSMutableDictionary dictionary];
         
        [frameDatas enumerateObjectsUsingBlock:^(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            NSInteger frameIndex = [[obj objectForKey:@"frameIndex"] integerValue];
            NSArray *framesArry = [obj objectForKey:@"data"];
            NSMutableArray<YYEVAEffectFrame *> *curFrames = [NSMutableArray array];
            [framesArry enumerateObjectsUsingBlock:^(NSDictionary *frameObj, NSUInteger frameDict, BOOL * _Nonnull stop) {
                if (frameObj) {
                    YYEVAEffectFrame *frame = [YYEVAEffectFrame effectFrameWithDictionary:frameObj];
                    [curFrames addObject:frame];
                }
            }];
            [frames setObject:curFrames forKey:@(frameIndex)];
            
        }];
        _frames = [frames copy];
    }
}

@end


