//
//  ImagePlatform.m
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ImagePlatform.h"

#define kDepthFormat kCVPixelFormatType_DisparityFloat32
//#define kDepthFormat kCVPixelFormatType_DepthFloat32

@import CoreImage;
@import Accelerate;
@import AVFoundation;

@implementation IMAGE_TYPE (ImagePlatform)

- (NSData*)imageJPEGRepresentationWithCompressionFactor:(CGFloat)compressionFactor {
#ifdef MACOS_TARGET
    NSData *imageData = [self TIFFRepresentation];
    NSBitmapImageRep *imageRep = [NSBitmapImageRep imageRepWithData:imageData];
    NSDictionary *imageProps = [NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:compressionFactor] forKey:NSImageCompressionFactor];
    imageData = [imageRep representationUsingType:NSBitmapImageFileTypeJPEG properties:imageProps];
    return imageData;
#else
    NSData *imageJPEGRepresentation = UIImageJPEGRepresentation(self, compressionFactor);
    return imageJPEGRepresentation;
#endif
}

- (CGImageRef)asCGImageRef {
#ifdef MACOS_TARGET
    CGRect proposedRect = CGRectMake(0.0f, 0.0f, self.size.width, self.size.height);
    CGImageRef imgRef = [self CGImageForProposedRect:&proposedRect context:nil hints:nil];
#else
    CGImageRef imgRef = self.CGImage;
#endif
    
    return imgRef;
}

@end

typedef struct _sImagePlatformContext {
    uint8_t *pData;
    uint8_t pixelSizeInBytes;
    int sizeX;
    int sizeY;
    
    float   *spBuff;
    size_t  spBuffSize;
    float   maxV;
    float   minV;
    
    
}sImagePlatformContext, *sImagePlatformContextPtr;

@interface ImagePlatform () {
    CGColorSpaceRef _colorSpaceRGB;
    sImagePlatformContext _context;
}

@property (nonatomic, strong) CIContext     *imagePlatformCoreContext;
@property (nonatomic, strong) CIImage *scaledDepthImage;

@end

@implementation ImagePlatform

#pragma mark - init / dealloc

- (instancetype)init
{
    self = [super init];
    if (self) {
        _context.pData = NULL;
        _context.pixelSizeInBytes = 0;
        _context.sizeX = 0;
        _context.sizeY = 0;
        _context.spBuff = NULL;
        _context.spBuffSize = 0;
        _context.maxV = 0.0f;
        _context.minV = 0.0f;
        [self setupCoreContext];
    }
    return self;
}

- (void)dealloc
{
    [self teardownInternalContext];
    [self teardownCoreContext];
}

- (void)teardownInternalContext {
    if (_context.pData) {
        free(_context.pData);
        _context.pData = NULL;
    }
    
    _context.pixelSizeInBytes = 0;
    _context.sizeX = 0;
    _context.sizeY = 0;
    
    if (_context.spBuff) {
        free(_context.spBuff);
        _context.spBuff = NULL;
    }
    
    _context.spBuffSize = 0;
    
    _context.maxV = 0.0f;
    _context.minV = 0.0f;
}

- (void)setupCoreContext {
    
    if (self.imagePlatformCoreContext ==  nil) {
        NSDictionary *options = @{kCIContextWorkingColorSpace   : [NSNull null],
                                  kCIContextUseSoftwareRenderer : @(NO)};
        self.imagePlatformCoreContext = [CIContext contextWithOptions:options];
    }
    
    if (_colorSpaceRGB == NULL) {
        _colorSpaceRGB = CGColorSpaceCreateDeviceRGB();
    }
}

- (void)teardownCoreContext {
    self.imagePlatformCoreContext = nil;
    
    if (_colorSpaceRGB) {
        CGColorSpaceRelease(_colorSpaceRGB);
        _colorSpaceRGB = NULL;
    }
}

- (CGColorSpaceRef) colorSpaceRGB {
    return _colorSpaceRGB;
}

#pragma mark - Pixel buffer reference to image

