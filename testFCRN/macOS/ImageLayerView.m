//
//  ImageLayerView.m
//  testFCRN
//
//  Created by Doron Adler on 31/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ImageLayerView.h"
#import "ImagePlatform.h"

@interface ImageLayerView () {
    __strong NSImage *_image;
}

@end

@implementation ImageLayerView

@dynamic image;
@dynamic contentsGravity;

- (id)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.layer = [[CALayer alloc] init];
    self.wantsLayer = NO;
  }
  return self;
}

- (void)setImage:(NSImage *)image {
    if (_image != image) {
        _image = image;
        self.layer.contents = CFBridgingRelease([_image asCGImageRef]);
        self.wantsLayer = (image != nil)?(YES):(NO);
        [self.layer setNeedsDisplay];
    }
}

- (NSImage *)image {
    return _image;
}
- (void)setContentsGravity:(CALayerContentsGravity)contentsGravity {
    self.layer.contentsGravity = contentsGravity;
    [self.layer setNeedsDisplay];
}

- (CALayerContentsGravity)contentsGravity {
    return [self.layer contentsGravity];
}

CGContextRef createBitmapContext (int pixelsWide,
                                  int pixelsHigh)
{
    CGContextRef    context = NULL;
    CGColorSpaceRef colorSpace;
    void *          bitmapData;
    int             bitmapByteCount;
    int             bitmapBytesPerRow;
 
    bitmapBytesPerRow   = (pixelsWide * 4);
    bitmapByteCount     = (bitmapBytesPerRow * pixelsHigh);
 
    colorSpace = CGColorSpaceCreateWithName(kCGColorSpaceGenericRGB);
    bitmapData = calloc( bitmapByteCount, sizeof(uint8_t) );
    if (bitmapData == NULL)
    {
        fprintf (stderr, "Memory not allocated!");
        return NULL;
    }
    context = CGBitmapContextCreate (bitmapData,// 4
                                    pixelsWide,
                                    pixelsHigh,
                                    8,      // bits per component
                                    bitmapBytesPerRow,
                                    colorSpace,
                                    kCGImageAlphaPremultipliedLast);
    if (context== NULL)
    {
        free (bitmapData);// 5
        fprintf (stderr, "Context not created!");
        return NULL;
    }
    CGColorSpaceRelease( colorSpace );// 6
 
    return context;// 7
}

- (NSImage *)imageFromLayer {
    NSImage *imageFromPresentationLayer = nil;
    
    CALayer *presentationLayer = [self.layer presentationLayer];
    if (presentationLayer){
        int pixelsWide = (int)presentationLayer.bounds.size.width;
        int pixelsHigh = (int)presentationLayer.bounds.size.height;
        CGContextRef bitmapContext = createBitmapContext(pixelsWide, pixelsHigh);
        if (bitmapContext) {
            [presentationLayer setNeedsDisplay];
            [presentationLayer renderInContext:bitmapContext];
            CGImageRef imageRef = CGBitmapContextCreateImage(bitmapContext);
            if (imageRef) {
                imageFromPresentationLayer = [[NSImage alloc] initWithCGImage:imageRef
                                                                         size:NSMakeSize((CGFloat)pixelsWide,
                                                                                         (CGFloat)pixelsHigh)];
            }
            CGContextRelease(bitmapContext);
        }
    }
    
    return imageFromPresentationLayer;
}

@end
