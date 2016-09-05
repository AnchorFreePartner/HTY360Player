//
//  HTYSlider.h
//  K360Player
//
//  Created by Sergey Kim on 05.09.16.
//  Copyright © 2016 Sergey Kim. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface HTYSlider : UISlider

@property (nonatomic, strong) UIProgressView * bufferView;

- (void) setup;
- (void) setBufferValue:(float)value;

@end
