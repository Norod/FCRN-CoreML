//
//  ImageLayerView.h
//  testFCRN
//
//  Created by Doron Adler on 31/07/2019.
//  Copyright © 2019 Doron Adler. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface ImageLayerView : NSView

@property (nonatomic, strong) NSImage *image;
@property (nonatomic, assign) CALayerContentsGravity contentsGravity;

- (NSImage *)imageFromLayer;

@end

NS_ASSUME_NONNULL_END
