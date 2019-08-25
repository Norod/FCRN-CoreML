//
//  ViewController.m
//  testFCRN
//
//  Created by Doron Adler on 25/08/2019.
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
    
//    self.textView.stringValue = NSLocalizedString(@"depthPrediction.loading", @"Loading model");
//    self.imageOpenButton.enabled = NO;
//    self.aspectFillImageSaveButton.enabled = NO;
//    self.depthImageSaveButton.enabled = NO;
//    self.combinedImageSaveButton.enabled = NO;
       
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
    //self.textView.stringValue = NSLocalizedString(@"depthPrediction.readyToOpen", @"Please open an image");
    //self.imageOpenButton.enabled = YES;
    NSLog(@"didLoadModel (\"%@\")", ML_MODEL_CLASS_NAME_STRING);
}

- (void)didFailToLoadModelWithError:(NSError*)error {
    //self.textView.stringValue = NSLocalizedString(@"depthPrediction.failToLoad", @"Error loading model");
    NSLog(@"Error loading model (\"%@\") because \"%@\"", ML_MODEL_CLASS_NAME_STRING, error);
}

@end
