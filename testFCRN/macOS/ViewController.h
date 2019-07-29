//
//  ViewController.h
//  testFCRN
//
//  Created by Doron Adler on 28/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <AppKit/AppKit.h>

@interface ViewController : NSViewController

@property (nonatomic, weak) IBOutlet NSImageView *imageView;    // the image to display
@property (nonatomic, weak) IBOutlet NSTextField *textView;     // the image file name to display


@end

