//
//  ViewController.m
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ViewController.h"

//ML_MODEL_CLASS_NAME is defined in "User defined build settings"
//ML_MODEL_CLASS_HEADER_STRING=\"$(ML_MODEL_CLASS_NAME).h\"
//ML_MODEL_CLASS=$(ML_MODEL_CLASS_NAME)
//ML_MODEL_CLASS_NAME_STRING=@\"$(ML_MODEL_CLASS_NAME)\"

#import ML_MODEL_CLASS_HEADER_STRING
#import "ImagePlatform.h"

@import CoreML;
@import Vision;

//#import "ImagePlatform.h"

@interface ViewController ()

@property (nonatomic, strong) ML_MODEL_CLASS *fcrn;
@property (nonatomic, strong) VNCoreMLModel *model;
@property (nonatomic, strong) VNCoreMLRequest *request;
@property (nonatomic, strong) VNImageRequestHandler *handler;

@property (nonatomic, strong) ImagePlatform* imagePlatform;

@property (nonatomic, strong) NSString *fileName;

@property (nonatomic, strong) NSImage *inputImage;
@property (nonatomic, strong) NSImage *croppedInputImage;

@property (nonatomic, strong) NSImage *disparityImage;
@property (nonatomic, strong) NSImage *depthHistogramImage;

@property (nonatomic, strong) NSData *combinedImageData;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imagePlatform = [[ImagePlatform alloc] init];
    
    self.textView.stringValue = NSLocalizedString(@"depthPrediction.loading", @"Loading model");
    self.imageOpenButton.enabled = NO;
    self.aspectFillImageSaveButton.enabled = NO;
    self.depthImageSaveButton.enabled = NO;
    self.combinedImageSaveButton.enabled = NO;
    
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        [self loadModel];
    });
}

- (void)loadModel {
    NSError *error = nil;
    self.fcrn = [[ML_MODEL_CLASS alloc] init];
    self.model = [VNCoreMLModel modelForMLModel:self.fcrn.model error:&error];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.model != nil) {
            [self didLoadModel];
        } else {
            [self didFailToLoadModelWithError:error];
        }
    });
    
}

- (void)didLoadModel {
    self.textView.stringValue = NSLocalizedString(@"depthPrediction.readyToOpen", @"Please open an image");
    self.imageOpenButton.enabled = YES;
}

- (void)didFailToLoadModelWithError:(NSError*)error {
    self.textView.stringValue = NSLocalizedString(@"depthPrediction.failToLoad", @"Error loading model");
    NSLog(@"Error loading model: \"%@\"", error);
}

- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];
    
    // Update the view, if already loaded.
}


// -------------------------------------------------------------------------------
//    configureImage:imagePathStr
// -------------------------------------------------------------------------------
- (NSImage*)configureImage:(NSString *)imagePathStr
{
    // load the image from the given path string and set is to the NSImageView
    NSImage* image = [[NSImage alloc] initWithContentsOfFile:imagePathStr];
    CGImageRef imageRef = [image asCGImageRef];
    CGFloat width  = CGImageGetWidth(imageRef);
    CGFloat height = CGImageGetHeight(imageRef);
    [image setSize:CGSizeMake(width, height)];
    [self.imageView setContentsGravity:kCAGravityResizeAspectFill];
    [self.imageView setImage:image];
    [self.aspectFillImageSaveButton setEnabled:YES];
    self.fileName = [imagePathStr lastPathComponent];
    [self.textView setStringValue:self.fileName];    // display the file name
    return image;
}

// -------------------------------------------------------------------------------
//    openImageAction:sender
//
//    User clicked the "Open" button, open the NSOpenPanel to choose an image.
// -------------------------------------------------------------------------------
- (IBAction)openImageAction:(id)sender
{
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    
    NSArray* imageTypes = [NSImage imageTypes];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setMessage:@"Choose an image file"];
    [openPanel setAllowedFileTypes:imageTypes];
    //[panel setNameFieldStringValue:newName];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:@"~/Pictures/"]];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK)
        {
            if ([[openPanel URL] isFileURL])
            {
                NSString* imagePathStr = [[openPanel URL] path];
                NSImage *image = [self configureImage:imagePathStr];
                
                self.imageOpenButton.enabled = NO;
                self.textView.stringValue = NSLocalizedString(@"depthPrediction.predicting", @"Please wait...");
                dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    [self predictDepthMapFromInputImage:image];
                });
            }
        }
    }];
}

