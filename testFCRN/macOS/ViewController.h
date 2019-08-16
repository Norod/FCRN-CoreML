//
//  ViewController.h
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

#import "ImageLayerView.h"

@interface ViewController : NSViewController

@property (nonatomic, weak) IBOutlet ImageLayerView *imageView;        // the image to display
@property (nonatomic, weak) IBOutlet ImageLayerView *depthImageView;   // the predicted depth map to display
@property (nonatomic, weak) IBOutlet NSTextField    *textView;         // the image file name to display

@property (nonatomic, weak) IBOutlet NSImageView    *histogramImageView;

@property (nonatomic, weak) IBOutlet NSButton       *imageOpenButton;
@property (nonatomic, weak) IBOutlet NSButton       *depthImageSaveButton;
@property (nonatomic, weak) IBOutlet NSButton       *aspectFillImageSaveButton;
@property (nonatomic, weak) IBOutlet NSButton       *combinedImageSaveButton;


@end