- (CIImage *)ciImageFromPixelBuffer:(CVPixelBufferRef _Nonnull)cvPixelBufferRef
                   imageOrientation:(UIImageOrientation)imageOrientation {
#ifdef MACOS_TARGET
    CIImage *ciImageBeforeOrientation = nil;
    ciImageBeforeOrientation = [CIImage imageWithCVImageBuffer:cvPixelBufferRef];
    CGImagePropertyOrientation orientation = [self CGImagePropertyOrientationForUIImageOrientation:imageOrientation];
    CIImage *ciImage = [ciImageBeforeOrientation imageByApplyingOrientation:orientation];
    return ciImage;
#else
    return ([CIImage imageWithCVImageBuffer:cvPixelBufferRef]);
#endif
}

- (IMAGE_TYPE*)imageFromCVPixelBufferRef:(CVPixelBufferRef)cvPixelBufferRef
                        imageOrientation:(UIImageOrientation)imageOrientation
{
    IMAGE_TYPE* imageFromCVPixelBufferRef = nil;
    
    CIImage * ciImage = [self ciImageFromPixelBuffer:cvPixelBufferRef imageOrientation:imageOrientation];
    CGRect imageRect = CGRectMake(0, 0,
                                  CVPixelBufferGetWidth(cvPixelBufferRef),
                                  CVPixelBufferGetHeight(cvPixelBufferRef));
    
    CGImageRef imageRef = [self.imagePlatformCoreContext
                           createCGImage:ciImage
                           fromRect:imageRect];
    
    if (imageRef) {
#ifdef MACOS_TARGET
        size_t imageWidth  = CGImageGetWidth(imageRef);
        size_t imageHeight = CGImageGetHeight(imageRef);
        NSSize imageSize = NSMakeSize((CGFloat)imageWidth, (CGFloat)imageHeight);
        
        
        imageFromCVPixelBufferRef = [[IMAGE_TYPE alloc] initWithCGImage:imageRef size:imageSize] ;
#else
        imageFromCVPixelBufferRef = [IMAGE_TYPE imageWithCGImage:imageRef scale:1.0 orientation:imageOrientation];
#endif
        
        CGImageRelease(imageRef);
    }
    
    return imageFromCVPixelBufferRef;
    
}

#pragma mark - Utility - CGImagePropertyOrientation <-> UIImageOrientation convertion

- (CGImagePropertyOrientation) CGImagePropertyOrientationForUIImageOrientation:(UIImageOrientation)uiOrientation {
    switch (uiOrientation) {
        default:
        case UIImageOrientationUp: return kCGImagePropertyOrientationUp;
        case UIImageOrientationDown: return kCGImagePropertyOrientationDown;
        case UIImageOrientationLeft: return kCGImagePropertyOrientationLeft;
        case UIImageOrientationRight: return kCGImagePropertyOrientationRight;
        case UIImageOrientationUpMirrored: return kCGImagePropertyOrientationUpMirrored;
        case UIImageOrientationDownMirrored: return kCGImagePropertyOrientationDownMirrored;
        case UIImageOrientationLeftMirrored: return kCGImagePropertyOrientationLeftMirrored;
        case UIImageOrientationRightMirrored: return kCGImagePropertyOrientationRightMirrored;
    }
}

-(UIImageOrientation) UIImageOrientationForCGImagePropertyOrientation:(CGImagePropertyOrientation)cgOrientation {
    switch (cgOrientation) {
        default:
        case kCGImagePropertyOrientationUp: return UIImageOrientationUp;
        case kCGImagePropertyOrientationDown: return UIImageOrientationDown;
        case kCGImagePropertyOrientationLeft: return UIImageOrientationLeft;
        case kCGImagePropertyOrientationRight: return UIImageOrientationRight;
        case kCGImagePropertyOrientationUpMirrored: return UIImageOrientationUpMirrored;
        case kCGImagePropertyOrientationDownMirrored: return UIImageOrientationDownMirrored;
        case kCGImagePropertyOrientationLeftMirrored: return UIImageOrientationLeftMirrored;
        case kCGImagePropertyOrientationRightMirrored: return UIImageOrientationRightMirrored;
    }
}


#pragma mark - Utility - Pixel buffer

- (void)teardownPixelBuffer:(CVPixelBufferRef*)pPixelBufferRef {
    if (*pPixelBufferRef != NULL) {
        //        GTLog(@"teardownPixelBuffer: \"%@\"", (*pPixelBufferRef));
        CVPixelBufferRelease(*pPixelBufferRef);
        *pPixelBufferRef = NULL;
    }
}

