//
//  VZFTextRenderer.m
//  TextKitTest
//
//  Created by Sleen on 2016/12/1.
//  Copyright © 2016年 Sleen. All rights reserved.
//

#import "VZFTextNodeRenderer.h"
#import <CoreText/CoreText.h>


#define VZF_SCREEN_SCALE    ([UIScreen mainScreen].scale)
#define VZF_CEIL_PIXEL(v)   (ceil((v) * VZF_SCREEN_SCALE) / VZF_SCREEN_SCALE)
#define VZF_ROUND_PIXEL(v)  (round((v) * VZF_SCREEN_SCALE) / VZF_SCREEN_SCALE)


@interface VZFTextLine : NSObject

@property (nonatomic, strong) id line;
@property (nonatomic, assign) CGFloat width;
@property (nonatomic, assign) CGFloat height;
@property (nonatomic, assign) CGFloat offsetY;
@property (nonatomic, assign) CGFloat top;
@property (nonatomic, assign) CGFloat ascent;
@property (nonatomic, assign) CGFloat scale;

@end
@implementation VZFTextLine
@end


@implementation VZFTextNodeRenderer
{
    BOOL _calculated;
    CGSize _textSize;
    NSArray<VZFTextLine *> *_lines;
    NSAttributedString *_unfixedText;
}

- (void)setLineBreakMode:(VZFTextLineBreakMode)lineBreakMode {
    if (_lineBreakMode != lineBreakMode) {
        _calculated = NO;
    }
    _lineBreakMode = lineBreakMode;
}

- (void)setTruncatingMode:(VZFTextTruncationMode)truncatingMode {
    if (_truncatingMode != truncatingMode) {
        _calculated = NO;
    }
    _truncatingMode = truncatingMode;
}

- (void)setAlignment:(NSTextAlignment)alignment {
    BOOL oldJustified = _alignment == NSTextAlignmentJustified;
    BOOL justified = alignment == NSTextAlignmentJustified;
    if (oldJustified != justified) {
        _calculated = NO;
    }
    _alignment = alignment;
}

- (void)setMaxNumberOfLines:(NSUInteger)maxNumberOfLines {
    if (_maxNumberOfLines != maxNumberOfLines) {
        _calculated = NO;
    }
    _maxNumberOfLines = maxNumberOfLines;
}

- (void)setAdjustsFontSizeToFitWidth:(BOOL)adjustsFontSizeToFitWidth {
    if (_adjustsFontSizeToFitWidth != adjustsFontSizeToFitWidth) {
        _calculated = NO;
    }
    _adjustsFontSizeToFitWidth = adjustsFontSizeToFitWidth;
}

- (void)setMinimumScaleFactor:(CGFloat)minimumScaleFactor {
    if (_minimumScaleFactor != minimumScaleFactor) {
        _calculated = NO;
    }
    _minimumScaleFactor = minimumScaleFactor;
}

- (void)setBaselineAdjustment:(UIBaselineAdjustment)baselineAdjustment {
    if (_baselineAdjustment != baselineAdjustment) {
        _calculated = NO;
    }
    _baselineAdjustment = baselineAdjustment;
}

- (void)setMaxSize:(CGSize)maxSize {
    if (_calculated && !(maxSize.width >= _textSize.width && maxSize.width <= _maxSize.width &&
                         maxSize.height >= _textSize.height && maxSize.height <= _maxSize.height)) {
        _calculated = NO;
    }
    _maxSize = maxSize;
}

