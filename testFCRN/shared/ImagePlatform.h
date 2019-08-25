//
//  ImagePlatform.h
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "TargetPlatform.h"

#if !defined(IMAGE_TYPE)
    #if (defined(WATCHOS_TARGET))
        #import <UIKit/UIKit.h>
        #define IMAGE_TYPE UIImage
    #elif (defined(MACOS_TARGET))
        #import <AppKit/AppKit.h>
        #define IMAGE_TYPE NSImage
    #else
        #import <UIKit/UIKit.h>
        #define IMAGE_TYPE UIImage
    #endif
#endif

#define MAKE_RGBA_uint32_t(R, G, B, A) ((((uint32_t)(R & 0xFF)) << 24) | (((uint32_t)(G & 0xFF)) << 16) | (((uint32_t)(B & 0xFF)) << 8 ) | ((uint32_t)(A & 0xFF) << 0 ))

#ifdef MACOS_TARGET
typedef NS_ENUM(NSInteger, UIImageOrientation) {
    UIImageOrientationUp,            // default orientation
    UIImageOrientationDown,          // 180 deg rotation
    UIImageOrientationLeft,          // 90 deg CCW
    UIImageOrientationRight,         // 90 deg CW
    UIImageOrientationUpMirrored,    // as above but image mirrored along other axis. horizontal flip
    UIImageOrientationDownMirrored,  // horizontal flip
    UIImageOrientationLeftMirrored,  // vertical flip
    UIImageOrientationRightMirrored, // vertical flip
};
#endif

NS_ASSUME_NONNULL_BEGIN

@interface IMAGE_TYPE (ImagePlatform)

- (NSData*)imageJPEGRepresentationWithCompressionFactor:(CGFloat)compressionFactor;
- (CGImageRef)asCGImageRef;

@end

@interface ImagePlatform : NSObject

@property (nonatomic, readonly) CIContext       *imagePlatformCoreContext;
@property (nonatomic, readonly) CGColorSpaceRef colorSpaceRGB;

- (IMAGE_TYPE * __nullable)imageFromCVPixelBufferRef:(CVPixelBufferRef)cvPixelBufferRef
                        imageOrientation:(UIImageOrientation)imageOrientation;

- (BOOL)setupPixelBuffer:(CVPixelBufferRef _Nonnull *_Nullable)pPixelBufferRef
         pixelFormatType:(OSType)pixelFormatType
                withRect:(CGRect)rect;
- (void)teardownPixelBuffer:(CVPixelBufferRef _Nonnull *_Nonnull)pPixelBufferRef;

- (BOOL)prepareImagePlatformContextFromResultData:(uint8_t *)pData
                                 pixelSizeInBytes:(uint8_t)pixelSizeInBytes
                                            sizeX:(int)sizeX
                                            sizeY:(int)sizeY;
- (IMAGE_TYPE* __nullable)createDisperityDepthImage;
//- (IMAGE_TYPE* __nullable)createBGRADepthImage;
- (NSData*)addDepthMapToExistingImage:(IMAGE_TYPE*)existingImage;

- (CGRect)cropRectFromImageSize:(CGSize)imageSize
         withSizeForAspectRatio:(CGSize)sizeForaspectRatio;

- (IMAGE_TYPE* __nullable)cropImage:(IMAGE_TYPE*)image withCropRect:(CGRect)cropRect;

- (IMAGE_TYPE* __nullable)depthHistogram;

@end

NS_ASSUME_NONNULL_END
