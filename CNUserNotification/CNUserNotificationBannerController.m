//
//  CNUserNotificationBannerController.m
//
//  Created by Frank Gregor on 16.05.13.
//  Copyright (c) 2013 cocoa:naut. All rights reserved.
//

/*
 The MIT License (MIT)
 Copyright © 2013 Frank Gregor, <phranck@cocoanaut.com>

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the “Software”), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <QuartzCore/QuartzCore.h>
#import "CNUserNotificationBannerController.h"
#import "CNUserNotificationBannerBackgroundView.h"
#import "CNUserNotificationBannerButton.h"


static NSTimeInterval slideInAnimationDuration = 0.42;
static NSTimeInterval slideOutAnimationDuration = 0.56;
static NSDictionary *titleAttributes, *subtitleAttributes, *informativeTextAttributes;
static NSRect presentationBeginRect, presentationRect, presentationEndRect;
static CGFloat bannerTopMargin = 10;
static CGFloat bannerTrailingMargin = 15;
static CGSize bannerSize;
static CGSize bannerImageSize;
static CGFloat bannerContentPadding = 8;
static CGFloat bannerContentLabelPadding = 1;
static CGSize buttonSize;


CGFloat CNGetMaxCGFloat(CGFloat left, CGFloat right) {
    return (left > right ? left : right);;
}


@interface CNUserNotificationBannerController () {
    NSDictionary *_userInfo;
    CNUserNotification *_userNotification;
    void (^_activationBlock)(CNUserNotificationActivationType);
    CGFloat _labelWidth;
    NSLineBreakMode _informativeTextLineBreakMode;
}
@property (strong, nonatomic) NSTextField *title;
@property (strong, nonatomic) NSTextField *subtitle;
@property (strong, nonatomic) NSTextField *informativeText;
@property (strong, nonatomic) NSImageView *bannerImageView;
@property (assign) BOOL animationIsRunning;
@property (strong) NSTimer *dismissTimer;
@end

@implementation CNUserNotificationBannerController

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Initialization

+ (void)initialize
{
    bannerSize = NSMakeSize(380.0, 70.0);
    bannerImageSize = NSMakeSize(36.0, 36.0);
    buttonSize = NSMakeSize(80.0, 32.0);
}

- (instancetype)initWithNotification:(CNUserNotification *)theNotification
                            delegate:(id<CNUserNotificationCenterDelegate>)theDelegate
                usingActivationBlock:(void(^)(CNUserNotificationActivationType activationType))activationBlock
{
    self = [super init];
    if (self) {
        _activationBlock = activationBlock;
        _animationIsRunning = NO;
        _userInfo = theNotification.userInfo;
        _delegate = theDelegate;
        _userNotification = theNotification;
        _informativeTextLineBreakMode = _userNotification.feature.lineBreakMode;

        [self adjustTextFieldAttributes];

        [[NSNotificationCenter defaultCenter] addObserverForName:CNUserNotificationDismissBannerNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(NSNotification *note) {
                                                          [self dismissBanner];
                                                      }];
    }
    return self;
}

/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - API

- (void)presentBanner
{
    if (self.animationIsRunning) return;

    self.animationIsRunning = YES;

    [self prepareNotificationBanner];
    [NSApp activateIgnoringOtherApps:YES];

    NSWindow *window = [self window];
    [window setFrame:presentationBeginRect display:NO];
    [window orderFront:self];

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = slideInAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [[window animator] setAlphaValue:1.0];
        [[window animator] setFrame:presentationRect display:YES];
        
    } completionHandler:^{
        self.animationIsRunning = NO;
        [window makeKeyAndOrderFront:self];

        [[NSNotificationCenter defaultCenter] postNotificationName:CNUserNotificationHasBeenPresentedNotification object:nil];
    }];
}

- (void)presentBannerDismissAfter:(NSTimeInterval)dismissTimerInterval
{
    [self presentBanner];
    self.dismissTimer = [NSTimer timerWithTimeInterval:dismissTimerInterval target:self selector:@selector(timedBannerDismiss:) userInfo:nil repeats:NO];
    [[NSRunLoop mainRunLoop] addTimer:self.dismissTimer forMode:NSDefaultRunLoopMode];
}

- (void)dismissBanner
{
    if (self.animationIsRunning) return;

    self.animationIsRunning = YES;

    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = slideOutAnimationDuration;
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [[[self window] animator] setAlphaValue:0.0];
        [[[self window] animator] setFrame:presentationEndRect display:YES];
        
    } completionHandler:^{
        self.animationIsRunning = NO;
        [[self window] close];
    }];
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

- (void)adjustTextFieldAttributes
{
    NSShadow *textShadow = [[NSShadow alloc] init];
    [textShadow setShadowColor:[[NSColor whiteColor] colorWithAlphaComponent:0.5]];
    [textShadow setShadowOffset:NSMakeSize(0, -1)];

    NSMutableParagraphStyle *textStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    [textStyle setAlignment:NSLeftTextAlignment];
    [textStyle setLineBreakMode:NSLineBreakByTruncatingTail];

    titleAttributes = @{
        NSShadowAttributeName:          textShadow,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.280 alpha:1.000],
        NSFontAttributeName:            [NSFont fontWithName:@"LucidaGrande-Bold" size:12],
        NSParagraphStyleAttributeName:  textStyle
    };

    subtitleAttributes = @{
        NSShadowAttributeName:          textShadow,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.280 alpha:1.000],
        NSFontAttributeName:            [NSFont fontWithName:@"LucidaGrande-Bold" size:11],
        NSParagraphStyleAttributeName:  textStyle
    };

    [textStyle setLineBreakMode:_informativeTextLineBreakMode];
    informativeTextAttributes = @{
        NSShadowAttributeName:          textShadow,
        NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:0.500 alpha:1.000],
        NSFontAttributeName:            [NSFont fontWithName:@"LucidaGrande" size:11],
        NSParagraphStyleAttributeName:  textStyle
    };
}



/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Actions

- (void)activationButtonAction
{
    _activationBlock(CNUserNotificationActivationTypeActionButtonClicked);
}

- (void)otherButtonAction
{
    [self dismissBanner];
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - Private Helper

- (void)timedBannerDismiss:(NSTimer *)theTimer
{
    [self dismissBanner];
}

- (void)calculateBannerPositions
{
    NSRect mainScreenFrame = [[NSScreen screens][0] frame];
    CGFloat statusBarThickness = [[NSStatusBar systemStatusBar] thickness];
    CGFloat calculatedBannerHeight = bannerContentPadding + self.title.intrinsicContentSize.height * 2 + self.informativeText.intrinsicContentSize.height + bannerContentLabelPadding * 2 + bannerContentPadding;
    CGFloat delta = bannerSize.height - calculatedBannerHeight;
    CGFloat bannerheight = (delta < 0 ? bannerSize.height + delta*-1 : bannerSize.height);

    /// window position before slide in animation
    presentationBeginRect = NSMakeRect(NSMaxX(mainScreenFrame) - bannerSize.width - bannerTrailingMargin,
                                       NSMaxY(mainScreenFrame) - bannerheight - bannerTopMargin,
                                       bannerSize.width,
                                       bannerheight);

    /// window position after slide in animation
    presentationRect = NSMakeRect(NSMaxX(mainScreenFrame) - bannerSize.width - bannerTrailingMargin,
                                  NSMaxY(mainScreenFrame) - statusBarThickness - bannerheight - bannerTopMargin,
                                  bannerSize.width,
                                  bannerheight);

    /// window position after slide out animation
    presentationEndRect = NSMakeRect(NSMaxX(mainScreenFrame) - bannerSize.width,
                                     NSMaxY(mainScreenFrame) - statusBarThickness - bannerheight - bannerTopMargin,
                                     bannerSize.width,
                                     bannerheight);
}

- (void)prepareNotificationBanner
{
    if (![self window]) {
        [self setWindow:[[NSWindow alloc] initWithContentRect:NSZeroRect
                                                    styleMask:NSBorderlessWindowMask
                                                      backing:NSBackingStoreBuffered
                                                        defer:NO
                                                       screen:[NSScreen screens][0]]];
    }

    [[self window] setHasShadow:YES];
    [[self window] setDisplaysWhenScreenProfileChanges:YES];
    [[self window] setReleasedWhenClosed:NO];
    [[self window] setAlphaValue:0.0];
    [[self window] setOpaque:NO];
    [[self window] setLevel:NSStatusWindowLevel];
    [[self window] setBackgroundColor:[NSColor clearColor]];
    [[self window] setCollectionBehavior:(NSWindowCollectionBehaviorCanJoinAllSpaces | NSWindowCollectionBehaviorStationary)];

    /// now we build the banner content
    CNUserNotificationBannerBackgroundView *contentView = [[CNUserNotificationBannerBackgroundView alloc] init];
    [[self window] setContentView:contentView];

    self.bannerImageView = [NSImageView new];
    self.bannerImageView.translatesAutoresizingMaskIntoConstraints = NO;
    self.bannerImageView.image = _userNotification.feature.bannerImage;
    [contentView addSubview:self.bannerImageView];

    
    self.title = [self labelWithidentifier:@"titleLabel"
                       attributedTextValue:[[NSAttributedString alloc] initWithString:_userNotification.title attributes:titleAttributes]
                                 superView:contentView];

    self.subtitle = [self labelWithidentifier:@"subtitleLabel"
                          attributedTextValue:[[NSAttributedString alloc] initWithString:_userNotification.subtitle attributes:subtitleAttributes]
                                    superView:contentView];

    self.informativeText = [self labelWithidentifier:@"informativeTextLabel"
                                 attributedTextValue:[[NSAttributedString alloc] initWithString:_userNotification.informativeText attributes:informativeTextAttributes]
                                           superView:contentView];

    switch (_informativeTextLineBreakMode) {
        case NSLineBreakByClipping:
        case NSLineBreakByTruncatingHead:
        case NSLineBreakByTruncatingTail:
        case NSLineBreakByTruncatingMiddle:
            [self.informativeText.cell setUsesSingleLineMode:YES];
            break;

        default:
            [self.informativeText.cell setUsesSingleLineMode:NO];
            break;
    }

    CNUserNotificationBannerButton *otherButton = [[CNUserNotificationBannerButton alloc] init];
    otherButton.target = self;
    otherButton.action = @selector(otherButtonAction);
    otherButton.title = (![_userNotification.otherButtonTitle isEqualToString:@""] ? _userNotification.otherButtonTitle : NSLocalizedString(@"Close", @"CNUserNotificationBannerController: Other-Button title"));

    CNUserNotificationBannerButton *activationButton = [[CNUserNotificationBannerButton alloc] init];
    activationButton.target = self;
    activationButton.action = @selector(activationButtonAction);
    activationButton.title = (![_userNotification.actionButtonTitle isEqualToString:@""] ? _userNotification.actionButtonTitle : NSLocalizedString(@"Show", @"CNUserNotificationBannerController: Activation-Button title"));

    CGFloat calculatedMaxButtonWidth = CNGetMaxCGFloat(otherButton.intrinsicContentSize.width, activationButton.intrinsicContentSize.width);

    NSDictionary *views = @{
        @"bannerImage":         self.bannerImageView,
        @"title":               self.title,
        @"subtitle":            self.subtitle,
        @"informativeText":     self.informativeText,
        @"otherButton":         otherButton,
        @"activationButton":    activationButton
    };

    _labelWidth = 0;
    if (_userNotification.hasActionButton) {
        _labelWidth = bannerSize.width - (bannerContentPadding + bannerImageSize.width + bannerContentPadding + bannerContentPadding + calculatedMaxButtonWidth + bannerContentPadding);
    } else {
        _labelWidth = bannerSize.width - (bannerContentPadding + bannerImageSize.width + bannerContentPadding + bannerContentPadding);
    }
    [self.informativeText setPreferredMaxLayoutWidth:_labelWidth];


    NSDictionary *metrics = @{
        @"padding":         @(bannerContentPadding),
        @"labelPadding":    @(bannerContentLabelPadding),
        @"labelHeight":     @(self.title.intrinsicContentSize.height),
        @"labelWidth":      @(_labelWidth),
        @"imageWidth":      @(bannerImageSize.width),
        @"imageHeight":     @(bannerImageSize.height),
        @"buttonWidth":     @(calculatedMaxButtonWidth)
    };

    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-padding-[bannerImage(imageHeight)]" options:0 metrics:metrics views:views]];
    [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-padding-[title(labelHeight)]-labelPadding-[subtitle(labelHeight)]-labelPadding-[informativeText(>=labelHeight)]"
                                                                        options:NSLayoutFormatAlignAllLeading | NSLayoutFormatAlignAllTrailing metrics:metrics views:views]];
    if (_userNotification.hasActionButton) {
        [contentView addSubview:otherButton];
        [contentView addSubview:activationButton];

        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-padding-[otherButton]-padding-[activationButton]" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-padding-[bannerImage(imageWidth)]-padding-[title(labelWidth)]-padding-[otherButton(buttonWidth)]-padding-|" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[activationButton(==otherButton)]-padding-|" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[subtitle(==title)]" options:0 metrics:metrics views:views]];
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[informativeText(==title)]" options:0 metrics:metrics views:views]];
    }

    else {
        [contentView addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-padding-[bannerImage(imageWidth)]-padding-[title(labelWidth)]-padding-|" options:0 metrics:metrics views:views]];
    }

    [self calculateBannerPositions];
    [self showWindow:nil];
}

- (NSTextField *)labelWithidentifier:(NSString *)theIdentifier attributedTextValue:(NSAttributedString *)theTextValue superView:(NSView *)theSuperView
{
    NSTextField *aTextField = [NSTextField new];
    aTextField.translatesAutoresizingMaskIntoConstraints = NO;
    aTextField.attributedStringValue = theTextValue;
    aTextField.identifier = theIdentifier;
    aTextField.drawsBackground = NO;
    [aTextField setSelectable:NO];
    [aTextField setEditable:NO];
    [aTextField setBordered:NO];
    [aTextField setAlignment:NSLeftTextAlignment];
    [theSuperView addSubview:aTextField];

    return aTextField;
}


/////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#pragma mark - NSResponder

- (void)mouseUp:(NSEvent *)theEvent
{
    _activationBlock(CNUserNotificationActivationTypeContentsClicked);
}

@end
