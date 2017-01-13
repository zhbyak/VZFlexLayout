//
//  FBHeaderNode.m
//  VZFlexLayout
//
//  Created by moxin on 16/2/26.
//  Copyright © 2016年 Vizlab. All rights reserved.
//

#import "FBHeaderNode.h"
#import "FBNameNode.h"
#import "FBStarNode.h"
#import "VZFStackNode.h"
#import "FBHostItem.h"
#import "FBImageDownloader.h"
#import "FBIconNode.h"
#import "VZFNodeViewClass.h"
#import "VZFNodeSpecs.h"
#import "VZFTextNode.h"
#import "VZFTextNodeSpecs.h"

@implementation FBHeaderNode

+ (instancetype)newWithProps:(FBHostItem* )item Store:(id)store Context:(id)context{
    
    
    return [super newWithNode:[VZFStackNode newWithStackAttributes:{} NodeSpecs:{
        .margin = 10
    } Children:{
        {[FBIconNode newWithURL:item.headIconURL]},//头像
        {[VZFStackNode newWithStackAttributes:{
            .direction = VZFlexVertical,
            .justifyContent = VZFlexSpaceBetween,
//            .spacing = 5
        } NodeSpecs:{
            .marginLeft = 10,
            .flexGrow = 1,
        } Children:{
//            {
//                .node = [VZFTextNode newWithTextAttributes:{
//                    .text = item.nick,
//                    .color = [UIColor blackColor],
//                    .fontSize = 14.0f,
//                    .alignment = NSTextAlignmentLeft
//                } NodeSpecs:{}]
//            },
//            {
//                [VZFTextNode newWithTextAttributes:{
//                    
//                    .text = item.time,
//                    .color = [UIColor lightGrayColor],
//                    .fontSize = 12.0f,
//                    .alignment = NSTextAlignmentLeft
//                    
//                }NodeSpecs:{}]
//            }
            {[FBNameNode newWithName:item.nick createTime:item.time]},//姓名+时间
//            {
//                [VZFTextNode newWithTextAttributes:{
//                    .text = item.content,
//                    .color = [UIColor redColor],
//                    .fontSize = 12.0f,
//                    .alignment = NSTextAlignmentLeft,
//                    .lines = 0
//                } NodeSpecs:{
//                    .marginTop = 10
//                }]
//            }
            {[FBStarNode newWithScore:[item.score floatValue]]}, //星星

        }]}
    }]];
    
}

@end