- (void)setText:(NSAttributedString *)text {
    _unfixedText = text;
    // https://openradar.appspot.com/28522327
    // https://github.com/ibireme/YYText/issues/548#issuecomment-260231194
    BOOL isIOS10OrGreater = [[UIDevice currentDevice].systemVersion floatValue] >= 10;
    if (isIOS10OrGreater) {
        NSMutableAttributedString *mutText = text.mutableCopy;
        [mutText fixAttributesInRange:NSMakeRange(0, mutText.length)];
        [mutText enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, mutText.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
            UIFont *font = (UIFont *)value;
            if ([font.fontName isEqualToString:@".AppleColorEmojiUI"]) {
                [mutText addAttribute:NSFontAttributeName value:[UIFont fontWithName:@"AppleColorEmoji" size:font.pointSize] range:range];
            }
        }];
        text = mutText;
    }
    
    if (_text != text && ![_text isEqualToAttributedString:text]) {
        _calculated = NO;
    }
    _text = text;
}

- (CGSize)textSize {
    [self _calculate];
    return _textSize;
}

- (NSUInteger)linesCount {
    [self _calculate];
    return _lines.count;
}

CGFloat vz_getAscentCallback(void *context) {
    return ((__bridge UIImage *)context).size.height;
}

CGFloat vz_getDescentCallback(void *context) {
    return 0;
}

CGFloat vz_getWidthCallback(void *context) {
    return ((__bridge UIImage *)context).size.width;
}

- (CTLineRef)truncateLine:(CTLineRef)line text:(NSAttributedString *)text typesetter:(CTTypesetterRef)typesetter start:(CFIndex)start {
    // 省略号使用行末的字符的属性，当省略号在头部或中间时，得到的效果不一定正确
    
    CFIndex truncationTokenAttributesIndex = start + CTTypesetterSuggestClusterBreak(typesetter, start, self.maxSize.width) - 1;
    NSDictionary *truncationTokenAttributes = [text attributesAtIndex:truncationTokenAttributesIndex effectiveRange:nil];
    NSAttributedString *tokenString = [[NSAttributedString alloc] initWithString:@"…" attributes:truncationTokenAttributes];
    CTLineRef truncationLine = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)tokenString);
    
    CTLineTruncationType type = _truncatingMode == VZFTextTruncatingHead ? kCTLineTruncationStart :
    _truncatingMode == VZFTextTruncatingMiddle ? kCTLineTruncationMiddle : kCTLineTruncationEnd;
    CTLineRef truncatedLine = CTLineCreateTruncatedLine(line, self.maxSize.width, type, truncationLine);
    if (truncatedLine) {
        CFRelease(line);
        line = truncatedLine;
    }
    CFRelease(truncationLine);
    return line;
}

- (BOOL)isEmoji:(NSString*)textString {
    if (textString.length < 2) {
        return NO;
    }
    
    static NSCharacterSet* VariationSelectors;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        VariationSelectors = [NSCharacterSet characterSetWithRange:NSMakeRange(0xFE00, 16)];
    });
    
    if ([textString rangeOfCharacterFromSet: VariationSelectors].location != NSNotFound) {
        return YES;
    }
    
    const unichar high = [textString characterAtIndex: 0];
    
    // Surrogate pair (U+1D000-1F9FF)
    if (0xD800 <= high && high <= 0xDBFF) {
        const unichar low = [textString characterAtIndex: 1];
        const int codepoint = ((high - 0xD800) * 0x400) + (low - 0xDC00) + 0x10000;
        
        return (0x1D000 <= codepoint && codepoint <= 0x1F9FF);
        
        // Not surrogate pair (U+2100-27BF)
    } else {
        return (0x2100 <= high && high <= 0x27BF);
    }
}

- (BOOL)isIncludingEmoji:(NSString*)textString inRange:(NSRange)range {
    BOOL __block result = NO;
    
    [textString enumerateSubstringsInRange:range
                                   options:NSStringEnumerationByComposedCharacterSequences
                                usingBlock: ^(NSString* substring, NSRange substringRange, NSRange enclosingRange, BOOL* stop) {
                                    if ([self isEmoji:substring]) {
                                        *stop = YES;
                                        result = YES;
                                    }
                                }];
    
    return result;
}