- (BOOL)setupPixelBuffer:(CVPixelBufferRef*)pPixelBufferRef
         pixelFormatType:(OSType)pixelFormatType
                withRect:(CGRect)rect {
    
    if ((rect.size.width <= 0) || (rect.size.height <= 0)) {
        return NO;
    }
    
    if (*pPixelBufferRef != NULL) {
        [self teardownPixelBuffer:pPixelBufferRef];
    }
    
#ifdef MACOS_TARGET
    NSDictionary *pixelBufferAttributes = @{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                             (NSString*)kCVPixelBufferOpenGLCompatibilityKey: @YES};
    
#else
    NSDictionary *pixelBufferAttributes = @{ (NSString*)kCVPixelBufferIOSurfacePropertiesKey : @{},
                                             (NSString*)kCVPixelBufferOpenGLESCompatibilityKey: @YES};
    
#endif
    
    CVReturn cvRet =  CVPixelBufferCreate(kCFAllocatorDefault,
                                          rect.size.width,
                                          rect.size.height,
                                          pixelFormatType,
                                          (__bridge CFDictionaryRef)pixelBufferAttributes,
                                          pPixelBufferRef);
    
    if (cvRet != kCVReturnSuccess)
    {
        NSLog(@"CVPixelBufferCreate failed to create a pixel buffer (\"%d\")", cvRet);
        return NO;
    }
    
    NSLog(@"Done: setupPixelBuffer: \"%@\" withRect: \"{%f, %f, %f, %f}\"", (*pPixelBufferRef), rect.origin.x, rect.origin.y, rect.size.width, rect.size.height);
    
    return YES;
}

#pragma mark - Utility Filters

- (IMAGE_TYPE*)depthHistogram {
    NSAssert((_context.pixelSizeInBytes == 8), @"Expected double sized elements");
    
    CVPixelBufferRef grayImageBuffer = NULL;
    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)(_context.sizeX), (CGFloat)(_context.sizeY));
    BOOL didSetup = [self setupPixelBuffer:&grayImageBuffer
                           pixelFormatType:kDepthFormat
                                  withRect:pixelBufferRect];
    
    if (grayImageBuffer == NULL || didSetup == NO) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
    float *spBuff = (float *)CVPixelBufferGetBaseAddress(grayImageBuffer);
    memcpy(spBuff, _context.spBuff, _context.spBuffSize);
    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
    
    CIImage *ciImage = [self ciImageFromPixelBuffer:grayImageBuffer imageOrientation:UIImageOrientationUp];
    
    CIFilter *areaHistogramFilter = [CIFilter filterWithName:@"CIAreaHistogram"];
    [areaHistogramFilter setValue:ciImage forKey:kCIInputImageKey];
    
#define kInputHeight 100
#define kInputScale  50
    CGRect imageExtent = [ciImage extent];
    CIVector *extentVector = [CIVector vectorWithCGRect:imageExtent];
    [areaHistogramFilter setValue:extentVector forKey:kCIInputExtentKey];
    [areaHistogramFilter setValue:@(255) forKey: @"inputCount"];
    [areaHistogramFilter setValue:@(kInputScale) forKey: kCIInputScaleKey];
    
    CIImage *areaHistogramImage = [areaHistogramFilter outputImage];
    
    CIFilter *histogramDisplayFilter = [CIFilter filterWithName:@"CIHistogramDisplayFilter"];
    [histogramDisplayFilter setValue:areaHistogramImage forKey:kCIInputImageKey];
    [histogramDisplayFilter setValue:@(kInputHeight)  forKey:@"inputHeight"];
    [histogramDisplayFilter setValue:@(_context.maxV) forKey:@"inputHighLimit"];
    [histogramDisplayFilter setValue:@(_context.minV) forKey:@"inputLowLimit"];
    
    
    CIImage *histogramDisplayImage = [histogramDisplayFilter outputImage];
    CGRect histogramDisplayImageRect = [histogramDisplayImage extent];
    CVPixelBufferRef histogramPixelBufferRef = NULL;
    didSetup = [self setupPixelBuffer:&histogramPixelBufferRef
                      pixelFormatType:kCVPixelFormatType_32BGRA
                             withRect:histogramDisplayImageRect];
    
    if (histogramPixelBufferRef == NULL || didSetup == NO) {
        [self teardownPixelBuffer:&grayImageBuffer];
        return NULL;
    }
    
    [self.imagePlatformCoreContext render:histogramDisplayImage toCVPixelBuffer:histogramPixelBufferRef];
    IMAGE_TYPE * histogramImage = [self imageFromCVPixelBufferRef:histogramPixelBufferRef imageOrientation:UIImageOrientationUp];
    
    [self teardownPixelBuffer:&grayImageBuffer];
    [self teardownPixelBuffer:&histogramPixelBufferRef];
    
    return histogramImage;
}

