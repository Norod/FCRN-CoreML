//
//  ViewController.m
//  testFCRN
//
//  Created by Doron Adler on 25/08/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import "ViewController.h"

@import Photos;

//ML_MODEL_CLASS_NAME is defined in "User defined build settings"
//ML_MODEL_CLASS_HEADER_STRING=\"$(ML_MODEL_CLASS_NAME).h\"
//ML_MODEL_CLASS=$(ML_MODEL_CLASS_NAME)
//ML_MODEL_CLASS_NAME_STRING=@\"$(ML_MODEL_CLASS_NAME)\"

#import ML_MODEL_CLASS_HEADER_STRING
#import "ImagePlatform.h"

@import CoreML;
@import Vision;

@interface ViewController ()  <UINavigationControllerDelegate, UIImagePickerControllerDelegate>

@property (nonatomic, strong) ML_MODEL_CLASS *fcrn;
@property (nonatomic, strong) VNCoreMLModel *model;
@property (nonatomic, strong) VNCoreMLRequest *request;
@property (nonatomic, strong) VNImageRequestHandler *handler;

@property (nonatomic, strong) ImagePlatform* imagePlatform;

@property (nonatomic, weak) IBOutlet UIImageView *inputImageView;
@property (nonatomic, strong) NSString *mediaType;
@property (nonatomic, strong) UIImage *croppedInputImage;
@property (nonatomic, weak) IBOutlet UIImageView *croppedInputImageView;

@property (nonatomic, strong) UIImage *disparityImage;
@property (nonatomic, weak) IBOutlet UIImageView *disparityImageImageView;

@property (nonatomic, strong) UIImage *depthHistogramImage;
@property (nonatomic, weak) IBOutlet UIImageView *depthHistogramImageImageView;

@property (nonatomic, weak) IBOutlet UILabel *statusLabel;

@property (nonatomic, strong) NSData *combinedImageData;

@property (nonatomic, weak) IBOutlet UIButton *imageOpenButton;
@property (nonatomic, weak) IBOutlet UIButton *depthImageSaveButton;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.imagePlatform = [[ImagePlatform alloc] init];
    
    [self updateStatusLabelText:@"Loading model"];
    self.imageOpenButton.enabled = NO;
    self.depthImageSaveButton.enabled = NO;
       
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
    NSLog(@"didLoadModel (\"%@\")", ML_MODEL_CLASS_NAME_STRING);
    [self updateStatusLabelText:[NSString stringWithFormat:@"didLoadModel (\"%@\")", ML_MODEL_CLASS_NAME_STRING]];
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageOpenButton.enabled = NO;
        [self openImagePickerAndSelectImage];
    });
    
}

- (void)didFailToLoadModelWithError:(NSError*)error {
    //self.textView.stringValue = NSLocalizedString(@"depthPrediction.failToLoad", @"Error loading model");
    NSLog(@"Error loading model (\"%@\") because \"%@\"", ML_MODEL_CLASS_NAME_STRING, error);
    [self updateStatusLabelText:[NSString stringWithFormat:@"Error loading model (\"%@\") because \"%@\"", ML_MODEL_CLASS_NAME_STRING, error.localizedDescription]];
}

#pragma mark - Status label

- (void)updateStatusLabelText:(NSString*)text {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.statusLabel.text = text;
    });
}

#pragma mark - Button action handlers

- (IBAction)handleActionForImageOpenButton:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageOpenButton.enabled = NO;
        [self openImagePickerAndSelectImage];
    });
}

- (IBAction)handleActionForDepthImageSaveButton:(id)sender {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.depthImageSaveButton.enabled = NO;
        UIImageWriteToSavedPhotosAlbum(self.disparityImage, self, @selector(image:didFinishSavingWithError:contextInfo:), nil);
    });
}

#pragma mark - UIImagePickerController

- (void)openImagePickerAndSelectImage {
    UIImagePickerController *imagePickerController = [[UIImagePickerController alloc] init];
    [imagePickerController setDelegate:self];
    [self showViewController:imagePickerController sender:self];
}

