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

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imagePlatform = [[ImagePlatform alloc] init];
     NSError *error = nil;
     self.fcrn = [[ML_MODEL_CLASS alloc] init];
     self.model = [VNCoreMLModel modelForMLModel:self.fcrn.model error:&error];
    
    // Do any additional setup after loading the view.
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
    [self.imageView setImage:image];
    self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
//    self.imageView.layer.contentsGravity = kCAGravityResizeAspectFill;
//    [self.imageView.layer setNeedsLayout];
    [self.textView setStringValue:[imagePathStr lastPathComponent]];    // display the file name
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
    
    NSArray *fileTypes = [NSArray arrayWithObjects:@"jpg", @"gif", @"png", @"tiff", nil];
    [openPanel setAllowsMultipleSelection:NO];
    [openPanel setMessage:@"Choose an image file to display:"];
    [openPanel setAllowedFileTypes:fileTypes];
    [openPanel setDirectoryURL:[NSURL fileURLWithPath:@"~/Pictures/"]];
    [openPanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK)
        {
            if ([[openPanel URL] isFileURL])
            {
                NSString* imagePathStr = [[openPanel URL] path];
                NSImage *image = [self configureImage:imagePathStr];
                [self predictDepthMapFromImage:image];
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
    NSImage *depthImage = [self.depthImageView image];
    if (depthImage == nil) {
        return;
    }
    
    NSSavePanel *savePanel = [NSSavePanel savePanel];
    NSArray *fileTypes = [NSArray arrayWithObjects:@"jpg", @"png", @"tiff", nil];
    [savePanel setAllowedFileTypes:fileTypes];
    [savePanel setAllowsOtherFileTypes:NO];
    [savePanel setMessage:@"Save depth image file:"];
    [savePanel setDirectoryURL:[NSURL fileURLWithPath:@"~/Pictures/"]];
    [savePanel setCanCreateDirectories:YES];
    [savePanel beginSheetModalForWindow:self.view.window completionHandler:^(NSInteger result) {
        if (result == NSModalResponseOK) {
            if ([[savePanel URL] isFileURL])
            {
                NSString* depthImagePathStr = [[savePanel URL] path];
                
                NSData* jpegData = [depthImage imageJPEGRepresentationWithCompressionFactor:0.80f];
                BOOL didWrite = [jpegData writeToFile:depthImagePathStr atomically:YES];
                if (didWrite) {
                    NSLog(@"Wrote to \"%@\"", depthImagePathStr);
                } else {
                    NSLog(@"Failed writing to \"%@\"", depthImagePathStr);
                }
            }
        }
    }];
}

- (void)predictDepthMapFromImage:(NSImage *)image {
    NSError *error = nil;
        
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
                    //int sizeZ = [multiArrayValue.shape[0] intValue];
                    int sizeY = [multiArrayValue.shape[1] intValue];
                    int sizeX = [multiArrayValue.shape[2] intValue];
                    
                    NSImage * depthImage32 = nil;
                    depthImage32 = [self.imagePlatform createBGRADepthImageFromResultData:pData
                                                                         pixelSizeInBytes:pixelSizeInBytes
                                                                                    sizeX:sizeX
                                                                                    sizeY:sizeY];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self.depthImageView setImage:depthImage32];
                        self.depthImageView.layer.contentsGravity = kCAGravityResizeAspect;
                        [self.saveButton setEnabled:YES];
                    });
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