#pragma mark - Depth buffer proccesing

- (BOOL)prepareImagePlatformContextFromResultData:(uint8_t *)pData
                                 pixelSizeInBytes:(uint8_t)pixelSizeInBytes
                                            sizeX:(int)sizeX
                                            sizeY:(int)sizeY {
    
    if ((_context.sizeX != sizeX) || (_context.sizeY != sizeY) || (_context.pixelSizeInBytes != pixelSizeInBytes)) {
        [self teardownInternalContext];
    }
    
    if (_context.pData == NULL) {
        _context.pData = malloc(sizeX * sizeY * pixelSizeInBytes);
        _context.pixelSizeInBytes = pixelSizeInBytes;
        _context.sizeX = sizeX;
        _context.sizeY = sizeY;
    }
    
    memcpy(_context.pData, pData, (sizeX * sizeY * pixelSizeInBytes));
    
    if (_context.spBuff == NULL) {
        _context.spBuffSize = sizeX * sizeY * sizeof(float);
        _context.spBuff = malloc(_context.spBuffSize);
    }
    
    double maxVD = 0.;
    vDSP_maxvD((const double *)pData, 1, &maxVD, sizeY*sizeX);
    double minVD = 0.;
    vDSP_minvD((const double *)pData, 1, &minVD, sizeY*sizeX);
    const  double scalar = (1.0 / (maxVD+(minVD/2.0)));
    vDSP_vsmulD((const double *)pData, 1, &scalar, (double *)_context.pData, 1, sizeY*sizeX);
    vDSP_vdpsp((const double *)_context.pData,1, (float*)_context.spBuff, 1,  sizeY*sizeX);
    
    float maxV = 0.;
    float minV = 0.;
    vDSP_maxv((float*)_context.spBuff, 1, &maxV, _context.sizeY*_context.sizeX);
    vDSP_minv((float*)_context.spBuff, 1, &minV, _context.sizeY*_context.sizeX);
    
    _context.maxV = maxV;
    _context.minV = minV;
    
    return YES;
}

- (IMAGE_TYPE*)createDisperityDepthImage {
    
    NSAssert((_context.pixelSizeInBytes == 8), @"Expected double sized elements");
    
    CVPixelBufferRef grayImageBuffer = NULL;
    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)(_context.sizeX), (CGFloat)(_context.sizeY));
    BOOL didSetup = [self setupPixelBuffer:&grayImageBuffer
                           pixelFormatType:kDepthFormat
                                  withRect:pixelBufferRect];
    
    if (grayImageBuffer == NULL || didSetup == NO) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
    float *spBuff = (float *)CVPixelBufferGetBaseAddress(grayImageBuffer);
    memcpy(spBuff, _context.spBuff, _context.spBuffSize);
    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
    
    CIImage *unproccessedImage = [CIImage imageWithCVImageBuffer:grayImageBuffer];
    CIFilter *lanczosScaleTransform = [CIFilter filterWithName:@"CILanczosScaleTransform"];
    [lanczosScaleTransform setValue:unproccessedImage forKey:kCIInputImageKey];
    
#define kDepthMapScaleFactor (5.0f)
    [lanczosScaleTransform setValue:@(kDepthMapScaleFactor) forKey: kCIInputScaleKey];
    
    CGFloat aspectRatio = 1.0f;
    [lanczosScaleTransform setValue:@(aspectRatio) forKey: kCIInputAspectRatioKey];
    
    CIFilter *colorInvert = [CIFilter filterWithName:@"CIColorInvert"];
    [colorInvert setValue:[lanczosScaleTransform outputImage] forKey:kCIInputImageKey];
    
    CIImage *scaledDepthImage = [colorInvert outputImage];
    CGRect scaledDepthImageRect = [scaledDepthImage extent];
    CVPixelBufferRef scaledDepthPixelBufferRef = NULL;
    didSetup = [self setupPixelBuffer:&scaledDepthPixelBufferRef
                      pixelFormatType:kDepthFormat
                             withRect:scaledDepthImageRect];
    
    if (scaledDepthPixelBufferRef == NULL || didSetup == NO) {
        [self teardownPixelBuffer:&grayImageBuffer];
        return NULL;
    }
    
    [self.imagePlatformCoreContext render:scaledDepthImage toCVPixelBuffer:scaledDepthPixelBufferRef];
    
    self.scaledDepthImage = [CIImage imageWithCVImageBuffer:scaledDepthPixelBufferRef];
    
    IMAGE_TYPE * depthImage = [self imageFromCVPixelBufferRef:scaledDepthPixelBufferRef imageOrientation:UIImageOrientationUp];
    
    [self teardownPixelBuffer:&grayImageBuffer];
    [self teardownPixelBuffer:&scaledDepthPixelBufferRef];
    
    return depthImage;
    
}

