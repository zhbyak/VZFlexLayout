//
//  VZFStackView.m
//  O2OReact
//
//  Created by moxin on 16/5/30.
//  Copyright © 2016年 Alipay. All rights reserved.
//

#import "VZFStackView.h"

@implementation VZFStackView

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event{
    [super touchesBegan:touches withEvent:event];
    if(self.highlightColor){
        self.backgroundColor = self.highlightColor;
    }else{
        self.backgroundColor = self.defaultColor;
    }
}
- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event{
    [super touchesMoved:touches withEvent:event];
    
}
- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event{
    [super touchesEnded:touches withEvent:event];
    self.backgroundColor = self.defaultColor;
    
}
- (void)touchesCancelled:(nullable NSSet<UITouch *> *)touches withEvent:(nullable UIEvent *)event{
    
    [super touchesCancelled:touches withEvent:event];
    self.backgroundColor = self.defaultColor;
}


/////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - backing view interface

- (void)resetState
{
    self.backgroundColor = self.defaultColor;
}

@end