- (void)_calculate {
    if (_calculated) {
        return;
    }
    
    if (self.text.length == 0 || self.maxSize.width <= 0) {
        _calculated = YES;
        _textSize = CGSizeZero;
        return;
    }
    
    BOOL adjustsFontSizeToFitWidth = _adjustsFontSizeToFitWidth && _maxNumberOfLines == 1 && _minimumScaleFactor < 1;
    
//    CFAbsoluteTime t1 = CFAbsoluteTimeGetCurrent();
//    [self.text boundingRectWithSize:CGSizeMake(_maxWidth, CGFLOAT_MAX) options:NSStringDrawingUsesLineFragmentOrigin context:nil];
//    CFAbsoluteTime t2 = CFAbsoluteTimeGetCurrent();
    
    NSMutableAttributedString *mutableText = self.text.mutableCopy;
    CFMutableAttributedStringRef attrString = (__bridge CFMutableAttributedStringRef)mutableText;
    NSString *plainString = self.text.string;
    
    [self.text enumerateAttribute:NSAttachmentAttributeName inRange:NSMakeRange(0, self.text.length) options:0 usingBlock:^(id  _Nullable value, NSRange range, BOOL * _Nonnull stop) {
        NSTextAttachment *attachment = value;
        if (!attachment.image) return;
        
        CTRunDelegateCallbacks callbacks;
        callbacks.version = kCTRunDelegateVersion1;
        callbacks.getAscent = vz_getAscentCallback;
        callbacks.getDescent = vz_getDescentCallback;
        callbacks.getWidth = vz_getWidthCallback;
        callbacks.dealloc = NULL;
        CTRunDelegateRef delegate = CTRunDelegateCreate(&callbacks, (__bridge void *)(attachment.image));
        CFAttributedStringSetAttribute(attrString, CFRangeMake(range.location, range.length), kCTRunDelegateAttributeName, delegate);
        CFRelease(delegate);
    }];
    
    CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString(attrString);
    
    CFIndex start = 0;
    NSUInteger textLength = self.text.length;
    NSUInteger maxRemainLines = self.maxNumberOfLines ?: UINT32_MAX;
    CGFloat width = 0;
    CGFloat height = 0;
    
    NSMutableArray *lines = [NSMutableArray array];
    while (start < textLength && maxRemainLines-- > 0) {
        BOOL isFirstLine = start == 0;
        
        CGFloat lineSpacing = 0;
        NSParagraphStyle *style = (__bridge NSParagraphStyle *)CFAttributedStringGetAttribute(attrString, start, kCTParagraphStyleAttributeName, NULL);
        if (style) {
            lineSpacing = style.lineSpacing;
        }
        
        if (!isFirstLine) {
            height += lineSpacing / 2;
        }
        
        CFIndex count;
        if (maxRemainLines == 0 && (_truncatingMode != VZFTextTruncatingNone || adjustsFontSizeToFitWidth)) {
            count = 0;
        }
        else {
            if (_lineBreakMode == VZFTextLineBreakByChar) {
                count = CTTypesetterSuggestClusterBreak(typesetter, start, self.maxSize.width);
            }
            else {
                count = CTTypesetterSuggestLineBreak(typesetter, start, self.maxSize.width);
            }
        }
        
        BOOL isLastLine = maxRemainLines == 0 || start + count >= textLength;
        BOOL needsToTruncate = _truncatingMode != VZFTextTruncatingClip && maxRemainLines == 0 && start + count < textLength && !adjustsFontSizeToFitWidth;
        BOOL needsToJustify = _alignment == NSTextAlignmentJustified && start + count < textLength;
        
        CTLineRef line = CTTypesetterCreateLine(typesetter, CFRangeMake(start, count));
        
        if (needsToTruncate) {
            line = [self truncateLine:line text:self.text typesetter:typesetter start:start];
        }
        
        if (needsToJustify) {
            CTLineRef justifiedLine = CTLineCreateJustifiedLine(line, 1, self.maxSize.width);
            if (justifiedLine) {
                CFRelease(line);
                line = justifiedLine;
            }
        }
        
        VZFTextLine *textLine = [VZFTextLine new];
        textLine.top = height;
        
        __block CGFloat maxAscent = 0;
        __block CGFloat maxDescent = 0;
        CFRange range = CTLineGetStringRange(line);
        [_unfixedText enumerateAttributesInRange:NSMakeRange(range.location, range.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
            NSTextAttachment *attachment = attrs[NSAttachmentAttributeName];
            if (attachment.image) {
                CGFloat ascent = attachment.image.size.height;
                if (ascent > maxAscent) {
                    maxAscent = ascent;
                }
                return;
            }
            
            UIFont *font = attrs[NSFontAttributeName] ?: [UIFont systemFontOfSize:[UIFont systemFontSize]];
            CGFloat ascent = font.ascender;
            CGFloat descent = -font.descender;
            if (ascent > maxAscent) {
                maxAscent = ascent;
            }
            if (descent > maxDescent) {
                maxDescent = descent;
            }
        }];
        
        CGFloat ascent, descent, leading;
        CGFloat lineWidth = CTLineGetTypographicBounds(line, &ascent, &descent, &leading);
        
        CGFloat usedLineHeight = VZF_CEIL_PIXEL(maxAscent + maxDescent);
        
        height += usedLineHeight;
        if (lines.count > 0 && height - self.maxSize.height > 1e-5) {
            // 如果高度超出最大高度，则重置相关属性，然后重新计算最后一行
            VZFTextLine *lineBeforelastLine = lines.count - 2 < lines.count ? [lines objectAtIndex:lines.count - 2] : nil;
            if (lineBeforelastLine) {
                CFRange range = CTLineGetStringRange((__bridge CTLineRef)lineBeforelastLine.line);
                start = range.location + range.length;
                height = lineBeforelastLine.top + lineBeforelastLine.height;
            }
            else {
                start = 0;
                height = 0;
            }
            [lines removeLastObject];
            maxRemainLines = 1;
            continue;
        }
        if (!isLastLine) {
            height += lineSpacing / 2;
        }
        
        // 第一种方式得到的行高，在纯英文的时候，小了许多
        // 第二种方式得到的行高，不包含 CTRunDelegate（图片） 的高度
        // CGFloat realLineHeight = ascent + descent + leading;
        // CGFloat realLineHeight = CTLineGetBoundsWithOptions(line, 0).size.height;
        CGFloat realLineHeight = MAX(ascent + descent + leading, CTLineGetBoundsWithOptions(line, 0).size.height);
        CGFloat drawingOffset = (usedLineHeight - realLineHeight) / 2;
        
        textLine.ascent = realLineHeight - descent - leading + drawingOffset;
        textLine.height = usedLineHeight;
        textLine.offsetY = -(descent + leading) - drawingOffset;
        
        // 修复有 emoji 时文本偏下的问题
        if (ascent < 23 && [self isIncludingEmoji:plainString inRange:NSMakeRange(range.location, range.length)]) {
            textLine.offsetY -= ascent * 0.045; // 试出来的 magic number 😉
        }
        
        if (adjustsFontSizeToFitWidth && lineWidth > self.maxSize.width) {
            CGFloat scale = self.maxSize.width / lineWidth;
            if (scale >= _minimumScaleFactor) {
                textLine.scale = scale;
            }
            else {
                NSMutableAttributedString *adjustedText = [mutableText attributedSubstringFromRange:NSMakeRange(range.location, range.length)].mutableCopy;
                [mutableText enumerateAttributesInRange:NSMakeRange(range.location, range.length) options:0 usingBlock:^(NSDictionary<NSString *,id> * _Nonnull attrs, NSRange range, BOOL * _Nonnull stop) {
                    UIFont *font = attrs[NSFontAttributeName] ?: [UIFont systemFontOfSize:[UIFont systemFontSize]];
                    font = [font fontWithSize:font.pointSize * self.minimumScaleFactor];
                    [adjustedText addAttribute:NSFontAttributeName value:font range:NSMakeRange(range.location - start, range.length)];
                }];
                CTTypesetterRef typesetter = CTTypesetterCreateWithAttributedString((__bridge CFAttributedStringRef)adjustedText);
                CFRelease(line);
                line = CTTypesetterCreateLine(typesetter, CFRangeMake(0, range.length));
                line = [self truncateLine:line text:adjustedText typesetter:typesetter start:start];
                CFRelease(typesetter);
                CGFloat newAscent, newDescent, newLeading;
                lineWidth = CTLineGetTypographicBounds(line, &newAscent, &newDescent, &newLeading);
                CGFloat newRealLineHeight = MAX(newAscent + newDescent + newLeading, CTLineGetBoundsWithOptions(line, 0).size.height);
                switch (_baselineAdjustment) {
                    case UIBaselineAdjustmentNone:
                        textLine.offsetY -= ascent - newAscent;
                        break;
                    default:
                    case UIBaselineAdjustmentAlignBaselines:
                        break;
                    case UIBaselineAdjustmentAlignCenters:
                        textLine.offsetY -= ascent - newAscent - (realLineHeight - newRealLineHeight) / 2;
                        break;
                }
            }
        }
        textLine.line = (__bridge_transfer id)line;
        textLine.width = lineWidth;
        
        [lines addObject:textLine];
        start += count;
    }
    _lines = lines;
    
    for (VZFTextLine *line in lines) {
        if (width < line.width) {
            width = line.width;
        }
    }
    width = MIN(width, self.maxSize.width);
    _textSize = CGSizeMake(VZF_CEIL_PIXEL(width), VZF_CEIL_PIXEL(height));
    _calculated = YES;
    CFRelease(typesetter);
    
//    CFAbsoluteTime t3 = CFAbsoluteTimeGetCurrent();
//    NSLog(@"%.3f/%.3f ms", (t2 - t1) * 1000, (t3 - t2) * 1000);
}