- (nullable NSDictionary *)auxiliaryDictWithImageData:(nonnull NSData *)imageData
                                     infoMetadataDict:(NSDictionary *)infoMetadataDict
                                              xmpPath:(NSString*)xmpPath {
    
    NSData* xmpData = [NSData dataWithContentsOfFile:xmpPath];
    CFDataRef xmpDataRef = (__bridge CFDataRef)xmpData;
    CGImageMetadataRef imgMetaData = CGImageMetadataCreateFromXMPData(xmpDataRef);
    
    
    
    // NSError *error = nil;
    
    NSDictionary *auxDict = @{(NSString*)kCGImageAuxiliaryDataInfoData : imageData,
                              (NSString*)kCGImageAuxiliaryDataInfoMetadata : (id)CFBridgingRelease(imgMetaData),
                              (NSString*)kCGImageAuxiliaryDataInfoDataDescription : infoMetadataDict};
    
    //[AVDepthData depthDataFromDictionaryRepresentation:auxDict error:&error];
    
    return auxDict;
}

- (NSData*)addDepthMapToExistingImage:(IMAGE_TYPE*)existingImage {
    NSData *combinedImageData = NULL;
    
    NSMutableData *imageData = [NSMutableData data];
    
    CGImageDestinationRef imageDestination =  CGImageDestinationCreateWithData((__bridge CFMutableDataRef)imageData, (CFStringRef)@"public.jpeg", 1, NULL);
    
    if (imageDestination == nil) {
        return nil;
    }
    
    NSString *portraitStr = @"Portrait";
    NSString *landscapeStr = @"Landscape";
    NSString *orientationXMPFile = nil;
    
    if (existingImage.size.width > existingImage.size.height) {
        orientationXMPFile = [NSString stringWithFormat:@"Depth%@", landscapeStr];
    } else {
        orientationXMPFile = [NSString stringWithFormat:@"Depth%@", portraitStr];
    }
    
    NSString *xmpPath = [[NSBundle mainBundle] pathForResource:orientationXMPFile ofType:@"xmp"];
    
    
    size_t bytesPerRow = _context.sizeX * sizeof(float);
    size_t height = _context.sizeY;
    size_t width  = _context.sizeX;
    OSType pixelFormatType = kDepthFormat;
    
    NSDictionary *infoMetadataDict = @{@"BytesPerRow": @(bytesPerRow),
                                       @"Height" : @(height),
                                       @"PixelFormat" : @(pixelFormatType),
                                       @"Width" : @(width)};
    
  
    NSData *depthMapImageData = [NSData dataWithBytesNoCopy:_context.spBuff length:_context.spBuffSize freeWhenDone:NO];
    
    NSDictionary *auxiliaryDict = [self auxiliaryDictWithImageData:depthMapImageData
                                                  infoMetadataDict:infoMetadataDict
                                                           xmpPath:xmpPath];
    
    NSError *error = nil;
    AVDepthData *depthDataUnscaled = [AVDepthData depthDataFromDictionaryRepresentation:auxiliaryDict error:&error];
    AVDepthData *depthData = [depthDataUnscaled depthDataByReplacingDepthDataMapWithPixelBuffer:[self.scaledDepthImage pixelBuffer] error:&error];
    
    if (depthData == NULL) {
        NSLog(@"ERROR - depthDataByReplacingDepthDataMapWithPixelBuffer failed: %@", error);
        depthData = depthDataUnscaled;
    }
    
    CVPixelBufferRef depthDataMap = [depthData depthDataMap];
    
    // Use AVDepthData to get the auxiliary data dictionary.
       NSString *auxDataType = nil;
       NSDictionary *auxData = [depthData dictionaryRepresentationForAuxiliaryDataType:&auxDataType];
       
       CFDictionaryRef auxDataRef = (__bridge CFDictionaryRef)(auxData);
       NSLog(@"auxDataRef = 0x%x", (unsigned int)auxDataRef);
            
   // NSDictionary *exifDict = @{(NSString*)kCGImagePropertyExifDictionary:@{@"Orientation":@(1), @(0x0112):@(1)}};
   // CFDictionaryRef exifDictRef = (__bridge CFDictionaryRef)(exifDict);
   // CGImageDestinationAddImage(imageDestination, [existingImage asCGImageRef], ( CFDictionaryRef)exifDictRef );
    CGImageDestinationAddImage(imageDestination, [existingImage asCGImageRef], NULL);

    // Add auxiliary data to the image destination.
    CGImageDestinationAddAuxiliaryDataInfo(imageDestination, (CFStringRef)auxDataType, auxDataRef);
    
    if (CGImageDestinationFinalize(imageDestination)) {
        combinedImageData = [NSData dataWithData:imageData];
    }
    
    CFRelease(imageDestination);
    
    return combinedImageData;
}

