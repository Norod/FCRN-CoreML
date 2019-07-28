//
//  ViewController.m
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ViewController.h"
#import "FCRN.h"

#import "ImagePlatform.h"

@import CoreML;
@import Vision;

//#import "ImagePlatform.h"

@interface ViewController ()

@property (nonatomic, strong) FCRN *fcrn;
@property (nonatomic, strong) VNCoreMLModel *model;
@property (nonatomic, strong) VNCoreMLRequest *request;
@property (nonatomic, strong) VNImageRequestHandler *handler;

@property (nonatomic, strong) ImagePlatform* imagePlatform;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imagePlatform = [[ImagePlatform alloc] init];
    [self test];
    
    // Do any additional setup after loading the view.
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}

- (void)test {
    NSError *error = nil;
    self.fcrn = [[FCRN alloc] init];
    self.model = [VNCoreMLModel modelForMLModel:self.fcrn.model error:&error];
    NSString *imagePath = @"/Users/dadler/Downloads/outfolder/2.jpg";
    NSImage *image = [[NSImage alloc] initWithContentsOfFile:imagePath];
    
    VNRequestCompletionHandler completionHandler =  ^(VNRequest *request, NSError * _Nullable error) {
        NSArray *results = request.results;
        NSLog(@"results = \"%@\"", results);
        for (VNObservation *observation in results) {
            if ([observation isKindOfClass:[VNCoreMLFeatureValueObservation class]]) {
                VNCoreMLFeatureValueObservation *featureValueObservation = (VNCoreMLFeatureValueObservation*)observation;
                MLFeatureValue *featureValue = featureValueObservation.featureValue;
                if (featureValue.type == MLFeatureTypeMultiArray) {
                    //NSLog(@"featureName: \"%@\" of type \"%@\" (%@)", featureValueObservation.featureName, @"MLFeatureTypeMultiArray", @(featureValue.type));
                    MLMultiArray *multiArrayValue = featureValue.multiArrayValue;
                    MLMultiArrayDataType dataType = multiArrayValue.dataType;
                    uint8_t pixelSizeInBytes = (dataType & 0xFF) / 8;
                    uint8_t* pData = (uint8_t*)multiArrayValue.dataPointer;
                    int sizeZ = [multiArrayValue.shape[0] intValue];
                    int sizeY = [multiArrayValue.shape[1] intValue];
                    int sizeX = [multiArrayValue.shape[2] intValue];
                    
                    double maxVal = *(double_t*) pData;
                    double minVal = *(double_t*) pData;
                    
                    for (int iz =0; iz < sizeZ; ++iz) {
                        printf("\n\t\t Start Image\t%d\n", iz);
                        for (int iy =0; iy < sizeY; ++iy) {
                            //printf("\n");
                            for (int ix=0; ix < sizeX; ++ix) {
                                double curVal = 0.;
                                if (pixelSizeInBytes == 8) {
                                    curVal = *(double_t*) pData;
                                } else {
                                    curVal = (double)(*(Float32*) pData);
                                }
                                //printf("%lf ",  curVal);
                                
                                if (curVal > maxVal) {
                                    maxVal = curVal;
                                }
                                
                                if (curVal < minVal) {
                                    minVal = curVal;
                                }
                                
                                pData += pixelSizeInBytes;
                            }
                        }
                        double scalar = 254./maxVal;
                        uint8_t toCenter = (uint8_t)((scalar * minVal) / 2.);
                        uint8_t centeredMax = 254 - toCenter;
                        printf("\n\t\t minVal = %lf \t maxVal = %lf range = %d..%d\n", minVal, maxVal, (int)toCenter, (int)centeredMax);
                        printf("\n");
                        
                        CVPixelBufferRef grayImageBuffer = NULL;
                        CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)sizeX, (CGFloat)sizeY);
                        [self.imagePlatform setupPixelBuffer:&grayImageBuffer withRect:pixelBufferRect];
                        CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
                        uint32 *pRGBA = (uint32 *)CVPixelBufferGetBaseAddress(grayImageBuffer);
                        pData = (uint8_t*)multiArrayValue.dataPointer;
                        for (int iy =0; iy < sizeY; ++iy) {
                             ////printf("\n");
                            for (int ix=0; ix < sizeX; ++ix) {
                                double curVal = 0.;
                                if (pixelSizeInBytes == 8) {
                                    curVal = *(double_t*) pData;
                                } else {
                                    curVal = (double)(*(Float32*) pData);
                                }
                                
                                uint8_t grayVal = ((uint8_t)(curVal*scalar)) - toCenter;
                                 //printf("%d ", (int)grayVal);
                                *pRGBA =MAKE_RGBA_UINT32(0xFF, grayVal, grayVal, 0x80); //ABGR due to endianity
                                
                                pRGBA++;
                                pData += pixelSizeInBytes;
                            }
                        }
                        CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
                        
                        IMAGE_TYPE *depthImage = [self.imagePlatform imageFromCVPixelBufferRef:grayImageBuffer imageOrientation:UIImageOrientationUp];
                        
                        NSData* jpegData = [depthImage imageJPEGRepresentationWithCompressionFactor:0.80f];
                        [jpegData writeToFile:@"/Users/dadler/Downloads/outfolder/2_fcrn.jpg" atomically:YES];
                        
                        printf("\n\t\t End Image\t%d\n", iz);
                    }
                }
            }
        }
    };
    
    self.request = [[VNCoreMLRequest alloc] initWithModel:self.model completionHandler:completionHandler];
    self.handler = [[VNImageRequestHandler alloc] initWithCGImage:[image asCGImageRef]
                                                          options:@{VNImageOptionCIContext : self.imagePlatform.imagePlatformCoreContext}];
    //[self.handler performRequests:self.request];
    [self.handler performRequests:@[self.request] error:&error];
}

@end