- (CGFloat)offsetYWithBounds:(CGRect)bounds {
    switch (_verticalAlignment) {
        case VZFTextVerticalAlignmentTop:
            return bounds.origin.y;
        default:
        case VZFTextVerticalAlignmentCenter:
            return bounds.origin.y + (bounds.size.height - _textSize.height) / 2;
        case VZFTextVerticalAlignmentBottom:
            return bounds.origin.y + (bounds.size.height - _textSize.height);
    }
}

- (CGFloat)baselineOfLineAtIndex:(NSUInteger)index inBounds:(CGRect)bounds {
    [self _calculate];
    
    if (index >= _lines.count) {
        return bounds.size.height;
    }
    
    VZFTextLine *textLine = [_lines objectAtIndex:index];
    return textLine.ascent + textLine.top + [self offsetYWithBounds:bounds];
}

- (CGFloat)firstBaselineInBounds:(CGRect)bounds {
    return [self baselineOfLineAtIndex:0 inBounds:bounds];
}

- (CGFloat)lastBaselineInBounds:(CGRect)bounds {
    return [self baselineOfLineAtIndex:_lines.count - 1 inBounds:bounds];
}

- (void)drawInContext:(CGContextRef)context bounds:(CGRect)bounds {
    if (self.text.length == 0) {
        return;
    }
    
    [self _calculate];
    
    CGContextSetTextMatrix(context, CGAffineTransformIdentity);
    
    CGContextTranslateCTM(context, 0, bounds.size.height);
    CGContextScaleCTM(context, 1.0, -1.0);
    
    CGFloat offsetY = [self offsetYWithBounds:bounds];
    
    NSUInteger linesCount = _lines.count;
    for (int i=0;i<linesCount;i++) {
        VZFTextLine *textLine = _lines[i];
        CGFloat scale = textLine.scale ?: 1;
        
        CTLineRef line = (__bridge CTLineRef)textLine.line;
        CGFloat offsetX;
        switch (_alignment) {
            default:
            case NSTextAlignmentLeft:
                offsetX = bounds.origin.x;
                break;
            case NSTextAlignmentCenter:
                offsetX = bounds.origin.x + (bounds.size.width - textLine.width * scale) / 2;
                break;
            case NSTextAlignmentRight:
                offsetX = bounds.origin.x + (bounds.size.width - textLine.width * scale);
                break;
        }
        CGFloat x = offsetX;
        CGFloat y = bounds.size.height - (offsetY + textLine.top + textLine.height);
        if (textLine.scale) {
            CGFloat scaleCenterY = y;
            switch (_baselineAdjustment) {
                case UIBaselineAdjustmentNone:
                    scaleCenterY += textLine.height;
                    break;
                default:
                case UIBaselineAdjustmentAlignBaselines:
                    scaleCenterY -= textLine.offsetY;
                    break;
                case UIBaselineAdjustmentAlignCenters:
                    scaleCenterY += textLine.height / 2;
                    break;
            }
            
            CGContextSaveGState(context);
            CGContextTranslateCTM(context, x, scaleCenterY);
            CGContextScaleCTM(context, textLine.scale, textLine.scale);
            CGContextTranslateCTM(context, -x, -scaleCenterY);
        }
        CGContextSetTextPosition(context, VZF_ROUND_PIXEL(x), VZF_ROUND_PIXEL(y - textLine.offsetY));
//        CGContextStrokeRect(context, CGRectMake(x, y, textLine.width, textLine.height));
        CTLineDraw(line, context);
        
        // draws strike through, currently only supports solid single line style.
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (CFIndex i=0, count=CFArrayGetCount(runs);i<count;i++) {
            CTRunRef run = (CTRunRef)CFArrayGetValueAtIndex(runs, i);
            NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
            
            CGPoint point;
            CTRunGetPositions(run, CFRangeMake(0, 1), &point);
//            CGFloat width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
//            CGContextStrokeRect(context, CGRectMake(x+point.x, y+point.y, width, textLine.height));
            
            UIImage *image = ((NSTextAttachment *)attributes[NSAttachmentAttributeName]).image;
            if (image) {
                CGContextDrawImage(context, CGRectMake(x + point.x, y + point.y - textLine.offsetY, image.size.width, image.size.height), image.CGImage);
            }
            
            if ([attributes[NSStrikethroughStyleAttributeName] intValue] != 0) {
                UIColor *strikeColor = attributes[NSStrikethroughColorAttributeName] ?: attributes[NSForegroundColorAttributeName];
                CGFloat width = CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL);
                CGContextSetStrokeColorWithColor(context, strikeColor.CGColor);
                UIFont *font = attributes[NSFontAttributeName] ?: [UIFont systemFontOfSize:[UIFont systemFontSize]];
                // CTFontGetUnderlineThickness 在 iOS 7 上可能crash，原因不明。这里自己计算线条粗细，因数是测试出来的。
                // CGFloat strikeThickness = CTFontGetUnderlineThickness((CTFontRef)font);
                CGFloat strikeThickness = font.pointSize * 0.05859375;
                CGFloat strikeX = x + point.x;
                CGFloat strikeY = y + point.y - textLine.offsetY + font.xHeight / 2; // TODO: snap to pixels
                CGContextSetLineWidth(context, strikeThickness);
                CGContextMoveToPoint(context, strikeX, strikeY);
                CGContextAddLineToPoint(context, MIN(strikeX + width, bounds.origin.x + bounds.size.width / scale), strikeY);
                CGContextStrokePath(context);
            }
        }
        
        if (textLine.scale) {
            CGContextRestoreGState(context);
        }
        
//        CGFloat baseline = bounds.size.height - [self baselineOfLineAtIndex:i inBounds:bounds];
//        CGContextMoveToPoint(context, x, baseline);
//        CGContextAddLineToPoint(context, x + textLine.width, baseline);
//        CGContextStrokePath(context);
    }
}

@end