#pragma mark - Depth buffer proccesing - Unused examples

- (CVPixelBufferRef)createPixelBufferFromGrayData:(char *)grayBuff
                                            sizeX:(int)sizeX
                                            sizeY:(int)sizeY {
    CVPixelBufferRef grayImageBuffer = NULL;
    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)sizeX, (CGFloat)sizeY);
    BOOL didSetup = [self setupPixelBuffer:&grayImageBuffer
                           pixelFormatType:kCVPixelFormatType_32BGRA
                                  withRect:pixelBufferRect];
    
    if (grayImageBuffer == NULL || didSetup == NO) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
    uint32 *pRGBA = (uint32 *)CVPixelBufferGetBaseAddress(grayImageBuffer);
    
    const vImage_Buffer grayBuffV = {grayBuff, sizeY, sizeX, sizeX};
    const vImage_Buffer rgbaBuffV = {pRGBA, sizeY, sizeX, sizeX * 4};
    
    vImageConvert_Planar8ToBGRX8888(&grayBuffV, &grayBuffV, &grayBuffV, 0xFF, &rgbaBuffV, (vImage_Flags)0);
    
    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
    return grayImageBuffer;
}

- (IMAGE_TYPE*)createBGRADepthImage {
    
    NSAssert((_context.pixelSizeInBytes == 8), @"Expected double sized elements");
    
    char *grayBuff = malloc(_context.sizeY*_context.sizeX*sizeof(char));
    const  double scalar = 255.;
    double *doubleBuff1 = malloc(_context.sizeY*_context.sizeX*sizeof(double));
    vDSP_vsmulD((const double *)_context.pData, 1, &scalar, doubleBuff1, 1, _context.sizeY*_context.sizeX);
    const double offset = -(scalar * (_context.minV / 2.));
    double *doubleBuff2 = malloc(_context.sizeY*_context.sizeX*sizeof(double));
    vDSP_vsaddD(doubleBuff1, 1, &offset, doubleBuff2, 1, _context.sizeY*_context.sizeX);
    free(doubleBuff1);
    vDSP_vfix8D(doubleBuff2, 1, grayBuff, 1,  _context.sizeY*_context.sizeX);
    free(doubleBuff2);
    
    CVPixelBufferRef grayImageBuffer = [self createPixelBufferFromGrayData:grayBuff sizeX:_context.sizeX sizeY:_context.sizeY];
    
    free(grayBuff);
    
    if (grayImageBuffer == NULL) {
        return NULL;
    }
    
    IMAGE_TYPE *depthImage32 = [self imageFromCVPixelBufferRef:grayImageBuffer imageOrientation:UIImageOrientationUp];
    
    [self teardownPixelBuffer:&grayImageBuffer];
    
    return depthImage32;
}

