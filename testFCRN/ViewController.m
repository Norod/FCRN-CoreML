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
@import Accelerate;

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
                    
                    char *grayBuff = malloc(sizeY*sizeX*sizeof(char));
                    if (pixelSizeInBytes == 8) {
                        double maxVD = 0.;
                        double minVD = 0.;
                        vDSP_maxvD((const double *)pData, 1, &maxVD, sizeY*sizeX);
                        vDSP_minvD((const double *)pData, 1, &minVD, sizeY*sizeX);
                        const  double scalar = 255./maxVD;
                        double *doubleBuff1 = malloc(sizeY*sizeX*sizeof(double));
                        vDSP_vsmulD((const double *)pData, 1, &scalar, doubleBuff1, 1, sizeY*sizeX);
                        const double offset = -((scalar * minVD) / 2.);
                        double *doubleBuff2 = malloc(sizeY*sizeX*sizeof(double));
                        vDSP_vsaddD(doubleBuff1, 1, &offset, doubleBuff2, 1, sizeY*sizeX);
                        free(doubleBuff1);
                        vDSP_vfix8D(doubleBuff2, 1, grayBuff, 1,  sizeY*sizeX);
                        free(doubleBuff2);
                    }
                    
                    
                    CVPixelBufferRef grayImageBuffer = NULL;
                    CGRect pixelBufferRect = CGRectMake(0.0f, 0.0f, (CGFloat)sizeX, (CGFloat)sizeY);
                    [self.imagePlatform setupPixelBuffer:&grayImageBuffer
                                         pixelFormatType:kCVPixelFormatType_32BGRA
                                                withRect:pixelBufferRect];
                    CVPixelBufferLockBaseAddress(grayImageBuffer, 0);
                    uint32 *pRGBA = (uint32 *)CVPixelBufferGetBaseAddress(grayImageBuffer);
                    for (int i = 0; i < sizeY * sizeX; ++i) {
                        *pRGBA =MAKE_RGBA_UINT32(0xFF, grayBuff[i], grayBuff[i], 0x80); //ABGR due to endianity
                        pRGBA++;
                    }
                    CVPixelBufferUnlockBaseAddress(grayImageBuffer, 0);
                    
                    IMAGE_TYPE *depthImage32 = [self.imagePlatform imageFromCVPixelBufferRef:grayImageBuffer imageOrientation:UIImageOrientationUp];
                    
                    NSData* jpegData = [depthImage32 imageJPEGRepresentationWithCompressionFactor:0.80f];
                    [jpegData writeToFile:@"/Users/dadler/Downloads/outfolder/2_fcrn32.jpg" atomically:YES];
                    
                    [self.imagePlatform teardownPixelBuffer:&grayImageBuffer];
                    free(grayBuff);
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