// -------------------------------------------------------------------------------
//    openImageAction:sender
//
//    User clicked the "Save" button, open the NSOpenPanel to save the images.
// -------------------------------------------------------------------------------
- (IBAction)saveImageAction:(id)sender
{
    NSImage *depthImage = self.disparityImage;
    if (depthImage == nil) {
        return;
    }
    
    NSString *fileNameToSuggest = [self.fileName stringByDeletingPathExtension];
    NSString *fileExtentionToSuggest = [self.fileName pathExtension];
    NSString *filePathToSuggest = nil;
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"jpg", @"jpeg", @"png", @"tiff", nil];
    [savePanel setAllowedFileTypes:fileTypes];
    [savePanel setAllowsOtherFileTypes:NO];
    if (sender == self.depthImageSaveButton) {
        [savePanel setMessage:@"Save depth image file:"];
        filePathToSuggest = [NSString stringWithFormat:@"%@-fcrn_depth.%@", fileNameToSuggest, fileExtentionToSuggest];
    } else if (sender == self.aspectFillImageSaveButton) {
        [savePanel setMessage:@"Save aspect-fill cropped image file:"];
        filePathToSuggest = [NSString stringWithFormat:@"%@-fcrn.%@", fileNameToSuggest, fileExtentionToSuggest];
    } else if (sender == self.combinedImageSaveButton) {
        filePathToSuggest = [NSString stringWithFormat:@"%@-fcrn_combined.%@", fileNameToSuggest, fileExtentionToSuggest];
    }
    
    [savePanel setNameFieldStringValue:filePathToSuggest];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:@"~/Pictures/"]];
    [savePanel setCanCreateDirectories:YES];
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            if ([[savePanel URL] isFileURL])
            {
                NSString* depthImagePathStr = [[savePanel URL] path];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    NSData* jpegData = nil;
                    if (sender == self.depthImageSaveButton) {
                        jpegData = [depthImage imageJPEGRepresentationWithCompressionFactor:0.80f];
                    } else if (sender == self.aspectFillImageSaveButton) {
                        jpegData = [self.croppedInputImage imageJPEGRepresentationWithCompressionFactor:0.80f];
                    } else if (sender == self.combinedImageSaveButton) {
                        jpegData = self.combinedImageData;
                    }
                    BOOL didWrite = [jpegData writeToFile:depthImagePathStr atomically:YES];
                    if (didWrite) {
                        NSLog(@"Wrote to \"%@\"", depthImagePathStr);
                    } else {
                        NSLog(@"Failed writing to \"%@\"", depthImagePathStr);
                    }
                });
            }
        }
    }];
}

- (void)predictDepthMapFromInputImage:(NSImage*)inputImage {
    NSError *error = nil;
    
    VNRequestCompletionHandler completionHandler =  ^(VNRequest *request, NSError * _Nullable error) {
         dispatch_async(dispatch_get_main_queue(), ^{
             self.textView.stringValue = NSLocalizedString(@"depthPrediction.completionHandler", @"Processing results...");
         });
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
                    //int sizeZ = [multiArrayValue.shape[0] intValue];
                    int sizeY = [multiArrayValue.shape[1] intValue];
                    int sizeX = [multiArrayValue.shape[2] intValue];
                    
                    [self.imagePlatform prepareImagePlatformContextFromResultData:pData
                                                                 pixelSizeInBytes:pixelSizeInBytes
                                                                            sizeX:sizeX
                                                                            sizeY:sizeY];
                    
                    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
                    self.disparityImage = [self.imagePlatform createDisperityDepthImage];
                    //self.depthImage =  [self.imagePlatform createBGRADepthImage];
                                                            
                    CGRect inputImageCropRect = [self.imagePlatform cropRectFromImageSize:inputImage.size
                                                                   withSizeForAspectRatio:self.disparityImage.size];
                    
                    NSImage *croppedImage  = [self.imagePlatform cropImage:inputImage
                                                              withCropRect:inputImageCropRect];
                    self.croppedInputImage = croppedImage;
                    
                    self.combinedImageData =  [self.imagePlatform addDepthMapToExistingImage:croppedImage];
                        
                    self.depthHistogramImage = [self.imagePlatform depthHistogram];
                        
                    [self didPrepareImages];
                    });
                }
            }
        }
    };
    
    
    self.request = [[VNCoreMLRequest alloc] initWithModel:self.model completionHandler:completionHandler];
    CGImageRef imageRef = [inputImage asCGImageRef];
    self.handler = [[VNImageRequestHandler alloc] initWithCGImage: imageRef
                                                          options:@{VNImageOptionCIContext : self.imagePlatform.imagePlatformCoreContext}];
    //[self.handler performRequests:self.request];
    [self.handler performRequests:@[self.request] error:&error];
}

- (void)didPrepareImages {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.handler = nil;
        self.request = nil;
        
        self.textView.stringValue = NSLocalizedString(@"depthPrediction.didPrepareImages", @"Images are ready");
                    
        if (self.disparityImage) {
            [self.depthImageView setContentsGravity:kCAGravityResizeAspect];
            [self.depthImageView setImage:self.disparityImage];
            [self.depthImageSaveButton setEnabled:YES];
        }
        
        if (self.croppedInputImage) {
            [self.imageView setContentsGravity:kCAGravityResizeAspect];
            [self.imageView setImage:self.croppedInputImage];
        }
        
        if (self.depthHistogramImage) {
            [self.histogramImageView setImage:self.depthHistogramImage];
        }
        
        if (self.combinedImageData) {
            [self.combinedImageSaveButton setEnabled:YES];
        }
        
        self.imageOpenButton.enabled = YES;
    });
}

@end