- (CVPixelBufferRef)createFalseColorPixelBufferFromGrayData:(char *)grayBuff
                                                      sizeX:(int)sizeX
                                                      sizeY:(int)sizeY {
    CVPixelBufferRef grayImageBuffer = NULL;
    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)sizeX, (CGFloat)sizeY);
    BOOL didSetup = [self setupPixelBuffer:&grayImageBuffer
                           pixelFormatType:kCVPixelFormatType_32BGRA
                                  withRect:pixelBufferRect];
    
    if (grayImageBuffer == NULL || didSetup == NO) {
        return NULL;
    }
    
    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
    uint32 *pRGBA = (uint32 *)CVPixelBufferGetBaseAddress(grayImageBuffer);
    
    char *colBuff1 = malloc(sizeX*sizeY);
    char *colBuff2 = malloc(sizeX*sizeY);
    char *pSource = grayBuff;
    char *pDest1 = colBuff1;
    char *pDest2 = colBuff2;
    for (int y = 0; y < sizeY; ++y) {
        for (int x= 0; x < sizeX; ++x) {
            *pDest1 = (char)((*pSource) * 2);
            *pDest2 = 0xFF - (char)((*pSource) * 2);
            pSource++;
            pDest1++;
            pDest2++;
        }
    }
    
    const vImage_Buffer grayBuffV = {grayBuff, sizeY, sizeX, sizeX};
    const vImage_Buffer colBuffV1 = {colBuff1, sizeY, sizeX, sizeX};
    const vImage_Buffer colBuffV2 = {colBuff2, sizeY, sizeX, sizeX};
    const vImage_Buffer rgbaBuffV = {pRGBA, sizeY, sizeX, sizeX * 4};
    
    vImageConvert_Planar8ToBGRX8888(&colBuffV1, &grayBuffV, &colBuffV2, 0xFF, &rgbaBuffV, (vImage_Flags)0);
    free(colBuff1);
    free(colBuff2);
    
    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
    return grayImageBuffer;
}

#pragma mark - Utility - Crop

- (CGRect)cropRectFromImageSize:(CGSize)imageSize
         withSizeForAspectRatio:(CGSize)sizeForaspectRatio {
    
    CGRect cropRect = CGRectZero;
    CGFloat inWidth = imageSize.width;
    CGFloat inHeight = imageSize.height;
    
    CGFloat aspectWidth = sizeForaspectRatio.width;
    CGFloat aspectHeight = sizeForaspectRatio.height;
    
    CGFloat rx = inWidth/aspectWidth;           //E.G. 320/312 = 1.0256410256   |   704/312 = 2.2564102564
    CGFloat ry = inHeight/aspectHeight;         //E.G. 240/312 = 0.7692307692   |   576/312 = 1.8461538462
    CGFloat dx = 0.0f;
    CGFloat dy = 0.0f;
    
    if(ry<rx) { //E.G. (320 - 240*312/312)/2 = 40   |   (704 - 576*312/312)/2 = 64
        dx = (inWidth - inHeight*aspectWidth/aspectHeight) / 2.0f;
        CGFloat newWidth  = (inWidth - (dx * 2.0f));
        dy = 0.0f;
        cropRect = CGRectMake(dx, dy, newWidth, inHeight);
    } else {
        dx = 0.0f;
        dy = (inHeight - inWidth*aspectHeight/aspectWidth) / 2.0f;
        CGFloat newHeight  = (inHeight - (dy * 2.0f));
        cropRect = CGRectMake(dx, dy, inWidth, newHeight);
    }
    
    return cropRect;
}

- (IMAGE_TYPE*)cropImage:(IMAGE_TYPE*)image withCropRect:(CGRect)cropRect {
    IMAGE_TYPE *croppedImage = NULL;
    
    CGImageRef inputImageRef = [image asCGImageRef];
    CIImage *ciInputImage = [CIImage imageWithCGImage:inputImageRef];
    CGImageRef imageRef = [self.imagePlatformCoreContext
                           createCGImage:ciInputImage
                           fromRect:cropRect];
    
    if (imageRef) {
#ifdef MACOS_TARGET
        size_t imageWidth  = CGImageGetWidth(imageRef);
        size_t imageHeight = CGImageGetHeight(imageRef);
        NSSize imageSize = NSMakeSize((CGFloat)imageWidth, (CGFloat)imageHeight);
        
        
        croppedImage = [[IMAGE_TYPE alloc] initWithCGImage:imageRef size:imageSize] ;
#else
        croppedImage = [IMAGE_TYPE imageWithCGImage:imageRef scale:1.0 orientation:imageOrientation];
#endif
        
        CGImageRelease(imageRef);
    }
    
    return croppedImage;
}

@end
