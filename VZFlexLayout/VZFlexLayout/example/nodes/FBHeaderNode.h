//
//  FBHeaderNode.h
//  VZFlexLayout
//
//  Created by moxin on 16/2/26.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "VZFCompositeNode.h"

@class FBHostItem;
@interface FBHeaderNode : VZFCompositeNode

+ (instancetype)newWithItem:(FBHostItem* )item;

@end