#pragma mark - UIImagePickerControllerDelegate

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary<UIImagePickerControllerInfoKey, id> *)info {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIImage *inputImage = [info objectForKey:UIImagePickerControllerEditedImage];
        if (inputImage == nil) {
            inputImage = [info objectForKey:UIImagePickerControllerOriginalImage];
        }
        
        self.mediaType = [info objectForKey:UIImagePickerControllerMediaType];
        if (inputImage) {
            self.inputImageView.image = inputImage;
            [self dismissViewControllerAnimated:YES completion:^{
                self.imageOpenButton.enabled = NO;
                self.depthImageSaveButton.enabled = NO;
               [self predictDepthMapFromInputImage:inputImage];
            }];
            
        }
        
        
       });
}
- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
    [self.navigationController popToRootViewControllerAnimated:YES];
    [self dismissViewControllerAnimated:NO completion:^{
       self.imageOpenButton.enabled = YES;
    }];
}

// Adds a photo to the saved photos album.  The optional completionSelector should have the form:
- (void)image:(UIImage *)image didFinishSavingWithError:(NSError *)error contextInfo:(void *)contextInfo {
    NSLog(@"image: %@ didFinishSavingWithError: %@ contextInfo: 0x%llx", image, error, (uint64_t)contextInfo);
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.depthImageSaveButton setEnabled:YES];
        NSLog(@"Depth image was saved to gallery");
        [self updateStatusLabelText:@"Depth image was saved to gallery"];
    });
}


#pragma mark - Depth prediction


- (void)predictDepthMapFromInputImage:(UIImage*)inputImage {
    NSError *error = nil;
    
    VNRequestCompletionHandler completionHandler =  ^(VNRequest *request, NSError * _Nullable error) {
         dispatch_async(dispatch_get_main_queue(), ^{
            // self.textView.stringValue = NSLocalizedString(@"depthPrediction.completionHandler", @"Processing results...");
             NSLog(@"Processing results...");
             [self updateStatusLabelText:@"Processing results..."];
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
                    
                    UIImage *croppedImage  = [self.imagePlatform cropImage:inputImage
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
    [self updateStatusLabelText:@"Predicting depth map..."];
    [self.handler performRequests:@[self.request] error:&error];
}

- (void)didFinish {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageOpenButton.enabled = YES;
    });
}

- (void)didPrepareImages {
    dispatch_async(dispatch_get_main_queue(), ^{
        
        self.handler = nil;
        self.request = nil;
        
        //self.textView.stringValue = NSLocalizedString(@"depthPrediction.didPrepareImages", @"Images are ready");
        NSLog(@"Images are ready");
        [self updateStatusLabelText:@"Images are ready"];
        
        [PHPhotoLibrary requestAuthorization:^( PHAuthorizationStatus status ) {
            if ( status == PHAuthorizationStatusAuthorized ) {
                [[PHPhotoLibrary sharedPhotoLibrary] performChanges:^{
                   
                    if (self.combinedImageData) {
                        NSLog(@"Combined image data is available");
                        [self updateStatusLabelText:@"Portrait image data is available"];
                        PHAssetResourceCreationOptions* options = [[PHAssetResourceCreationOptions alloc] init];
                        options.uniformTypeIdentifier =  self.mediaType;
                        PHAssetCreationRequest* creationRequest = [PHAssetCreationRequest creationRequestForAsset];
                        [creationRequest addResourceWithType:PHAssetResourceTypePhoto data:self.combinedImageData options:options];
                    }
                    
                } completionHandler:^( BOOL success, NSError* _Nullable error ) {
                    if ( ! success ) {
                        NSLog( @"Error occurred while saving photo to photo library: %@", error );
                        [self updateStatusLabelText:[NSString stringWithFormat:@"Error occurred while saving photo to photo library: %@", error.localizedDescription]];
                    } else {
                        [self updateStatusLabelText:@"Cropped portrait image was saved to gallery"];
                    }
                    
                    [self didFinish];
                }];
            }
            else {
                NSLog(@"Not authorized to save photo" );
                [self updateStatusLabelText:@"Not authorized to save photo"];
                [self didFinish];
            }
        }];
                    
        if (self.disparityImage) {
            [self.disparityImageImageView setContentMode:UIViewContentModeScaleAspectFit];
            [self.disparityImageImageView setImage:self.disparityImage];
            [self.depthImageSaveButton setEnabled:YES];
        }
        
        if (self.croppedInputImage) {
            [self.croppedInputImageView setContentMode:UIViewContentModeScaleAspectFit];
            [self.croppedInputImageView setImage:self.croppedInputImage];
        }
        
        if (self.depthHistogramImage) {
            [self.depthHistogramImageImageView setImage:self.depthHistogramImage];
        }
        
    });
}

@end
