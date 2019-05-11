// Copyright 2018 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "FLEWindowSizePlugin.h"

#import <AppKit/AppKit.h>

#include "plugins/window_size/common/channel_constants.h"

/**
 * Returns the max Y coordinate across all screens.
 */
CGFloat GetMaxScreenY() {
  CGFloat maxY = 0;
  for (NSScreen *screen in [NSScreen screens]) {
    maxY = MAX(maxY, CGRectGetMaxY(screen.frame));
  }
  return maxY;
}

/**
 * Given |frame| in screen coordinates, returns a frame flipped relative to
 * GetMaxScreenY().
 */
NSRect GetFlippedRect(NSRect frame) {
  CGFloat maxY = GetMaxScreenY();
  return NSMakeRect(frame.origin.x, maxY - frame.origin.y - frame.size.height, frame.size.width,
                    frame.size.height);
}

@interface FLEWindowSizePlugin ()
/**
 * Extracts information from |screen| and returns the serializable form expected
 * by the platform channel.
 */
- (NSDictionary *)platformChannelRepresentationForScreen:(NSScreen *)screen;

/**
 * Extracts information from |window| and returns the serializable form expected
 * by the platform channel.
 */
- (NSDictionary *)platformChannelRepresentationForWindow:(NSWindow *)window;

/**
 * Returns the serializable form of |frame| expected by the platform channel.
 */
- (NSArray *)platformChannelRepresentationForFrame:(NSRect)frame;

@end

@implementation FLEWindowSizePlugin {
  // The channel used to communicate with Flutter.
  FlutterMethodChannel *_channel;
  // The view displaying Flutter content.
  NSView *_flutterView;
}

+ (void)registerWithRegistrar:(id<FLEPluginRegistrar>)registrar {
  FlutterMethodChannel *channel =
      [FlutterMethodChannel methodChannelWithName:@(plugins_window_size::kChannelName)
                                  binaryMessenger:registrar.messenger];
  FLEWindowSizePlugin *instance = [[FLEWindowSizePlugin alloc] initWithChannel:channel
                                                                          view:registrar.view];
  [registrar addMethodCallDelegate:instance channel:channel];
}

- (instancetype)initWithChannel:(FlutterMethodChannel *)channel view:(NSView *)view {
  self = [super init];
  if (self) {
    _channel = channel;
    _flutterView = view;
  }
  return self;
}

/**
 * Handles platform messages generated by the Flutter framework on the color
 * panel channel.
 */
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
  id methodResult = nil;
  if ([call.method isEqualToString:@(plugins_window_size::kGetScreenListMethod)]) {
    NSMutableArray<NSDictionary *> *screenList =
        [NSMutableArray arrayWithCapacity:[NSScreen screens].count];
    for (NSScreen *screen in [NSScreen screens]) {
      [screenList addObject:[self platformChannelRepresentationForScreen:screen]];
    }
    methodResult = screenList;
  } else if ([call.method isEqualToString:@(plugins_window_size::kGetWindowInfoMethod)]) {
    methodResult = [self platformChannelRepresentationForWindow:_flutterView.window];
  } else if ([call.method isEqualToString:@(plugins_window_size::kSetWindowFrameMethod)]) {
    NSArray<NSNumber *> *arguments = call.arguments;
    [_flutterView.window
        setFrame:GetFlippedRect(NSMakeRect(arguments[0].doubleValue, arguments[1].doubleValue,
                                           arguments[2].doubleValue, arguments[3].doubleValue))
         display:YES];
    methodResult = nil;
  } else {
    methodResult = FlutterMethodNotImplemented;
  }
  result(methodResult);
}

#pragma mark - Private methods

- (NSDictionary *)platformChannelRepresentationForScreen:(NSScreen *)screen {
  return @{
    @(plugins_window_size::kFrameKey) :
        [self platformChannelRepresentationForFrame:GetFlippedRect(screen.frame)],
    @(plugins_window_size::kVisibleFrameKey) :
        [self platformChannelRepresentationForFrame:GetFlippedRect(screen.visibleFrame)],
    @(plugins_window_size::kScaleFactorKey) : @(screen.backingScaleFactor),
  };
}

- (NSDictionary *)platformChannelRepresentationForWindow:(NSWindow *)window {
  return @{
    @(plugins_window_size::kFrameKey) :
        [self platformChannelRepresentationForFrame:GetFlippedRect(window.frame)],
    @(plugins_window_size::kScreenKey) :
        [self platformChannelRepresentationForScreen:window.screen],
    @(plugins_window_size::kScaleFactorKey) : @(window.backingScaleFactor),
  };
}

- (NSArray *)platformChannelRepresentationForFrame:(NSRect)frame {
  return @[ @(frame.origin.x), @(frame.origin.y), @(frame.size.width), @(frame.size.height) ];
}

@end