//
//  ImagePlatform.m
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ImagePlatform.h"

@import CoreImage;

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

@interface ImagePlatform () {
    CGColorSpaceRef _colorSpaceRGB;
}

@property (nonatomic, strong) CIContext     *imagePlatformCoreContext;

@end

@implementation ImagePlatform

#pragma mark - init / dealloc

- (instancetype)init
{
    self = [super init];
    if (self) {
          [self setupCoreContext];
    }
    return self;
}

- (void)dealloc
{
    [self teardownCoreContext];
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

- (IMAGE_TYPE*)imageFromCVPixelBufferRef:(CVPixelBufferRef)cvPixelBufferRef
                       imageOrientation:(UIImageOrientation)imageOrientation
{
    IMAGE_TYPE* imageFromCVPixelBufferRef = nil;
    
#ifdef MACOS_TARGET
    CIImage *ciImageBeforeOrientation = nil;
    ciImageBeforeOrientation = [CIImage imageWithCVImageBuffer:cvPixelBufferRef];
    CGImagePropertyOrientation orientation = [self CGImagePropertyOrientationForUIImageOrientation:imageOrientation];
    CIImage *ciImage = [ciImageBeforeOrientation imageByApplyingOrientation:orientation];
#else
    CIImage *ciImage =  [CIImage imageWithCVImageBuffer:cvPixelBufferRef];
#endif
    
    CGImageRef imageRef = [self.imagePlatformCoreContext
                           createCGImage:ciImage
                           fromRect:CGRectMake(0, 0,
                                               CVPixelBufferGetWidth(cvPixelBufferRef),
                                               CVPixelBufferGetHeight(cvPixelBufferRef))];
    
    if (imageRef) {
#ifdef MACOS_TARGET
        size_t imageWidth  = CGImageGetWidth(imageRef);
        size_t imageHeight = CGImageGetHeight(imageRef);
        NSSize imageSize = NSMakeSize((CGFloat)imageWidth, (CGFloat)imageHeight);
        
        
        imageFromCVPixelBufferRef = [[IMAGE_TYPE alloc] initWithCGImage:imageRef size:imageSize] ;
        
#else
        uiImageFromCVPixelBufferRef = [IMAGE_TYPE imageWithCGImage:imageRef scale:1.0 orientation:imageOrientation];
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

@end